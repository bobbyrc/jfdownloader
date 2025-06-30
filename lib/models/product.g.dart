// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Product _$ProductFromJson(Map<String, dynamic> json) => Product(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      imageUrl: json['imageUrl'] as String,
      category: json['category'] as String,
      files: (json['files'] as List<dynamic>)
          .map((e) => ProductFile.fromJson(e as Map<String, dynamic>))
          .toList(),
      purchaseDate: DateTime.parse(json['purchaseDate'] as String),
      version: json['version'] as String,
      sizeInMB: (json['sizeInMB'] as num).toDouble(),
      isDownloaded: json['isDownloaded'] as bool? ?? false,
      localPath: json['localPath'] as String?,
    );

Map<String, dynamic> _$ProductToJson(Product instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'imageUrl': instance.imageUrl,
      'category': instance.category,
      'files': instance.files,
      'purchaseDate': instance.purchaseDate.toIso8601String(),
      'version': instance.version,
      'sizeInMB': instance.sizeInMB,
      'isDownloaded': instance.isDownloaded,
      'localPath': instance.localPath,
    };

ProductFile _$ProductFileFromJson(Map<String, dynamic> json) => ProductFile(
      id: json['id'] as String,
      name: json['name'] as String,
      downloadUrl: json['downloadUrl'] as String,
      fileType: json['fileType'] as String,
      sizeInMB: (json['sizeInMB'] as num).toDouble(),
      isDownloaded: json['isDownloaded'] as bool? ?? false,
      localPath: json['localPath'] as String?,
    );

Map<String, dynamic> _$ProductFileToJson(ProductFile instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'downloadUrl': instance.downloadUrl,
      'fileType': instance.fileType,
      'sizeInMB': instance.sizeInMB,
      'isDownloaded': instance.isDownloaded,
      'localPath': instance.localPath,
    };
