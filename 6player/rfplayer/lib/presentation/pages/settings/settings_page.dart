import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../providers/settings_provider.dart';
import '../../../data/models/app_settings.dart' as app_settings;
import '../../../core/localization/app_localizations.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.settings),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionTitle(context, localizations.appearance),
          _buildUIStyleSetting(context, settings, settingsNotifier),
          const SizedBox(height: 16),
          _buildThemeModeSetting(context, settings, settingsNotifier),
          const SizedBox(height: 16),
          _buildLanguageSetting(context, settings, settingsNotifier),
          const SizedBox(height: 24),
          _buildSectionTitle(context, localizations.playback),
          _buildPlaybackSetting(context, settings, settingsNotifier),
          const SizedBox(height: 24),
          _buildSectionTitle(context, localizations.about),
          _buildAboutInfo(context),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildUIStyleSetting(
    BuildContext context,
    app_settings.AppSettings settings,
    SettingsNotifier settingsNotifier,
  ) {
    final localizations = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(localizations.uiStyle),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: app_settings.UIStyle.values.map((style) {
                return ChoiceChip(
                  label: Text(_getStyleLabel(context, style)),
                  selected: settings.uiStyle == style,
                  onSelected: (selected) {
                    if (selected) {
                      settingsNotifier.update(
                        settings.copyWith(uiStyle: style),
                      );
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeModeSetting(
    BuildContext context,
    app_settings.AppSettings settings,
    SettingsNotifier settingsNotifier,
  ) {
    final localizations = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(localizations.themeMode),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: app_settings.AppThemeMode.values.map((mode) {
                return ChoiceChip(
                  label: Text(_getThemeModeLabel(context, mode)),
                  selected: settings.themeMode == mode,
                  onSelected: (selected) {
                    if (selected) {
                      settingsNotifier.update(
                        settings.copyWith(themeMode: mode),
                      );
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _getThemeModeLabel(BuildContext context, app_settings.AppThemeMode mode) {
    final localizations = AppLocalizations.of(context)!;
    switch (mode) {
      case app_settings.AppThemeMode.system:
        return localizations.system;
      case app_settings.AppThemeMode.light:
        return localizations.light;
      case app_settings.AppThemeMode.dark:
        return localizations.dark;
    }
  }

  Widget _buildLanguageSetting(
    BuildContext context,
    app_settings.AppSettings settings,
    SettingsNotifier settingsNotifier,
  ) {
    final localizations = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(localizations.language),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: app_settings.AppLanguage.values.map((language) {
                return ChoiceChip(
                  label: Text(_getLanguageLabel(context, language)),
                  selected: settings.language == language,
                  onSelected: (selected) {
                    if (selected) {
                      settingsNotifier.update(
                        settings.copyWith(language: language),
                      );
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _getLanguageLabel(BuildContext context, app_settings.AppLanguage language) {
    final localizations = AppLocalizations.of(context)!;
    switch (language) {
      case app_settings.AppLanguage.system:
        return localizations.systemLanguage;
      case app_settings.AppLanguage.zhCn:
        return localizations.chinese;
      case app_settings.AppLanguage.enUs:
        return localizations.english;
    }
  }

  Widget _buildPlaybackSetting(
    BuildContext context,
    app_settings.AppSettings settings,
    SettingsNotifier settingsNotifier,
  ) {
    final localizations = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(localizations.playback),
            const SizedBox(height: 12),
            SwitchListTile(
              title: Text(localizations.rememberPlaybackPosition),
              value: settings.rememberPlaybackPosition,
              onChanged: (value) {
                settingsNotifier.update(
                  settings.copyWith(rememberPlaybackPosition: value),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutInfo(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(localizations.appName),
            const SizedBox(height: 8),
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                final version = snapshot.data?.version ?? '...';
                return Text('${localizations.version}: $version');
              },
            ),
            const SizedBox(height: 8),
            Text(localizations.freeMediaPlayer),
          ],
        ),
      ),
    );
  }

  String _getStyleLabel(BuildContext context, app_settings.UIStyle style) {
    final localizations = AppLocalizations.of(context)!;
    switch (style) {
      case app_settings.UIStyle.material3:
        return localizations.material3;
      case app_settings.UIStyle.fluent:
        return localizations.fluent;
      case app_settings.UIStyle.adaptive:
        return localizations.adaptive;
    }
  }
}