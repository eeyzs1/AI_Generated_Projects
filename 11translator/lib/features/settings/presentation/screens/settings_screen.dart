import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rfdictionary/core/localization/app_localizations.dart';
import 'package:rfdictionary/core/utils/platform_utils.dart';
import 'package:rfdictionary/features/llm/presentation/screens/model_download_screen.dart';

const List<Color> _presetColors = [
  Color(0xFFE8002D),
  Color(0xFF6750A4),
  Color(0xFF0061A4),
  Color(0xFF006C46),
  Color(0xFF9C4100),
  Color(0xFF7D5260),
  Color(0xFFFF9800),
  Color(0xFF2196F3),
  Color(0xFF4CAF50),
  Color(0xFFFF5722),
  Color(0xFF9C27B0),
  Color(0xFF00BCD4),
];

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.watch(settingsProvider.notifier);

    String getUIStyleLabel(UIStyle style) {
      return switch (style) {
        UIStyle.material3 => l10n.material3,
        UIStyle.fluent => l10n.fluent,
        UIStyle.adaptive => l10n.adaptive,
      };
    }

    String getThemeModeLabel(ThemeModeOption mode) {
      return switch (mode) {
        ThemeModeOption.system => l10n.system,
        ThemeModeOption.light => l10n.light,
        ThemeModeOption.dark => l10n.dark,
      };
    }

    String getLanguageLabel(LanguageOption lang) {
      return switch (lang) {
        LanguageOption.system => l10n.system,
        LanguageOption.zh => l10n.chinese,
        LanguageOption.en => l10n.english,
      };
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: ListView(
        children: [
          _SectionHeader(l10n.appearance),
          _OptionGroup(
            title: l10n.uiStyle,
            options: [
              (getUIStyleLabel(UIStyle.material3), UIStyle.material3),
              (getUIStyleLabel(UIStyle.fluent), UIStyle.fluent),
              (getUIStyleLabel(UIStyle.adaptive), UIStyle.adaptive),
            ],
            selectedValue: settings.uiStyle,
            onSelected: (value) async {
              await settingsNotifier.setUIStyle(value);
            },
          ),
          const SizedBox(height: 16),
          _OptionGroup(
            title: l10n.themeMode,
            options: [
              (getThemeModeLabel(ThemeModeOption.system), ThemeModeOption.system),
              (getThemeModeLabel(ThemeModeOption.light), ThemeModeOption.light),
              (getThemeModeLabel(ThemeModeOption.dark), ThemeModeOption.dark),
            ],
            selectedValue: settings.themeModeOption,
            onSelected: (value) async {
              await settingsNotifier.setThemeMode(value);
            },
          ),
          const SizedBox(height: 16),
          _ColorPickerGroup(
            title: l10n.accentColor,
            colors: _presetColors,
            selectedColor: settings.seedColor,
            onSelected: (color) async {
              await settingsNotifier.setSeedColor(color);
            },
          ),
          const SizedBox(height: 16),
          _OptionGroup(
            title: l10n.language,
            options: [
              (getLanguageLabel(LanguageOption.system), LanguageOption.system),
              (getLanguageLabel(LanguageOption.zh), LanguageOption.zh),
              (getLanguageLabel(LanguageOption.en), LanguageOption.en),
            ],
            selectedValue: settings.languageOption,
            onSelected: (value) async {
              await settingsNotifier.setLanguage(value);
            },
          ),
          const Divider(),
          _SectionHeader(l10n.aiFeatures),
          ListTile(
            title: Text(l10n.aiModel),
            subtitle: Text(l10n.notInstalled),
            trailing: FilledButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ModelDownloadScreen(),
                  ),
                );
              },
              child: Text(l10n.download),
            ),
          ),
          const Divider(),
          _SectionHeader(l10n.dataManagement),
          ListTile(
            title: Text(l10n.clearSearchHistory),
            leading: const Icon(Icons.history),
            onTap: () {},
          ),
          ListTile(
            title: Text(l10n.clearAllFavorites),
            leading: const Icon(Icons.star_outline),
            onTap: () {},
          ),
          const Divider(),
          _SectionHeader(l10n.about),
          ListTile(
            title: const Text(''),
            subtitle: Text(
              l10n.completelyFree,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFFE8002D),
              ),
            ),
          ),
          ListTile(
            title: Text(l10n.version),
            trailing: const Text('1.0.0'),
          ),
          ListTile(
            title: Text(l10n.dictionary),
            trailing: Text(l10n.ecdictInfo),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _OptionGroup<T extends Enum> extends ConsumerWidget {
  final String title;
  final List<(String, T)> options;
  final T selectedValue;
  final void Function(T) onSelected;

  const _OptionGroup({
    required this.title,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    UIStyle effectiveStyle = settings.uiStyle;
    if (effectiveStyle == UIStyle.adaptive) {
      effectiveStyle = PlatformUtils.isWindows ? UIStyle.fluent : UIStyle.material3;
    }
    final isFluent = effectiveStyle == UIStyle.fluent;

    if (isFluent) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: options.map((option) {
                    final (label, value) = option;
                    final isSelected = value == selectedValue;
                    return FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.surfaceVariant,
                        foregroundColor: isSelected
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        elevation: isSelected ? 2 : 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        side: isSelected
                            ? null
                            : BorderSide(
                                color: Theme.of(context).colorScheme.outline,
                                width: 1,
                              ),
                      ),
                      onPressed: () => onSelected(value),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: options.map((option) {
                  final (label, value) = option;
                  final isSelected = value == selectedValue;
                  return FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      backgroundColor: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.secondaryContainer,
                      foregroundColor: isSelected
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSecondaryContainer,
                      elevation: isSelected ? 1 : 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    onPressed: () => onSelected(value),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorPickerGroup extends ConsumerWidget {
  final String title;
  final List<Color> colors;
  final Color selectedColor;
  final void Function(Color) onSelected;

  const _ColorPickerGroup({
    required this.title,
    required this.colors,
    required this.selectedColor,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    UIStyle effectiveStyle = settings.uiStyle;
    if (effectiveStyle == UIStyle.adaptive) {
      effectiveStyle = PlatformUtils.isWindows ? UIStyle.fluent : UIStyle.material3;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: colors.map((color) {
                  final isSelected = color == selectedColor;
                  return GestureDetector(
                    onTap: () => onSelected(color),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.onSurface
                              : Colors.transparent,
                          width: isSelected ? 3 : 0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: isSelected
                          ? Icon(
                              Icons.check,
                              color: color.computeLuminance() > 0.5
                                  ? Colors.black
                                  : Colors.white,
                              size: 24,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
