# 本地翻译架构指南 — Encoder-Decoder + 兜底 LLM

## 1. 架构概览

本项目采用**混合架构**，根据文本类型自动选择最优翻译引擎：

```
┌─────────────────────────────────────────────────────────┐
│                    翻译请求                              │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│              文本长度/复杂度判断                          │
│  ┌───────────────────────────────────────────────────┐  │
│  │ 单词/短语：≤ 3 词 且 ≤ 20 字符                    │  │
│  │  → 使用 StarDict 词典查询（快速、准确）             │  │
│  └───────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────┐  │
│  │ 长句/段落：> 3 词 或 > 20 字符                    │  │
│  │  → 使用 OPUS-MT (MarianNMT) 翻译                  │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
                ┌───────────────────┐
                │  翻译成功？        │
                └───────────────────┘
                      │   │
                   是 │   │ 否
                      │   │
                      ▼   ▼
           返回结果      兜底 LLM (Qwen2.5-0.5B)
```

**核心约束：纯本地，不调用任何远程 API。**

---

## 2. 组件选型

### 2.1 主翻译引擎对比

| 引擎类型 | 模型 | 适用场景 | 优势 | 劣势 |
|----------|------|----------|------|------|
| **词典查询** | StarDict (Wiktionary) | 单词、短语 | 快速、准确、无需额外模型 | 仅支持词典中的词条 |
| **Encoder-Decoder** | OPUS-MT (MarianNMT) | 长句、段落 | 专为翻译优化、质量高、模型小 | 需要独立的翻译模型 |
| **Decoder-only LLM** | Qwen2.5-0.5B-Instruct | 兜底、特殊情况 | 灵活性高、能处理任意文本 | 翻译质量不如专用模型、资源占用大 |

**推荐策略（已确定）：**
- **单词/短语**：优先使用 StarDict 词典
- **长句/段落**：使用 OPUS-MT (MarianNMT)
- **兜底**：Qwen2.5-0.5B 处理边缘情况

---

## 3. OPUS-MT 模型

### 3.1 推荐模型

| 语言对 | 模型名称 | 大小 | 下载来源 |
|--------|----------|------|----------|
| 英语 → 汉语 | opus-mt-en-zh | ~150MB | Hugging Face: Helsinki-NLP/opus-mt-en-zh |
| 汉语 → 英语 | opus-mt-zh-en | ~150MB | Hugging Face: Helsinki-NLP/opus-mt-zh-en |

### 3.2 模型文件结构

OPUS-MT 模型通常包含以下文件：
```
opus-mt-en-zh/
├── config.json
├── source.spm        # 源语言分词器
├── target.spm        # 目标语言分词器
├── vocab.json
└── pytorch_model.bin (或 model.bin)
```

---

## 4. 集成方案

### 4.1 Python 后端架构

Python 后端负责：
1. **MarianNMT/OPUS-MT 翻译**（长句/段落）
2. **StarDict 词典查询**（单词/短语）
3. **兜底 LLM 推理**（边缘情况）

```python
# python_backend/llm_server.py 新增功能
class TranslationServer:
    def __init__(self, opus_mt_dir: str, llm_model_path: str):
        self.opus_mt = OpusMtTranslator(opus_mt_dir)
        self.llm = LlmFallback(llm_model_path)
        self.stardict = StarDictManager()
    
    def translate(self, text: str, source_lang: str, target_lang: str) -> str:
        # 1. 判断文本类型
        if is_word_or_phrase(text):
            # 2. 尝试词典查询
            dict_result = self.stardict.lookup_word(text)
            if dict_result:
                return dict_result
            # 3. 词典失败，使用兜底 LLM
            return self.llm.translate(text, source_lang, target_lang)
        else:
            # 4. 长句使用 OPUS-MT
            try:
                return self.opus_mt.translate(text, source_lang, target_lang)
            except Exception:
                # 5. OPUS-MT 失败，使用兜底 LLM
                return self.llm.translate(text, source_lang, target_lang)
```

### 4.2 依赖安装

```bash
# python_backend/requirements.txt 更新
llama-cpp-python>=0.2.0
pystardict>=0.9.0
zstandard>=0.22.0
transformers>=4.35.0
torch>=2.0.0
sentencepiece>=0.1.99
sacremoses>=0.0.53
```

---

## 5. Dart 端集成

### 5.1 翻译 Provider 更新

```dart
// lib/features/translation/presentation/providers/translation_provider.dart
Future<void> translate() async {
  // 1. 判断文本类型
  final isWordOrPhrase = _isWordOrPhrase(state.sourceText);
  
  if (isWordOrPhrase) {
    // 2. 单词/短语：优先使用词典
    final dictResult = await _tryDictionaryTranslation();
    if (dictResult != null) {
      state = state.copyWith(
        targetText: dictResult,
        source: TranslationSource.dictionary,
      );
      return;
    }
    // 3. 词典失败，使用兜底 LLM
    final llmResult = await _tryFallbackTranslation();
    state = state.copyWith(
      targetText: llmResult,
      source: TranslationSource.llmFallback,
    );
  } else {
    // 4. 长句：使用 OPUS-MT
    try {
      final mtResult = await _tryOpusMtTranslation();
      state = state.copyWith(
        targetText: mtResult,
        source: TranslationSource.opusMt,
      );
    } catch (_) {
      // 5. OPUS-MT 失败，使用兜底 LLM
      final llmResult = await _tryFallbackTranslation();
      state = state.copyWith(
        targetText: llmResult,
        source: TranslationSource.llmFallback,
      );
    }
  }
}
```

---

## 6. 降级策略

当任何组件不可用时，应用仍可正常使用：

```
用户发起翻译
    │
    ├─── OPUS-MT 可用？ ──是──▶ 使用 OPUS-MT
    │       │
    │       否
    │       │
    ├─── 是单词/短语？ ──是──▶ 词典可用？ ──是──▶ 使用词典
    │       │                           │
    │       否                           否
    │       │                           │
    └─── 兜底 LLM 可用？ ──是──▶ 使用 LLM
            │
            否
            │
        显示"翻译功能暂不可用"
```

---

## 7. 模型文件分发

### 方案：首次使用时下载（推荐）

首次使用翻译功能时触发下载流程：
1. 检测所需模型是否存在
2. 不存在则提示用户下载
3. 支持断点续传，显示实时进度

```dart
// 模型下载顺序
1. OPUS-MT 模型（优先，因为是主要翻译引擎）
2. 兜底 LLM 模型（备用）
```

### 模型存储路径

```
Windows: %USERPROFILE%\Documents\11Translator\models\
├── opus-mt/
│   ├── opus-mt-en-zh/
│   └── opus-mt-zh-en/
└── llm/
    └── qwen2.5-0.5b-instruct-q4_k_m.gguf
```

---

## 8. 详细的 OPUS-MT 集成指南

详见 [docs/09_marian_opus_mt_guide.md](./09_marian_opus_mt_guide.md)
