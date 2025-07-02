import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/product.dart';
import '../models/download_progress.dart';
import '../providers/download_provider.dart';
import '../providers/auth_provider.dart';
import '../services/justflight_service.dart';
import '../services/logger_service.dart';
import '../widgets/cached_network_image.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Product product;

  const ProductDetailsScreen({
    super.key,
    required this.product,
  });

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  bool _isLoading = true;
  String? _error;
  Product? _detailedProduct;
  List<ProductFile> _downloadableFiles = [];
  Map<String, String> _installationInfo = {};
  String? _orderNumber;
  DateTime? _purchaseDate;
  String? _version;
  final _logger = LoggerService();

  @override
  void initState() {
    super.initState();
    _loadProductDetails();
  }

  Future<void> _loadProductDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
      // Immediately set fallback data
      _detailedProduct = widget.product;
      _downloadableFiles = widget.product.files;
    });

    try {
      // Check if we're still logged in via the AuthProvider
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      if (!authProvider.isLoggedIn) {
        throw Exception('Not logged in. Please log in again.');
      }

      final justFlightService = JustFlightService();
      
      // Since we just successfully loaded products, we should still be logged in
      // Skip the login check to avoid potential session conflicts
      _logger.debug('Attempting to fetch detailed product info for: ${widget.product.name} (ID: ${widget.product.id})');
      
      try {
        final productDetails = await justFlightService.getProductDetails(widget.product.id);
        
        _logger.info('Successfully fetched product details for ${widget.product.name}');
        _logger.debug('  - Product info: ${productDetails['product'] != null ? 'Available' : 'Not available'}');
        _logger.debug('  - Files: ${(productDetails['files'] as List?)?.length ?? 0} files');
        _logger.debug('  - Installation info: ${(productDetails['installationInfo'] as Map?)?.length ?? 0} items');
        
        setState(() {
          if (productDetails['product'] != null) {
            _detailedProduct = productDetails['product'] as Product;
          }
          final detailedFiles = productDetails['files'] as List<ProductFile>?;
          if (detailedFiles != null && detailedFiles.isNotEmpty) {
            _downloadableFiles = detailedFiles;
            _logger.debug('Updated downloadable files: ${detailedFiles.map((f) => f.name).join(', ')}');
          }
          _installationInfo = productDetails['installationInfo'] as Map<String, String>? ?? {};
          _orderNumber = productDetails['orderNumber'] as String?;
          _purchaseDate = productDetails['purchaseDate'] as DateTime?;
          _version = productDetails['version'] as String?;
          
          _isLoading = false;
        });
      } catch (detailsError) {
        _logger.warning('Could not fetch detailed product info: $detailsError');
        setState(() {
          _error = 'Could not load detailed information - showing basic product details';
          _isLoading = false;
        });
      }
      
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
        // Keep the fallback data we already set
      });
      
      // If it's a login/session error, show a helpful message
      if (e.toString().contains('logged in') || e.toString().contains('session') || e.toString().contains('login')) {
        _showLoginErrorDialog();
      }
    }
  }

  void _showLoginErrorDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Session Expired'),
        content: const Text(
          'Your login session has expired. Please log in again to view product details.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to main screen
              
              // Trigger logout to show login screen
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              authProvider.logout();
            },
            child: const Text('Log In Again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product.name),
        actions: [
          if (!_isLoading && _downloadableFiles.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: () => _downloadAllFiles(),
              tooltip: 'Download All Files',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading product details...'),
          ],
        ),
      );
    }

    // Show content even if there was an error, but use fallback data
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProductHeader(),
          const Divider(),
          if (_error != null && _installationInfo.isEmpty) 
            _buildErrorBanner(),
          _buildInstallationInfo(),
          if (_installationInfo.isNotEmpty) const Divider(),
          _buildDownloadableFiles(),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Limited Information Available',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Could not load detailed product information. Showing basic details only.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _loadProductDetails,
            child: Text(
              'Retry',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductHeader() {
    final product = _detailedProduct ?? widget.product;
    
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
                    child: CachedNetworkImage(
                      imageUrl: product.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: _buildPlaceholderImage(),
                      errorWidget: _buildPlaceholderImage(),
                    ),
                  )
                : _buildPlaceholderImage(),
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
                      Icons.receipt_long,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Order: ${_orderNumber ?? product.id}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Purchased: ${_formatDate(_purchaseDate ?? product.purchaseDate)}',
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
                      'Version: ${_version ?? product.version}',
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

  Widget _buildPlaceholderImage() {
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

  Widget _buildInstallationInfo() {
    if (_installationInfo.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Installation Information',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 12),
          
          ..._installationInfo.entries.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    '${entry.key}:',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    entry.value,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildDownloadableFiles() {
    final files = _downloadableFiles.isNotEmpty ? _downloadableFiles : widget.product.files;
    
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
              'There may be an issue loading the download links for this product.',
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
              return _buildFileCard(file);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFileCard(ProductFile file) {
    return Consumer<DownloadProvider>(
      builder: (context, downloadProvider, child) {      final progress = downloadProvider.getDownloadProgress(file.id);
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
                  _buildDownloadActions(file, progress),
                ],
              ),
              
              // Download progress and error display
              if (progress != null) ...[
                const SizedBox(height: 12),
                _buildDownloadStatus(progress),
              ],
            ],
          ),
        ),
      );
      },
    );
  }

  Widget _buildDownloadActions(ProductFile file, DownloadProgress? progress) {
    final isDownloaded = file.isDownloaded;
    
    if (progress == null) {
      // No download in progress - show download button
      return ElevatedButton.icon(
        onPressed: isDownloaded ? null : () => _downloadFile(file),
        icon: Icon(isDownloaded ? Icons.check : Icons.download),
        label: Text(isDownloaded ? 'Downloaded' : 'Download'),
        style: ElevatedButton.styleFrom(
          backgroundColor: isDownloaded 
              ? Theme.of(context).colorScheme.surfaceVariant
              : null,
        ),
      );
    }

    // Download in progress or completed - show status and actions
    switch (progress.status) {
      case DownloadStatus.downloading:
        return IconButton(
          onPressed: () => Provider.of<DownloadProvider>(context, listen: false)
              .cancelDownload(file.id),
          icon: const Icon(Icons.close),
          tooltip: 'Cancel Download',
        );
      
      case DownloadStatus.completed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Completed',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        );
      
      case DownloadStatus.failed:
      case DownloadStatus.cancelled:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton.icon(
              onPressed: () => Provider.of<DownloadProvider>(context, listen: false)
                  .retryDownload(file.id),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: () => Provider.of<DownloadProvider>(context, listen: false)
                  .cancelDownload(file.id),
              icon: const Icon(Icons.close),
              tooltip: 'Remove',
            ),
          ],
        );
      
      case DownloadStatus.pending:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            const Text('Queued'),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => Provider.of<DownloadProvider>(context, listen: false)
                  .cancelDownload(file.id),
              icon: const Icon(Icons.close),
              tooltip: 'Cancel',
            ),
          ],
        );
      
      case DownloadStatus.paused:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton.icon(
              onPressed: () => Provider.of<DownloadProvider>(context, listen: false)
                  .resumeDownload(file.id),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Resume'),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: () => Provider.of<DownloadProvider>(context, listen: false)
                  .cancelDownload(file.id),
              icon: const Icon(Icons.close),
              tooltip: 'Cancel',
            ),
          ],
        );
    }
  }

  Widget _buildDownloadStatus(DownloadProgress progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (progress.status == DownloadStatus.downloading) ...[
          LinearProgressIndicator(
            value: progress.progress,
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
        
        // Error message
        if (progress.error != null)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 16,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    progress.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
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

  Future<void> _downloadFile(ProductFile file) async {
    try {
      final selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Choose download location for ${file.name}',
      );

      if (selectedDirectory == null) return;

      final downloadProvider = Provider.of<DownloadProvider>(context, listen: false);
      await downloadProvider.downloadFile(file, selectedDirectory);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Started downloading ${file.name}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start download: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _downloadAllFiles() async {
    try {
      final selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Choose download location for ${widget.product.name}',
      );

      if (selectedDirectory == null) return;

      final downloadProvider = Provider.of<DownloadProvider>(context, listen: false);
      final filesToDownload = _downloadableFiles.isNotEmpty ? _downloadableFiles : widget.product.files;
      
      for (final file in filesToDownload) {
        if (!file.isDownloaded) {
          await downloadProvider.downloadFile(file, selectedDirectory);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Started downloading all files for ${widget.product.name}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start downloads: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
