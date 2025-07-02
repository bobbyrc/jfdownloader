import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/product.dart';
import '../providers/download_provider.dart';

class SimpleProductDetailsScreen extends StatelessWidget {
  final Product product;

  const SimpleProductDetailsScreen({
    super.key,
    required this.product,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(product.name),
        actions: [
          if (product.files.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: () => _downloadAllFiles(context),
              tooltip: 'Download All Files',
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProductHeader(context),
            const Divider(),
            _buildDownloadableFiles(context),
          ],
        ),
      ),
    );
  }

  Widget _buildProductHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product image
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: product.imageUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      product.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildPlaceholderImage(context);
                      },
                    ),
                  )
                : _buildPlaceholderImage(context),
          ),
          
          const SizedBox(width: 16),
          
          // Product info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    product.category,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                if (product.description.isNotEmpty)
                  Text(
                    product.description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Purchased: ${product.purchaseDate.day}/${product.purchaseDate.month}/${product.purchaseDate.year}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Version: ${product.version}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.flight_takeoff,
          size: 32,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 4),
        Text(
          'JustFlight',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadableFiles(BuildContext context) {
    final files = product.files;
    
    if (files.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              Icons.folder_open,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No downloadable files found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'This product may not have downloadable files configured.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Downloadable Files',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${files.length} files',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: files.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final file = files[index];
              return _buildFileCard(context, file);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFileCard(BuildContext context, ProductFile file) {
    return Consumer<DownloadProvider>(
      builder: (context, downloadProvider, child) {
        final progress = downloadProvider.getDownloadProgress(file.id);
        final isDownloading = progress != null && progress.status.name != 'completed';
        final isDownloaded = file.isDownloaded;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _getFileIcon(file.fileType),
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            file.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                file.fileType.toUpperCase(),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (file.sizeInMB > 0) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '•',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${file.sizeInMB.toStringAsFixed(1)} MB',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (isDownloading)
                      _buildDownloadProgress(context, progress!)
                    else
                      ElevatedButton.icon(
                        onPressed: isDownloaded ? null : () => _downloadFile(context, file),
                        icon: Icon(isDownloaded ? Icons.check : Icons.download),
                        label: Text(isDownloaded ? 'Downloaded' : 'Download'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDownloaded 
                              ? Theme.of(context).colorScheme.surfaceVariant
                              : null,
                        ),
                      ),
                  ],
                ),
                
                if (isDownloading) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: progress!.progress,
                    backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        progress.status.name.toUpperCase(),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        '${(progress.progress * 100).toInt()}%',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDownloadProgress(BuildContext context, progress) {
    return SizedBox(
      width: 60,
      child: Column(
        children: [
          CircularProgressIndicator(
            value: progress.progress,
            strokeWidth: 3,
          ),
          const SizedBox(height: 4),
          Text(
            '${(progress.progress * 100).toInt()}%',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.folder_zip;
      case 'exe':
      case 'msi':
        return Icons.apps;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'txt':
      case 'readme':
        return Icons.description;
      default:
        return Icons.file_download;
    }
  }

  Future<void> _downloadFile(BuildContext context, ProductFile file) async {
    try {
      final selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Choose download location for ${file.name}',
      );

      if (selectedDirectory == null) return;

      final downloadProvider = Provider.of<DownloadProvider>(context, listen: false);
      await downloadProvider.downloadFile(file, selectedDirectory);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Started downloading ${file.name}'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start download: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _downloadAllFiles(BuildContext context) async {
    try {
      final selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Choose download location for ${product.name}',
      );

      if (selectedDirectory == null) return;

      final downloadProvider = Provider.of<DownloadProvider>(context, listen: false);
      
      for (final file in product.files) {
        if (!file.isDownloaded) {
          await downloadProvider.downloadFile(file, selectedDirectory);
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Started downloading all files for ${product.name}'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start downloads: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
