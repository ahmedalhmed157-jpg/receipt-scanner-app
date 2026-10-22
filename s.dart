void main() {
  List<String> cart = ["coffee", "milk"];
  Map<String, double> prices = {
    "coffee": 5.5,
     "milk": 2.0
     };
  for (String item in cart) {
    print("$item costs ${prices[item]}");
  }
}
