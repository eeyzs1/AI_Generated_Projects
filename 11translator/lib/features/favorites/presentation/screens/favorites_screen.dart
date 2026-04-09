import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rfdictionary/core/localization/app_localizations.dart';
import 'package:rfdictionary/features/translation/domain/translation_history_provider.dart';
import 'package:rfdictionary/features/translation/data/models/translation_history.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final favoritesAsync = ref.watch(translationFavoriteListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.favorites),
      ),
      body: favoritesAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star_border, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    l10n.noFavoritesYet,
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.tapStarToFavorite,
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _FavoriteListItem(item: item);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('$e', style: const TextStyle(color: Colors.red)),
        ),
      ),
    );
  }
}

class _FavoriteListItem extends ConsumerWidget {
  final TranslationHistory item;

  const _FavoriteListItem({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text(item.sourceText),
      subtitle: Text(item.targetText),
      trailing: IconButton(
        icon: const Icon(Icons.star, color: Colors.amber),
        onPressed: () {
          ref.read(translationHistoryListProvider.notifier).toggleFavorite(item);
        },
      ),
    );
  }
}
