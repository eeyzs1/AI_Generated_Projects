import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../history/widgets/history_list_item.dart';
import '../../providers/history_provider.dart';
import '../../../core/localization/app_localizations.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final historyListAsync = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.recentPlays),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () {
              _showClearAllDialog(context, ref);
            },
          ),
        ],
      ),
      body: historyListAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('${loc.loadingFailed}: $error')),
        data: (historyList) {
          if (historyList.isEmpty) {
            return Center(child: Text(loc.noRecentPlays));
          }
          return ListView.builder(
            itemCount: historyList.length,
            itemBuilder: (context, index) {
              final history = historyList[index];
              return Dismissible(
                key: Key(history.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (direction) async {
                  await ref.read(historyActionsProvider).deleteHistory(history.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${loc.deleted}: ${history.displayName}')),
                    );
                  }
                },
                child: HistoryListItem(history: history),
              );
            },
          );
        },
      ),
    );
  }

  void _showClearAllDialog(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.clearHistory),
        content: Text(loc.sureToClearHistory),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.cancel),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(historyActionsProvider).clearAllHistory();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(loc.historyCleared)),
                );
              }
            },
            child: Text(loc.clearAll),
          ),
        ],
      ),
    );
  }
}