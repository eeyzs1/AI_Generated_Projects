part of 'llm_service.dart';

typedef LlmServiceRef = Ref;

abstract class _$LlmService extends AutoDisposeNotifier<LlmStatus> {
}

final llmServiceProvider = AutoDisposeNotifierProvider<LlmService, LlmStatus>(
  LlmService.new,
  name: r'llmService',
  dependencies: const [],
);
