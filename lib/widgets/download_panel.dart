import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/download_progress.dart';
import '../providers/download_provider.dart';

class DownloadPanel extends StatelessWidget {
  const DownloadPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadProvider>(
      builder: (context, downloadProvider, child) {
        final downloads = downloadProvider.downloads.values.toList();

        return Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withOpacity(0.3),
                border: Border(
                  bottom: BorderSide(
                    color:
                        Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.download,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Downloads',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  if (downloadProvider.downloads.isNotEmpty)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) {
                        switch (value) {
                          case 'clear_completed':
                            downloadProvider.clearCompletedDownloads();
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'clear_completed',
                          child: Row(
                            children: [
                              Icon(Icons.clear_all),
                              SizedBox(width: 8),
                              Text('Clear Completed'),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // Overall progress
            if (downloadProvider.isDownloading)
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Overall Progress',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                        const Spacer(),
                        Text(
                          '${(downloadProvider.totalProgress * 100).toInt()}%',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: downloadProvider.totalProgress,
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${downloadProvider.activeDownloads.length} active downloads',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),

            // Downloads list
            Expanded(
              child: downloads.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.download_outlined,
                            size: 48,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No downloads yet',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Download files will appear here',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: downloads.length,
                      itemBuilder: (context, index) {
                        final download = downloads[index];
                        return _DownloadItem(download: download);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _DownloadItem extends StatelessWidget {
  final DownloadProgress download;

  const _DownloadItem({required this.download});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // File name and status
            Row(
              children: [
                Expanded(
                  child: Text(
                    download.fileName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildStatusIcon(context),
              ],
            ),

            const SizedBox(height: 8),

            // Progress bar (only for active downloads)
            if (download.status == DownloadStatus.downloading)
              Column(
                children: [
                  LinearProgressIndicator(
                    value: download.progress,
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        download.formattedSize,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Spacer(),
                      Text(
                        download.formattedSpeed,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),

            // Error message
            if (download.error != null)
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
                        download.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Action buttons
            if (download.status != DownloadStatus.completed)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (download.status == DownloadStatus.downloading)
                    TextButton(
                      onPressed: () =>
                          Provider.of<DownloadProvider>(context, listen: false)
                              .pauseDownload(download.fileId),
                      child: const Text('Pause'),
                    ),
                  if (download.status == DownloadStatus.paused)
                    TextButton(
                      onPressed: () =>
                          Provider.of<DownloadProvider>(context, listen: false)
                              .resumeDownload(download.fileId),
                      child: const Text('Resume'),
                    ),
                  if (download.status == DownloadStatus.failed ||
                      download.status == DownloadStatus.cancelled)
                    TextButton(
                      onPressed: () =>
                          Provider.of<DownloadProvider>(context, listen: false)
                              .retryDownload(download.fileId),
                      child: const Text('Retry'),
                    ),
                  if (download.status != DownloadStatus.completed)
                    TextButton(
                      onPressed: () =>
                          Provider.of<DownloadProvider>(context, listen: false)
                              .cancelDownload(download.fileId),
                      child: const Text('Cancel'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(BuildContext context) {
    switch (download.status) {
      case DownloadStatus.pending:
        return Icon(
          Icons.schedule,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
      case DownloadStatus.downloading:
        return Text(
          '${(download.progress * 100).toInt()}%',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.primary,
              ),
        );
      case DownloadStatus.completed:
        return Icon(
          Icons.check_circle,
          size: 16,
          color: Theme.of(context).colorScheme.primary,
        );
      case DownloadStatus.failed:
        return Icon(
          Icons.error,
          size: 16,
          color: Theme.of(context).colorScheme.error,
        );
      case DownloadStatus.cancelled:
        return Icon(
          Icons.cancel,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
      case DownloadStatus.paused:
        return Icon(
          Icons.pause_circle,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
    }
  }
}
