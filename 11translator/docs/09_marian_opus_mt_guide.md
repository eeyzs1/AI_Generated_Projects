# MarianNMT / OPUS-MT 集成详细指南

## 1. 概述

**MarianNMT** 是一个高效的神经机器翻译（NMT）框架，用 C++ 编写，专为速度和内存效率优化。

**OPUS-MT** 是基于 MarianNMT 训练的预翻译模型集合，涵盖多种语言对，质量优秀且模型大小适中。

本项目使用 **Transformers + OPUS-MT** 的方案，通过 Python 的 Hugging Face Transformers 库加载和推理 OPUS-MT 模型，便于集成且兼容性好。

---

## 2. 模型选择

### 2.1 支持的模型列表

| 语言对 | 模型名称 | 参数量 | 模型大小 | 最低RAM | 推荐RAM | 存储需求 |
|--------|----------|--------|----------|---------|---------|----------|
| 英语 → 汉语 | Helsinki-NLP/opus-mt-en-zh | ~77M | ~150MB | 2GB | 4GB | 300MB |
| 汉语 → 英语 | Helsinki-NLP/opus-mt-zh-en | ~77M | ~150MB | 2GB | 4GB | 300MB |
| 英语 → 德语 | Helsinki-NLP/opus-mt-en-de | ~77M | ~250MB | 3GB | 6GB | 500MB |
| 英语 → 法语 | Helsinki-NLP/opus-mt-en-fr | ~77M | ~250MB | 3GB | 6GB | 500MB |
| 英语 → 西班牙语 | Helsinki-NLP/opus-mt-en-es | ~77M | ~250MB | 3GB | 6GB | 500MB |
| 100+ 语言互译 | facebook/m2m100_418M | ~418M | ~1.5GB | 6GB | 12GB | 3GB |

### 2.2 硬件配置建议

| 配置级别 | 适用的模型 | 推荐配置 |
|---------|-----------|---------|
| 入门级 | OPUS-MT en/zh | 4GB RAM, 10GB 存储 |
| 中级 | MarianMT 系列 | 8GB RAM, 20GB 存储 |
| 高级 | M2M-100 | 16GB RAM, 50GB 存储 |

### 2.3 下载来源

支持两种下载源：

| 下载源 | 说明 | 国内可用性 |
|--------|------|-----------|
| **Hugging Face** | 官方源 | 可能需要代理 |
| **ModelScope** | 阿里云模型库 | ✅ 推荐国内用户 |

系统会自动检测最佳下载源，也允许用户手动选择。

### 2.4 ModelScope 模型地址

| 语言对 | ModelScope ID |
|--------|---------------|
| 英语 → 汉语 | AI-ModelScope/opus-mt-en-zh |
| 汉语 → 英语 | AI-ModelScope/opus-mt-zh-en |
| 英语 → 德语 | AI-ModelScope/marianmt-en-de |
| 英语 → 法语 | AI-ModelScope/marianmt-en-fr |
| 英语 → 西班牙语 | AI-ModelScope/marianmt-en-es |
| 100+ 语言互译 | AI-ModelScope/m2m100-418m |

---

## 3. Python 后端实现

### 3.1 依赖安装

```bash
# python_backend/requirements.txt
llama-cpp-python>=0.2.0
pystardict>=0.9.0
zstandard>=0.22.0
transformers>=4.35.0
torch>=2.0.0
sentencepiece>=0.1.99
sacremoses>=0.0.53
```

安装命令：
```bash
pip install -r python_backend/requirements.txt
```

### 3.2 OPUS-MT 翻译器实现

```python
#!/usr/bin/env python3
from typing import Optional
from pathlib import Path
import sys

def _clean_text(text: str) -> str:
    """清理文本中的无效字符"""
    try:
        result = text.encode('utf-8', errors='replace').decode('utf-8')
        result = ''.join(c for c in result if not (0xd800 <= ord(c) <= 0xdfff))
        return result
    except:
        return str(text)

class OpusMtTranslator:
    """OPUS-MT 翻译器封装"""
    
    def __init__(self, model_dir: Optional[str] = None):
        """
        初始化翻译器
        
        Args:
            model_dir: 本地模型目录，如果为 None 则从 Hugging Face 自动下载
        """
        self.model_dir = model_dir
        self.models = {}  # 缓存已加载的模型
        self.tokenizers = {}  # 缓存已加载的分词器
    
    def _get_model_key(self, source_lang: str, target_lang: str) -> str:
        """生成模型缓存 key"""
        return f"{source_lang}-{target_lang}"
    
    def _get_model_name(self, source_lang: str, target_lang: str) -> str:
        """获取 Hugging Face 模型名称"""
        if source_lang == 'en' and target_lang == 'zh':
            return 'Helsinki-NLP/opus-mt-en-zh'
        elif source_lang == 'zh' and target_lang == 'en':
            return 'Helsinki-NLP/opus-mt-zh-en'
        else:
            raise ValueError(f"不支持的语言对: {source_lang}->{target_lang}")
    
    def _load_model(self, source_lang: str, target_lang: str):
        """加载模型和分词器"""
        from transformers import MarianMTModel, MarianTokenizer
        
        key = self._get_model_key(source_lang, target_lang)
        
        if key in self.models and key in self.tokenizers:
            return
        
        model_name = self._get_model_name(source_lang, target_lang)
        
        print(f"[INFO] 正在加载 OPUS-MT 模型: {model_name}", file=sys.stderr)
        
        # 加载模型和分词器
        if self.model_dir:
            # 从本地目录加载
            model_path = Path(self.model_dir) / model_name.split('/')[-1]
            self.tokenizers[key] = MarianTokenizer.from_pretrained(str(model_path))
            self.models[key] = MarianMTModel.from_pretrained(str(model_path))
        else:
            # 从 Hugging Face 加载（自动缓存）
            self.tokenizers[key] = MarianTokenizer.from_pretrained(model_name)
            self.models[key] = MarianMTModel.from_pretrained(model_name)
        
        print(f"[INFO] OPUS-MT 模型加载成功！", file=sys.stderr)
    
    def translate(
        self,
        text: str,
        source_lang: str = 'en',
        target_lang: str = 'zh',
        max_length: int = 512
    ) -> str:
        """
        翻译文本
        
        Args:
            text: 待翻译文本
            source_lang: 源语言代码 ('en' 或 'zh')
            target_lang: 目标语言代码 ('zh' 或 'en')
            max_length: 最大生成长度
        
        Returns:
            翻译后的文本
        """
        try:
            # 加载模型
            self._load_model(source_lang, target_lang)
            
            key = self._get_model_key(source_lang, target_lang)
            tokenizer = self.tokenizers[key]
            model = self.models[key]
            
            # 预处理
            cleaned_text = _clean_text(text.strip())
            if not cleaned_text:
                return ''
            
            # 分词和翻译
            inputs = tokenizer(
                cleaned_text,
                return_tensors="pt",
                padding=True,
                truncation=True,
                max_length=max_length
            )
            
            translated = model.generate(
                **inputs,
                max_length=max_length,
                num_beams=4,
                early_stopping=True
            )
            
            # 解码
            result = tokenizer.decode(translated[0], skip_special_tokens=True)
            return _clean_text(result.strip())
            
        except Exception as e:
            print(f"[ERROR] OPUS-MT 翻译失败: {e}", file=sys.stderr)
            import traceback
            traceback.print_exc(file=sys.stderr)
            raise
```

### 3.3 集成到现有服务器

在 `llm_server.py` 中添加 OPUS-MT 支持：

```python
class LlmServer:
    def __init__(self, model_path: str, opus_mt_dir: Optional[str] = None):
        self.model_path = model_path
        self.llama = None
        self.stardict = StarDictManager()
        self.opus_mt = OpusMtTranslator(opus_mt_dir)
        self._load_model()
    
    def translate_with_opus_mt(
        self,
        text: str,
        source_lang: str = 'en',
        target_lang: str = 'zh'
    ) -> str:
        """使用 OPUS-MT 翻译"""
        return self.opus_mt.translate(text, source_lang, target_lang)
    
    def run(self):
        """运行服务器，新增 translate_opus_mt 命令"""
        print("[READY]", file=sys.stderr)
        print(json.dumps({'type': 'ready'}, ensure_ascii=True), flush=True)
        
        while True:
            try:
                line = sys.stdin.readline()
                if not line:
                    break
                
                line = line.strip()
                if not line:
                    continue
                
                try:
                    request = json.loads(line)
                    action = request.get('action')
                    
                    # ... 原有代码 ...
                    
                    elif action == 'translate_opus_mt':
                        text = request.get('text', '')
                        source_lang = request.get('sourceLang', 'en')
                        target_lang = request.get('targetLang', 'zh')
                        
                        print(f"[OPUS-MT] {source_lang}->{target_lang}: {text[:50]}...", file=sys.stderr)
                        
                        try:
                            result = self.translate_with_opus_mt(text, source_lang, target_lang)
                            output_dict = {
                                'type': 'translate_result',
                                'data': {
                                    'success': True,
                                    'text': result
                                }
                            }
                        except Exception as e:
                            output_dict = {
                                'type': 'translate_result',
                                'data': {
                                    'success': False,
                                    'error': str(e)
                                }
                            }
                        
                        print(json.dumps(output_dict, ensure_ascii=True), flush=True)
                    
                    # ... 其他原有命令 ...
                    
                except json.JSONDecodeError as e:
                    # ... 错误处理 ...
                    
            except KeyboardInterrupt:
                break
            except Exception as e:
                # ... 错误处理 ...
```

---

## 4. Dart 端集成

### 4.1 更新 Python LLM 数据源

在 `python_llm_datasource.dart` 中添加 OPUS-MT 翻译方法：

```dart
// lib/features/llm/data/datasources/python_llm_datasource.dart
class PythonLlmDataSource implements LlmDataSource {
  // ... 现有代码 ...
  
  Future<String?> translateWithOpusMt(
    String text, {
    String sourceLang = 'en',
    String targetLang = 'zh',
  }) async {
    if (_process == null) {
      throw StateError('Python server not started');
    }
    
    final request = {
      'action': 'translate_opus_mt',
      'text': text,
      'sourceLang': sourceLang,
      'targetLang': targetLang,
    };
    
    _sendRequest(request);
    
    final completer = Completer<String?>();
    late StreamSubscription sub;
    
    sub = _responses.listen((response) {
      if (response['type'] == 'translate_result') {
        final data = response['data'] as Map<String, dynamic>;
        if (data['success'] == true) {
          completer.complete(data['text'] as String?);
        } else {
          completer.completeError(data['error'] ?? 'Translation failed');
        }
        sub.cancel();
      }
    });
    
    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        sub.cancel();
        throw TimeoutException('OPUS-MT translation timeout');
      },
    );
  }
}
```

### 4.2 更新翻译 Provider

在 `translation_provider.dart` 中调整翻译流程：

```dart
Future<void> _translateWithNewArchitecture() async {
  String? translationResult;
  String? dictionaryExplanation;
  TranslationSource source = TranslationSource.dictionary;
  bool isWordOrPhrase = false;
  String? phonetic;
  List<String>? definitions;
  List<String>? examples;
  
  // 1. 判断文本类型
  isWordOrPhrase = _isWordOrPhrase(state.sourceText);
  
  // 2. 获取数据源
  final llmService = _ref.read(llmServiceProvider.notifier);
  final llmDataSource = llmService.dataSource;
  
  if (isWordOrPhrase) {
    // 3. 单词/短语：优先使用词典
    if (state.sourceLang == Language.english && state.targetLang == Language.chinese) {
      final dictResult = await _tryDictionaryTranslation();
      if (dictResult != null) {
        translationResult = dictResult['translation'];
        phonetic = dictResult['phonetic'];
        definitions = dictResult['definitions'];
        examples = dictResult['examples'];
        source = TranslationSource.dictionary;
      }
    }
    
    // 4. 词典失败，使用兜底 LLM
    if (translationResult == null) {
      try {
        translationResult = await _tryFallbackTranslation();
        source = TranslationSource.llmFallback;
      } catch (_) {
        translationResult = '无法翻译';
      }
    }
  } else {
    // 5. 长句：优先使用 OPUS-MT
    try {
      if (llmDataSource is PythonLlmDataSource) {
        translationResult = await llmDataSource.translateWithOpusMt(
          state.sourceText,
          sourceLang: state.sourceLang == Language.english ? 'en' : 'zh',
          targetLang: state.targetLang == Language.chinese ? 'zh' : 'en',
        );
        source = TranslationSource.opusMt;
      }
    } catch (e) {
      print('[ERROR] OPUS-MT 翻译失败: $e');
      // 6. OPUS-MT 失败，使用兜底 LLM
      try {
        translationResult = await _tryFallbackTranslation();
        source = TranslationSource.llmFallback;
      } catch (_) {
        translationResult = '无法翻译';
      }
    }
  }
  
  // ... 更新状态 ...
}
```

### 4.3 更新 TranslationSource 枚举

```dart
// lib/features/translation/domain/entities/translation_source.dart
enum TranslationSource {
  dictionary,    // StarDict 词典
  opusMt,        // OPUS-MT 翻译
  llmFallback,   // 兜底 LLM
}
```

---

## 5. 模型下载与管理

### 5.1 手动下载模型（可选）

如果希望手动管理模型而不是依赖 Hugging Face 自动缓存：

```bash
# 创建模型目录
mkdir -p models/opus-mt

# 下载模型（使用 huggingface_hub 库）
pip install huggingface_hub

python << 'EOF'
from huggingface_hub import snapshot_download

# 下载英中模型
snapshot_download(
    "Helsinki-NLP/opus-mt-en-zh",
    local_dir="models/opus-mt/opus-mt-en-zh",
    local_dir_use_symlinks=False
)

# 下载中英模型
snapshot_download(
    "Helsinki-NLP/opus-mt-zh-en",
    local_dir="models/opus-mt/opus-mt-zh-en",
    local_dir_use_symlinks=False
)
EOF
```

### 5.2 在应用中检测模型状态

```dart
// 检查 OPUS-MT 模型是否已下载
Future<bool> isOpusMtModelAvailable() async {
  final modelsDir = await getApplicationDocumentsDirectory();
  final opusMtDir = Directory('${modelsDir.path}/models/opus-mt');
  
  if (!await opusMtDir.exists()) {
    return false;
  }
  
  final enZhDir = Directory('${opusMtDir.path}/opus-mt-en-zh');
  final zhEnDir = Directory('${opusMtDir.path}/opus-mt-zh-en');
  
  return await enZhDir.exists() || await zhEnDir.exists();
}
```

---

## 6. 性能优化建议

### 6.1 模型量化

对于资源受限的设备，可以考虑使用量化后的模型。OPUS-MT 模型本身已经比较小，但仍可进一步优化：

```python
# 使用 int8 量化（需要 accelerate 库）
from transformers import MarianMTModel

model = MarianMTModel.from_pretrained(
    "Helsinki-NLP/opus-mt-en-zh",
    load_in_8bit=True,
    device_map="auto"
)
```

### 6.2 批处理翻译

如果需要批量翻译多个句子，使用批处理可以提高效率：

```python
def translate_batch(
    self,
    texts: List[str],
    source_lang: str = 'en',
    target_lang: str = 'zh'
) -> List[str]:
    """批量翻译"""
    self._load_model(source_lang, target_lang)
    key = self._get_model_key(source_lang, target_lang)
    tokenizer = self.tokenizers[key]
    model = self.models[key]
    
    inputs = tokenizer(
        texts,
        return_tensors="pt",
        padding=True,
        truncation=True,
        max_length=512
    )
    
    translated = model.generate(**inputs, max_length=512)
    return [tokenizer.decode(t, skip_special_tokens=True) for t in translated]
```

### 6.3 缓存翻译结果

对于重复出现的文本，可以缓存翻译结果以避免重复计算：

```python
from functools import lru_cache

@lru_cache(maxsize=1000)
def cached_translate(self, text: str, source_lang: str, target_lang: str) -> str:
    """带缓存的翻译"""
    return self.translate(text, source_lang, target_lang)
```

---

## 7. 故障排除

### 7.1 常见问题

**问题：模型下载很慢或失败**
- 解决方案：配置 Hugging Face 镜像源
  ```python
  import os
  os.environ['HF_ENDPOINT'] = 'https://hf-mirror.com'
  ```

**问题：内存占用过高**
- 解决方案：
  1. 使用更小的模型
  2. 启用模型量化
  3. 翻译完成后卸载模型

**问题：翻译质量不如预期**
- 解决方案：
  1. 检查输入文本是否清晰
  2. 尝试调整 beam search 参数（num_beams）
  3. 考虑使用更大的 OPUS-MT 模型变体

### 7.2 日志调试

启用详细日志：
```python
import logging
logging.basicConfig(level=logging.DEBUG)
```

---

## 8. 备选方案：使用 Marian 命令行工具

如果 Python + Transformers 方案不适用，可以考虑直接使用 Marian 命令行工具：

```bash
# 下载 Marian 预编译二进制文件
# Windows: https://github.com/marian-nmt/marian-dev/releases

# 下载 OPUS-MT 模型（包含 .npz 权重文件）
# 从 https://github.com/Helsinki-NLP/OPUS-MT 下载

# 翻译命令
./marian-decoder \
    -m model.npz \
    -v vocab.spm vocab.spm \
    -i input.txt \
    -o output.txt
```

此方案性能更好，但集成复杂度较高。
