class Product {
  String id;
  String name;
  double defaultAmount; // вес/количество по умолчанию
  String defaultUnit;   // единица по умолчанию
  double? defaultPrice; // стоимость по умолчанию (необязательно)

  Product({
    required this.id,
    required this.name,
    this.defaultAmount = 100,
    this.defaultUnit = 'г',
    this.defaultPrice,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'defaultAmount': defaultAmount,
        'defaultUnit': defaultUnit,
        'defaultPrice': defaultPrice,
      };

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      defaultAmount: (json['defaultAmount'] as num?)?.toDouble() ?? 100,
      defaultUnit: (json['defaultUnit'] as String?) ?? 'г',
      defaultPrice: json['defaultPrice'] != null
          ? (json['defaultPrice'] as num).toDouble()
          : null,
    );
  }
}
