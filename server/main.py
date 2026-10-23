import hmac
import io
import json
import os
import re
from typing import Optional
from PIL import Image, ImageOps, ImageEnhance, ImageFilter
from fastapi import FastAPI, File, Header, HTTPException, UploadFile
from google import genai
from google.genai import errors, types
from PIL import Image, ImageOps
from starlette.concurrency import run_in_threadpool

MODEL = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash")
MAX_UPLOAD_BYTES = 10 * 1024 * 1024
MAX_SIDE = 2048  # الخط اليدوي يحتاج دقة أعلى من 1568
APP_TOKEN = os.environ.get("APP_TOKEN")

# السيرفر يتعرض للإنترنت: بدون توكن أي شخص يستهلك حصة Gemini حقتك
if not APP_TOKEN:
    raise RuntimeError("APP_TOKEN environment variable is required")

# يقرأ GEMINI_API_KEY (أو GOOGLE_API_KEY) من متغيرات البيئة
client = genai.Client()
app = FastAPI(title="Receipt OCR (Gemini)")

PROMPT = """You are reading a photo of a receipt that contains handwritten text
(Arabic and/or English). Transcribe exactly what is written. Never guess:
if a word or number is unclear, leave that field empty and report it in "uncertain".

Return ONLY a JSON object (no markdown, no commentary) with this shape:
{
  "vendor": "",
  "date": "",
  "currency": "",
  "total": "",
  "items": [{"name": "", "quantity": "", "price": ""}],
  "full_text": "",
  "uncertain": []
}

Rules:
- "full_text": all readable text, line by line, in the original language and order.
- "date": as written; use YYYY-MM-DD only if the format is unambiguous.
- "total", "quantity", "price": numbers only, using Western digits (0-9) and a dot
  as the decimal separator.
- "uncertain": list the fields you are not sure about, using the names
  "vendor", "date", "currency", "total", or "items.N" (N = zero-based item index).
- If the image is not a receipt or has no readable text, return empty fields
  and put a short explanation in "full_text"."""


def prepare_image(raw: bytes) -> bytes:
    """تصحيح الاتجاه + تصغير + إرجاع الفلاتر لتحسين وضوح النص."""
    try:
        img = Image.open(io.BytesIO(raw))
        img = ImageOps.exif_transpose(img).convert("RGB")
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid image file")
    
    # تصغير الصورة
    img.thumbnail((MAX_SIDE, MAX_SIDE), Image.LANCZOS)
    
    # 🌟 إرجاع الفلاتر
    enhancer = ImageEnhance.Contrast(img)
    img = enhancer.enhance(1.5) 
    img = img.filter(ImageFilter.SHARPEN) 
    
    buf = io.BytesIO()
    img.save(buf, "JPEG", quality=92)
    return buf.getvalue()


def extract_json(text: str) -> dict:
    match = re.search(r"\{.*\}", text, re.DOTALL)
    if not match:
        raise ValueError("no JSON object found")
    data = json.loads(match.group(0))
    if not isinstance(data, dict):
        raise ValueError("JSON is not an object")
    return data


def as_str(value) -> str:
    return "" if value is None else str(value).strip()


def normalize_items(items) -> list:
    """يضمن أن كل صنف dict بثلاث حقول نصية، حتى لا ينهار التطبيق."""
    result = []
    if not isinstance(items, list):
        return result
    for it in items:
        if isinstance(it, dict):
            result.append(
                {
                    "name": as_str(it.get("name")),
                    "quantity": as_str(it.get("quantity")),
                    "price": as_str(it.get("price")),
                }
            )
        elif it:
            result.append({"name": as_str(it), "quantity": "", "price": ""})
    return result


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.get("/check")
async def check(x_app_token: Optional[str] = Header(default=None)):
    """يستخدمه التطبيق لاختبار العنوان والتوكن من شاشة الإعدادات."""
    if not x_app_token or not hmac.compare_digest(x_app_token, APP_TOKEN):
        raise HTTPException(status_code=401, detail="Unauthorized")
    return {"status": "ok"}


@app.post("/ocr")
async def ocr(
    file: UploadFile = File(...),
    x_app_token: Optional[str] = Header(default=None),
):
    if not x_app_token or not hmac.compare_digest(x_app_token, APP_TOKEN):
        raise HTTPException(status_code=401, detail="Unauthorized")

    raw = await file.read()
    if not raw:
        raise HTTPException(status_code=400, detail="Empty file")
    if len(raw) > MAX_UPLOAD_BYTES:
        raise HTTPException(status_code=413, detail="Image too large (max 10 MB)")

    # معالجة الصورة شغل ثقيل على الـ CPU، نطلعه من الـ event loop
    image_bytes = await run_in_threadpool(prepare_image, raw)

    try:
        response = await client.aio.models.generate_content(
            model=MODEL,
            contents=[
                types.Part.from_bytes(data=image_bytes, mime_type="image/jpeg"),
                PROMPT,
            ],
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                temperature=0,
            ),
        )
    except errors.APIError as e:
        code = getattr(e, "code", None)
        status = 429 if code == 429 else 502
        raise HTTPException(status_code=status, detail=f"Model API error ({code})")
    except Exception:
        raise HTTPException(status_code=502, detail="Could not reach the model API")

    text = response.text or ""
    try:
        data = extract_json(text)
    except (ValueError, json.JSONDecodeError):
        raise HTTPException(status_code=502, detail="Could not parse model output")

    uncertain = data.get("uncertain")
    if not isinstance(uncertain, list):
        uncertain = []

    return {
        "vendor": as_str(data.get("vendor")),
        "date": as_str(data.get("date")),
        "currency": as_str(data.get("currency")),
        "total": as_str(data.get("total")),
        "items": normalize_items(data.get("items")),
        "full_text": as_str(data.get("full_text")),
        "uncertain": [as_str(u) for u in uncertain if u],
    }
