import io
import json
import os
import re

from fastapi import FastAPI, File, Header, HTTPException, UploadFile
from google import genai
from google.genai import errors, types
from PIL import Image, ImageOps, ImageEnhance, ImageFilter

MODEL = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash")
MAX_UPLOAD_BYTES = 10 * 1024 * 1024
MAX_SIDE = 1568
APP_TOKEN = os.environ.get("APP_TOKEN")

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
    try:
        img = Image.open(io.BytesIO(raw))
        img = ImageOps.exif_transpose(img).convert("RGB")
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid image file")
    img.thumbnail((MAX_SIDE, MAX_SIDE), Image.LANCZOS)
    enhancer = ImageEnhance.Contrast(img)
    img = enhancer.enhance(1.5)
    img = img.filter(ImageFilter.SHARPEN)
    buf = io.BytesIO()
    img.save(buf, "JPEG", quality=90)
    return buf.getvalue()

def extract_json(text: str) -> dict:
    match = re.search(r"\{.*\}", text, re.DOTALL)
    if not match:
        raise ValueError("no JSON object found")
    return json.loads(match.group(0))

@app.get("/health")
async def health():
    return {"status": "ok"}

@app.post("/ocr")
async def ocr(file: UploadFile = File(...), x_app_token: str | None = Header(default=None)):
    if APP_TOKEN and x_app_token != APP_TOKEN:
        raise HTTPException(status_code=401, detail="Unauthorized")

    raw = await file.read()
    if not raw:
        raise HTTPException(status_code=400, detail="Empty file")
    if len(raw) > MAX_UPLOAD_BYTES:
        raise HTTPException(status_code=413, detail="Image too large (max 10 MB)")

    image_bytes = prepare_image(raw)

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
        status = 429 if getattr(e, "code", None) == 429 else 502
        raise HTTPException(status_code=status, detail=f"Model API error ({getattr(e, 'code', '?')})")
    except Exception:
        raise HTTPException(status_code=502, detail="Could not reach the model API")

    text = response.text or ""
    try:
        data = extract_json(text)
    except (ValueError, json.JSONDecodeError):
        raise HTTPException(status_code=502, detail="Could not parse model output")

    return {
        "vendor": data.get("vendor") or "",
        "date": data.get("date") or "",
        "currency": data.get("currency") or "",
        "total": str(data.get("total") or ""),
        "items": data.get("items") or [],
        "full_text": data.get("full_text") or "",
        "uncertain": data.get("uncertain") or [],
    }