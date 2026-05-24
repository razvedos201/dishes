class Product {
  String id;
  String name;
  double defaultAmount; // вес/количество по умолчанию
  String defaultUnit;   // единица по умолчанию

  Product({
    required this.id,
    required this.name,
    this.defaultAmount = 100,
    this.defaultUnit = 'г',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'defaultAmount': defaultAmount,
        'defaultUnit': defaultUnit,
      };

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      defaultAmount: (json['defaultAmount'] as num?)?.toDouble() ?? 100,
      defaultUnit: (json['defaultUnit'] as String?) ?? 'г',
    );
  }
}
