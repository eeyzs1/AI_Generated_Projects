import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/models/app_settings.dart';

final settingsRepositoryProvider = Provider((ref) => SettingsRepository());

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier(ref);
});

class SettingsNotifier extends StateNotifier<AppSettings> {
  final Ref _ref;

  SettingsNotifier(this._ref) : super(const AppSettings()) {
    loadSettings();
  }

  Future<void> loadSettings() async {
    try {
      final settings = await _ref.read(settingsRepositoryProvider).load();
      state = settings;
    } catch (e) {
      debugPrint('[SettingsNotifier] Failed to load settings: $e');
    }
  }

  Future<void> update(AppSettings settings) async {
    final previousState = state;
    try {
      await _ref.read(settingsRepositoryProvider).save(settings);
      state = settings;
    } catch (e) {
      debugPrint('[SettingsNotifier] Failed to save settings: $e');
      state = previousState;
    }
  }
}
