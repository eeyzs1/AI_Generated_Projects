import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';
import '../../../data/models/app_settings.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionTitle('界面设置'),
          _buildUIStyleSetting(context, settings, settingsNotifier),
          const SizedBox(height: 24),
          _buildSectionTitle('播放设置'),
          _buildPlaybackSetting(context, settings, settingsNotifier),
          const SizedBox(height: 24),
          _buildSectionTitle('关于'),
          _buildAboutInfo(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
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
    AppSettings settings,
    SettingsNotifier settingsNotifier,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('界面风格'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: UIStyle.values.map((style) {
                return ChoiceChip(
                  label: Text(_getStyleLabel(style)),
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

  Widget _buildPlaybackSetting(
    BuildContext context,
    AppSettings settings,
    SettingsNotifier settingsNotifier,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('播放设置'),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('记住播放位置'),
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

  Widget _buildAboutInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('RFPlayer'),
            const SizedBox(height: 8),
            const Text('版本: 1.0.0'),
            const SizedBox(height: 8),
            const Text('一个完全免费的媒体播放器'),
          ],
        ),
      ),
    );
  }

  String _getStyleLabel(UIStyle style) {
    switch (style) {
      case UIStyle.material3:
        return 'Material 3';
      case UIStyle.fluent:
        return 'Fluent';
      case UIStyle.adaptive:
        return '自适应';
      default:
        return '未知';
    }
  }
}