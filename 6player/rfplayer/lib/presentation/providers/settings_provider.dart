import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/models/app_settings.dart';

final settingsRepositoryProvider = Provider((ref) => SettingsRepository());

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier(ref);
});

class SettingsNotifier extends StateNotifier<AppSettings> {
  final Ref ref;

  SettingsNotifier(this.ref) : super(const AppSettings()) {
    loadSettings();
  }

  Future<void> loadSettings() async {
    final settings = await ref.read(settingsRepositoryProvider).load();
    state = settings;
  }

  Future<void> update(AppSettings settings) async {
    state = settings;
    await ref.read(settingsRepositoryProvider).save(settings);
  }
}