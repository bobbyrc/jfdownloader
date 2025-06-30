import 'package:json_annotation/json_annotation.dart';

part 'product.g.dart';

@JsonSerializable()
class Product {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final String category;
  final List<ProductFile> files;
  final DateTime purchaseDate;
  final String version;
  final double sizeInMB;
  final bool isDownloaded;
  final String? localPath;

  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.category,
    required this.files,
    required this.purchaseDate,
    required this.version,
    required this.sizeInMB,
    this.isDownloaded = false,
    this.localPath,
  });

  factory Product.fromJson(Map<String, dynamic> json) => _$ProductFromJson(json);
  Map<String, dynamic> toJson() => _$ProductToJson(this);

  Product copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    String? category,
    List<ProductFile>? files,
    DateTime? purchaseDate,
    String? version,
    double? sizeInMB,
    bool? isDownloaded,
    String? localPath,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      files: files ?? this.files,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      version: version ?? this.version,
      sizeInMB: sizeInMB ?? this.sizeInMB,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      localPath: localPath ?? this.localPath,
    );
  }
}

@JsonSerializable()
class ProductFile {
  final String id;
  final String name;
  final String downloadUrl;
  final String fileType;
  final double sizeInMB;
  final bool isDownloaded;
  final String? localPath;

  const ProductFile({
    required this.id,
    required this.name,
    required this.downloadUrl,
    required this.fileType,
    required this.sizeInMB,
    this.isDownloaded = false,
    this.localPath,
  });

  factory ProductFile.fromJson(Map<String, dynamic> json) => _$ProductFileFromJson(json);
  Map<String, dynamic> toJson() => _$ProductFileToJson(this);

  ProductFile copyWith({
    String? id,
    String? name,
    String? downloadUrl,
    String? fileType,
    double? sizeInMB,
    bool? isDownloaded,
    String? localPath,
  }) {
    return ProductFile(
      id: id ?? this.id,
      name: name ?? this.name,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      fileType: fileType ?? this.fileType,
      sizeInMB: sizeInMB ?? this.sizeInMB,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      localPath: localPath ?? this.localPath,
    );
  }
}
