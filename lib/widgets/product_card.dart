import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/download_provider.dart';
import '../screens/product_details_screen.dart';
import 'cached_network_image.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onDownload;

  const ProductCard({
    super.key,
    required this.product,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _navigateToProductDetails(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Product image
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: product.imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: product.imageUrl,
                        placeholder: _buildPlaceholderImage(context),
                        errorWidget: _buildPlaceholderImage(context),
                      )
                    : _buildPlaceholderImage(context),
              ),
            ),

            // Product information
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product name and category
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .secondaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            product.category,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSecondaryContainer,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Description
                    if (product.description.isNotEmpty)
                      Expanded(
                        child: Text(
                          product.description,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                    const SizedBox(height: 12),

                    // Download status and button
                    Consumer<DownloadProvider>(
                      builder: (context, downloadProvider, child) {
                        final hasActiveDownloads = product.files.any((file) {
                          final progress =
                              downloadProvider.getDownloadProgress(file.id);
                          return progress != null &&
                              progress.status.name != 'completed';
                        });

                        if (hasActiveDownloads) {
                          return _buildDownloadProgress(
                              context, downloadProvider);
                        }

                        return SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: product.isDownloaded ? null : onDownload,
                            icon: Icon(product.isDownloaded
                                ? Icons.check
                                : Icons.download),
                            label: Text(product.isDownloaded
                                ? 'Downloaded'
                                : 'Download'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: product.isDownloaded
                                  ? Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToProductDetails(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProductDetailsScreen(product: product),
      ),
    );
  }

  Widget _buildPlaceholderImage(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.flight_takeoff,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            'JustFlight',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadProgress(
      BuildContext context, DownloadProvider downloadProvider) {
    final activeDownloads = product.files
        .map((file) => downloadProvider.getDownloadProgress(file.id))
        .where((progress) =>
            progress != null && progress.status.name != 'completed')
        .toList();

    if (activeDownloads.isEmpty) {
      return const SizedBox.shrink();
    }

    final totalProgress = activeDownloads.fold<double>(
          0.0,
          (sum, progress) => sum + (progress?.progress ?? 0.0),
        ) /
        activeDownloads.length;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: totalProgress,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${(totalProgress * 100).toInt()}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Downloading ${activeDownloads.length} files',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            TextButton(
              onPressed: () {
                for (final file in product.files) {
                  downloadProvider.cancelDownload(file.id);
                }
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      ],
    );
  }
}
