class Category {
  final String id;
  final String name;
  final String slug;
  final String iconName;
  final String? parentCategory;
  final List<String> subcategories;
  final DateTime createdAt;

  const Category({
    required this.id,
    required this.name,
    required this.slug,
    required this.iconName,
    this.parentCategory,
    required this.subcategories,
    required this.createdAt,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: json['id'],
    name: json['name'],
    slug: json['slug'],
    iconName: json['iconName'],
    parentCategory: json['parentCategory'],
    subcategories: List<String>.from(json['subcategories'] ?? []),
    createdAt: DateTime.parse(json['createdAt']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slug': slug,
    'iconName': iconName,
    'parentCategory': parentCategory,
    'subcategories': subcategories,
    'createdAt': createdAt.toIso8601String(),
  };
}