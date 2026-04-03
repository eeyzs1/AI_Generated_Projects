import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rfdictionary/core/di/providers.dart';
import 'package:rfdictionary/core/localization/app_localizations.dart';
import 'package:rfdictionary/features/translation/domain/entities/language.dart';
import 'package:rfdictionary/features/translation/presentation/providers/translation_provider.dart';

class TranslationScreen extends ConsumerStatefulWidget {
  const TranslationScreen({super.key});

  @override
  ConsumerState<TranslationScreen> createState() => _TranslationScreenState();
}

class _TranslationScreenState extends ConsumerState<TranslationScreen> {
  final TextEditingController _sourceTextController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sourceTextController.addListener(() {
      ref.read(translationProvider.notifier).updateSourceText(_sourceTextController.text);
    });
  }

  @override
  void dispose() {
    _sourceTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(translationProvider);
    final notifier = ref.read(translationProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildLanguageSelector(l10n, state, notifier),
              const SizedBox(height: 16),
              _buildSourceTextField(l10n, state, notifier),
              const SizedBox(height: 16),
              _buildTranslateButton(l10n, state, notifier),
              const SizedBox(height: 16),
              _buildResultArea(l10n, state, notifier),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageSelector(
    AppLocalizations l10n,
    TranslationState state,
    TranslationNotifier notifier,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: _buildLanguageDropdown(
                value: state.sourceLang,
                onChanged: (lang) => notifier.updateSourceLang(lang!),
              ),
            ),
            const SizedBox(width: 16),
            IconButton(
              onPressed: () => notifier.swapLanguages(),
              icon: const Icon(Icons.swap_horiz),
              tooltip: '交换语言',
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildLanguageDropdown(
                value: state.targetLang,
                onChanged: (lang) => notifier.updateTargetLang(lang!),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageDropdown({
    required Language value,
    required ValueChanged<Language?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Language>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down),
          items: Language.values.map((lang) {
            return DropdownMenuItem<Language>(
              value: lang,
              child: Text(lang.displayName),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildSourceTextField(
    AppLocalizations l10n,
    TranslationState state,
    TranslationNotifier notifier,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '源文本',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (state.sourceText.isNotEmpty)
                  IconButton(
                    onPressed: () {
                      _sourceTextController.clear();
                      notifier.clear();
                    },
                    icon: const Icon(Icons.close),
                    tooltip: '清空',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _sourceTextController,
              maxLines: 5,
              minLines: 3,
              decoration: InputDecoration(
                hintText: '输入要翻译的文本...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              onSubmitted: (_) => notifier.translate(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranslateButton(
    AppLocalizations l10n,
    TranslationState state,
    TranslationNotifier notifier,
  ) {
    return FilledButton.icon(
      onPressed: state.isTranslating || state.sourceText.trim().isEmpty
          ? null
          : () => notifier.translate(),
      icon: state.isTranslating
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.translate),
      label: Text(state.isTranslating ? '翻译中...' : '翻译'),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildResultArea(
    AppLocalizations l10n,
    TranslationState state,
    TranslationNotifier notifier,
  ) {
    if (state.error != null) {
      return Card(
        elevation: 2,
        color: Theme.of(context).colorScheme.errorContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                state.error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => notifier.translate(),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.targetText.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            children: [
              Icon(Icons.translate_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                '翻译结果将显示在这里',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '翻译结果',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: state.targetText));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已复制到剪贴板')),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      tooltip: '复制',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                state.targetText,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
