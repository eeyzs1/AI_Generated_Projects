import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';
import 'package:rfdictionary/app.dart';
import 'package:rfdictionary/core/localization/app_localizations.dart';
import 'package:rfdictionary/core/utils/platform_utils.dart';
import 'package:rfdictionary/features/favorites/data/models/favorite_word.dart';
import 'package:rfdictionary/features/history/data/models/history_entry.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (PlatformUtils.isDesktop) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await Hive.initFlutter();
  Hive.registerAdapter(FavoriteWordAdapter());
  Hive.registerAdapter(HistoryEntryAdapter());
  await Hive.openBox<FavoriteWord>('favorites');
  await Hive.openBox<HistoryEntry>('history');

  final prefs = await SharedPreferences.getInstance();

  if (PlatformUtils.isWindows) {
    await windowManager.ensureInitialized();
    await windowManager.setMinimumSize(const Size(400, 600));
    await windowManager.setSize(const Size(900, 700));
    await windowManager.setTitle('RFDictionary');
    await windowManager.center();
  }

  runApp(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith((ref) => SettingsNotifier(prefs)),
      ],
      child: const App(),
    ),
  );
}
