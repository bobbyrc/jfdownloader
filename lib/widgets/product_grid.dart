import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../providers/download_provider.dart';
import '../providers/product_provider.dart';
import 'product_card.dart';

class ProductGrid extends StatelessWidget {
  const ProductGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ProductProvider>(
      builder: (context, productProvider, child) {
        final products = productProvider.products;

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 400,
            childAspectRatio: 0.75,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            return ProductCard(
              product: product,
              onDownload: () => _handleDownload(context, product),
            );
          },
        );
      },
    );
  }

  Future<void> _handleDownload(BuildContext context, Product product) async {
    try {
      // Let user choose download directory
      final selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Choose download location for ${product.name}',
      );

      if (selectedDirectory == null) return;

      final downloadProvider =
          Provider.of<DownloadProvider>(context, listen: false);
      await downloadProvider.downloadProduct(product, selectedDirectory);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Started downloading ${product.name}'),
            action: SnackBarAction(
              label: 'View Downloads',
              onPressed: () {
                // This would show the download panel
              },
            ),
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
}
