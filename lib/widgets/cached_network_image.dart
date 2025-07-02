import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import '../services/cache_service.dart';
import '../services/logger_service.dart';

/// Optimized image widget with memory caching and loading states
class CachedNetworkImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final double? width;
  final double? height;

  const CachedNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.width,
    this.height,
  });

  @override
  State<CachedNetworkImage> createState() => _CachedNetworkImageState();
}

class _CachedNetworkImageState extends State<CachedNetworkImage> {
  final CacheService _cache = CacheService();
  Uint8List? _imageData;
  bool _isLoading = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(CachedNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    if (widget.imageUrl.isEmpty) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Check cache first
      final cachedData = _cache.getCachedImage(widget.imageUrl);
      if (cachedData != null) {
        if (mounted) {
          setState(() {
            _imageData = cachedData;
            _isLoading = false;
          });
        }
        return;
      }

      // Load from network
      final response =
          await NetworkAssetBundle(Uri.parse(widget.imageUrl)).load('');
      final data = response.buffer.asUint8List();

      // Cache the image data
      _cache.cacheImage(widget.imageUrl, data);

      if (mounted) {
        setState(() {
          _imageData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      LoggerService().warning(
          'Failed to load image: ${widget.imageUrl}', 'CachedNetworkImage');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.placeholder ?? _buildDefaultPlaceholder(context);
    }

    if (_hasError || _imageData == null) {
      return widget.errorWidget ?? _buildDefaultErrorWidget(context);
    }

    return Image.memory(
      _imageData!,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      errorBuilder: (context, error, stackTrace) {
        return widget.errorWidget ?? _buildDefaultErrorWidget(context);
      },
    );
  }

  Widget _buildDefaultPlaceholder(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _buildDefaultErrorWidget(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.image_not_supported,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        size: 48,
      ),
    );
  }
}

/// Optimized image widget for product cards
class ProductImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;

  const ProductImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return _buildPlaceholder(context);
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      placeholder: _buildPlaceholder(context),
      errorWidget: _buildErrorWidget(context),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.flight_takeoff,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 8),
          Text(
            'Loading...',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.flight_takeoff,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 8),
          Text(
            'JustFlight',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
