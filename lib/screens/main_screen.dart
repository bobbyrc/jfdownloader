import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/product_provider.dart';
import '../providers/download_provider.dart';
import '../widgets/product_grid.dart';
import '../widgets/search_bar.dart';
import '../widgets/download_panel.dart';
import 'advanced_settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool _showDownloadPanel = false;
  bool _fetchImages = true; // Default to true for better user experience

  @override
  void initState() {
    super.initState();
    // Load products when the screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProductProvider>(context, listen: false)
          .loadProducts(fetchImages: _fetchImages);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.flight_takeoff),
            SizedBox(width: 8),
            Text('JustFlight Downloader'),
          ],
        ),
        actions: [
          Consumer<DownloadProvider>(
            builder: (context, downloadProvider, child) {
              final activeDownloads = downloadProvider.activeDownloads.length;
              return IconButton(
                icon: Badge(
                  label: Text('$activeDownloads'),
                  isLabelVisible: activeDownloads > 0,
                  child: const Icon(Icons.download),
                ),
                onPressed: () =>
                    setState(() => _showDownloadPanel = !_showDownloadPanel),
                tooltip: 'Downloads',
              );
            },
          ),
          Consumer<ProductProvider>(
            builder: (context, productProvider, child) {
              return IconButton(
                icon: productProvider.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                onPressed: productProvider.isLoading
                    ? null
                    : () => productProvider.refreshProducts(
                        fetchImages: _fetchImages),
                tooltip: 'Refresh',
              );
            },
          ),
          const SizedBox(width: 8),
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              return PopupMenuButton<String>(
                tooltip: 'Account',
                icon: const Icon(Icons.account_circle),
                onSelected: (value) {
                  switch (value) {
                    case 'logout':
                      _handleLogout();
                      break;
                    case 'settings':
                      _showSettings();
                      break;
                    case 'advanced':
                      _showAdvancedSettings();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  if (authProvider.username != null)
                    PopupMenuItem<String>(
                      enabled: false,
                      child: Text(
                        authProvider.username!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const PopupMenuItem<String>(
                    value: 'settings',
                    child: Row(
                      children: [
                        Icon(Icons.settings),
                        SizedBox(width: 8),
                        Text('Settings'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'advanced',
                    child: Row(
                      children: [
                        Icon(Icons.tune),
                        SizedBox(width: 8),
                        Text('Advanced'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout),
                        SizedBox(width: 8),
                        Text('Logout'),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Search and filter bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withOpacity(0.3),
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
            ),
            child: const CustomSearchBar(),
          ),

          // Main content area
          Expanded(
            child: Row(
              children: [
                // Products area
                Expanded(
                  flex: _showDownloadPanel ? 2 : 1,
                  child: Consumer<ProductProvider>(
                    builder: (context, productProvider, child) {
                      if (productProvider.isLoading &&
                          productProvider.products.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Loading your products...'),
                            ],
                          ),
                        );
                      }

                      // Show progress bar for image fetching
                      if (productProvider.isFetchingImages) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Products are loaded, show them with progress overlay
                              if (productProvider.products.isNotEmpty) ...[
                                const Expanded(
                                  child: ProductGrid(),
                                ),
                                // Progress overlay at the bottom
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color:
                                        Theme.of(context).colorScheme.surface,
                                    border: Border(
                                      top: BorderSide(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outline
                                            .withOpacity(0.2),
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.image, size: 20),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              productProvider.progressMessage,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium,
                                            ),
                                          ),
                                          Text(
                                            '${productProvider.completedProducts}/${productProvider.totalProducts}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      LinearProgressIndicator(
                                        value: productProvider.imageProgress,
                                        backgroundColor: Theme.of(context)
                                            .colorScheme
                                            .outline
                                            .withOpacity(0.2),
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else ...[
                                // No products yet, just show progress
                                const CircularProgressIndicator(),
                                const SizedBox(height: 16),
                                Text(
                                  productProvider.progressMessage,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: 300,
                                  child: LinearProgressIndicator(
                                    value: productProvider.imageProgress,
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .outline
                                        .withOpacity(0.2),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${productProvider.completedProducts}/${productProvider.totalProducts} products',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ],
                          ),
                        );
                      }

                      if (productProvider.error != null) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Error loading products',
                                style:
                                    Theme.of(context).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                productProvider.error!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () =>
                                    productProvider.refreshProducts(),
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                              ),
                            ],
                          ),
                        );
                      }

                      if (productProvider.products.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 64,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No products found',
                                style:
                                    Theme.of(context).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Make sure you have purchased products from JustFlight\nand that you\'re logged in with the correct account.',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () =>
                                    productProvider.refreshProducts(),
                                icon: const Icon(Icons.refresh),
                                label: const Text('Refresh'),
                              ),
                            ],
                          ),
                        );
                      }

                      return const ProductGrid();
                    },
                  ),
                ),

                // Download panel
                if (_showDownloadPanel)
                  Container(
                    width: 400,
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withOpacity(0.2),
                        ),
                      ),
                    ),
                    child: const DownloadPanel(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleLogout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content: Consumer<DownloadProvider>(
          builder: (context, downloadProvider, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('Max Concurrent Downloads'),
                  subtitle: Text('${downloadProvider.maxConcurrentDownloads}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: downloadProvider.maxConcurrentDownloads > 1
                            ? () => downloadProvider.setMaxConcurrentDownloads(
                                downloadProvider.maxConcurrentDownloads - 1)
                            : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: downloadProvider.maxConcurrentDownloads < 10
                            ? () => downloadProvider.setMaxConcurrentDownloads(
                                downloadProvider.maxConcurrentDownloads + 1)
                            : null,
                      ),
                    ],
                  ),
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('Fetch High-Quality Images'),
                  subtitle: const Text(
                      'Download product images from JustFlight website\n(slower but better looking)'),
                  value: _fetchImages,
                  onChanged: (value) {
                    setState(() {
                      _fetchImages = value;
                    });
                    Navigator.of(context).pop();
                    // Optionally refresh products if toggling to enable images
                    if (value) {
                      Provider.of<ProductProvider>(context, listen: false)
                          .refreshProducts();
                    }
                  },
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAdvancedSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AdvancedSettingsScreen(),
      ),
    );
  }
}
