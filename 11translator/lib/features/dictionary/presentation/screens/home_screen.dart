import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rfdictionary/core/localization/app_localizations.dart';
import 'package:rfdictionary/features/dictionary/presentation/providers/search_provider.dart';
import 'package:rfdictionary/features/translation/domain/translation_history_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final searchQuery = ref.watch(searchQueryProvider);
    final focusNode = ref.watch(searchFocusProvider);
    final suggestionsAsync = ref.watch(searchSuggestionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                focusNode: focusNode,
                decoration: InputDecoration(
                  hintText: l10n.searchHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            ref.read(searchQueryProvider.notifier).state = '';
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  ref.read(searchQueryProvider.notifier).state = value;
                },
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    context.push('/word/${Uri.encodeComponent(value)}');
                  }
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: searchQuery.length >= 2
                    ? _buildSuggestions(context, ref, suggestionsAsync)
                    : _buildRecentSearches(context, ref, l10n),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestions(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<String>> suggestionsAsync,
  ) {
    return suggestionsAsync.when(
      data: (suggestions) {
        if (suggestions.isEmpty) {
          return Center(
            child: Text(
              'No suggestions',
              style: TextStyle(color: Colors.grey[600]),
            ),
          );
        }
        return ListView.builder(
          itemCount: suggestions.length,
          itemBuilder: (context, index) {
            final word = suggestions[index];
            return ListTile(
              leading: const Icon(Icons.search, size: 20),
              title: Text(word),
              onTap: () {
                context.push('/word/${Uri.encodeComponent(word)}');
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildRecentSearches(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    final historyAsync = ref.watch(translationHistoryListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.recentSearches,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: historyAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        l10n.startSearching,
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
              }
              final recent = items.take(10).toList();
              return ListView.builder(
                itemCount: recent.length,
                itemBuilder: (context, index) {
                  final item = recent[index];
                  return ListTile(
                    leading: const Icon(Icons.history, size: 20),
                    title: Text(item.sourceText),
                    subtitle: Text(
                      item.targetText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Icon(
                      item.isFavorite ? Icons.star : null,
                      size: 18,
                      color: item.isFavorite ? Colors.amber : null,
                    ),
                    onTap: () {
                      context.push('/word/${Uri.encodeComponent(item.sourceText)}');
                    },
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    l10n.startSearching,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
