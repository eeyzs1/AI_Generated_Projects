import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rfdictionary/core/localization/app_localizations.dart';
import 'package:rfdictionary/features/llm/domain/model_manager.dart';
import 'package:rfdictionary/features/dictionary/domain/dictionary_manager.dart';

class InitScreen extends ConsumerStatefulWidget {
  const InitScreen({super.key});

  @override
  ConsumerState<InitScreen> createState() => _InitScreenState();
}

class _InitScreenState extends ConsumerState<InitScreen> {
  double _progress = 0.0;
  String _statusKey = 'initializing';

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    try {
      setState(() {
        _statusKey = 'loadingModelManager';
        _progress = 0.3;
      });
      
      await ref.read(modelManagerProvider.notifier).loadSavedModel();
      
      setState(() {
        _statusKey = 'loadingDictionaryManager';
        _progress = 0.6;
      });
      
      await ref.read(dictionaryManagerProvider.notifier).loadSavedDictionary();
      
      setState(() {
        _statusKey = 'initComplete';
        _progress = 1.0;
      });

      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      setState(() {
        _statusKey = 'initFailed';
        _progress = 1.0;
      });
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        context.go('/');
      }
    }
  }

  String _getLocalizedStatus(AppLocalizations l10n) {
    return switch (_statusKey) {
      'loadingModelManager' => l10n.loadingModelManager,
      'loadingDictionaryManager' => l10n.loadingDictionaryManager,
      'initComplete' => l10n.initComplete,
      'initFailed' => l10n.initFailed,
      _ => l10n.initializing,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.translate,
                size: 80,
              ),
              const SizedBox(height: 24),
              Text(
                '11Translator',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: 200,
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _getLocalizedStatus(l10n),
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
