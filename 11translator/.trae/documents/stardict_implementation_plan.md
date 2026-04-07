# StarDict 功能实现计划

## 概述

本计划详细描述了 StarDict 词典功能的完整实现，包括下载、解压、加载和查询功能。

## 当前状态

### 已完成

* ✅ Python 后端 `StarDictManager` 类

* ✅ Python 后端 `extract_tar_zst()` 解压函数

* ✅ Python 后端三个命令接口：`extract_dictionary`、`load_dictionary`、`lookup_word`

* ✅ Dart 端 `DictionaryType` 扩展（多种语言对）

* ✅ Dart 端 StarDict 下载地址配置

* ✅ Dart 端下载逻辑（StarDict 保存为 .tar.zst）

* ✅ Dart 端 `PythonLlmDataSource` 字典方法骨架

* ✅ Dart 端 `StarDictDataSource` 骨架

* ✅ Dart 端 `TranslationProvider` StarDict 检测

### 待完成

* [ ] DictionaryManager 整合 Ref 和 Python 后端调用

* [ ] 下载后自动解压 StarDict

* [ ] 翻译提供者真正调用 StarDict 查询

* [ ] Python 结果转换为 WordEntry 格式

* [ ] 完整的端到端测试

***

## 任务分解

### \[x] 任务 1：DictionaryManager 添加 Ref 和 Python 后端引用

* **Priority**: P0

* **Depends On**: None

* **Description**:

  * 修改 `DictionaryManager` 构造函数，添加 `Ref` 参数

  * 通过 Ref 访问 `pythonLlmDataSourceProvider`

  * 添加解压和查询的方法

* **Success Criteria**:

  * DictionaryManager 可以访问 PythonLlmDataSource

  * 代码编译通过

* **Test Requirements**:

  * `programmatic` TR-1.1: 代码可以成功编译

  * `human-judgement` TR-1.2: 依赖注入结构清晰

***

### \[ ] 任务 2：实现下载后自动解压

* **Priority**: P0

* **Depends On**: Task 1

* **Description**:

  * 在下载完成后检查是否是 StarDict 格式

  * 如果是，调用 Python 后端 `extract_dictionary`

  * 解压成功后，更新词典路径为解压后的 .ifo 文件

  * 调用 `load_dictionary` 预加载词典

* **Success Criteria**:

  * 下载 StarDict 后自动解压

  * 词典路径正确设置为解压后的文件

* **Test Requirements**:

  * `programmatic` TR-2.1: 下载后可以找到解压的 .ifo 文件

  * `human-judgement` TR-2.2: 用户界面显示词典已就绪

***

### \[ ] 任务 3：实现 StarDict 查询功能

* **Priority**: P0

* **Depends On**: Task 1, Task 2

* **Description**:

  * 在 `StarDictDataSource` 中实现 `getWord()` 方法

  * 调用 Python 后端 `lookup_word`

  * 解析返回的 JSON 结果

* **Success Criteria**:

  * 可以通过 Python 后端查询单词

  * 返回正确的结果

* **Test Requirements**:

  * `programmatic` TR-3.1: 查询返回结果不为 null

  * `human-judgement` TR-3.2: 查询响应时间合理（< 500ms）

***

### \[ ] 任务 4：实现 Python 结果到 WordEntry 的转换

* **Priority**: P0

* **Depends On**: Task 3

* **Description**:

  * Python 返回格式：`{word: str, definition: str, found: bool}`

  * 需要转换为 `WordEntry` 格式

  * 解析 definition 文本提取释义、音标等

  * StarDict 的 definition 通常是 HTML 或纯文本，需要清洗

* **Success Criteria**:

  * Python 结果正确转换为 WordEntry

  * 释义、音标等信息正确提取

* **Test Requirements**:

  * `programmatic` TR-4.1: 转换后的 WordEntry 非空

  * `human-judgement` TR-4.2: 显示的信息清晰易读

***

### \[ ] 任务 5：更新翻译提供者使用 StarDict

* **Priority**: P0

* **Depends On**: Task 2, Task 3, Task 4

* **Description**:

  * 修改 `_translateWithTraditional()` 方法

  * 如果是 StarDict 格式，使用 `StarDictDataSource` 查询

  * 如果 StarDict 查询失败，回退到 SQLite

  * 如果都失败，走 LLM 或"无法翻译"

* **Success Criteria**:

  * 翻译提供者正确使用 StarDict

  * 查询流程正确执行

* **Test Requirements**:

  * `programmatic` TR-5.1: StarDict 查询优先执行

  * `human-judgement` TR-5.2: 用户体验流畅，无明显卡顿

***

### \[ ] 任务 6：添加错误处理和用户反馈

* **Priority**: P1

* **Depends On**: All previous

* **Description**:

  * 添加解压失败的错误处理

  * 添加查询失败的错误处理

  * 显示友好的错误信息给用户

  * 添加加载状态指示器

* **Success Criteria**:

  * 错误情况有适当处理

  * 用户得到清晰的反馈

* **Test Requirements**:

  * `programmatic` TR-6.1: 错误不会导致应用崩溃

  * `human-judgement` TR-6.2: 错误信息清晰易懂

***

### \[ ] 任务 7：端到端测试

* **Priority**: P0

* **Depends On**: All previous

* **Description**:

  * 测试完整流程：下载 → 解压 → 加载 → 查询

  * 测试多种语言对

  * 测试常见单词和短语

  * 测试错误情况

* **Success Criteria**:

  * 完整流程正常工作

  * 多种场景都能正确处理

* **Test Requirements**:

  * `programmatic` TR-7.1: 完整流程执行无错误

  * `human-judgement` TR-7.2: 功能符合预期

***

## 技术细节

### Python 后端返回格式

#### lookup\_word 返回

```json
{
  "word": "hello",
  "definition": "你好\nint. 喂；哈罗\nn. 表示问候， 惊奇或唤起注意时的用语",
  "found": true
}
```

#### extract\_dictionary 返回

```json
{
  "success": true,
  "ifoPath": "/path/to/dictionary.ifo"
}
```

#### load\_dictionary 返回

```json
{
  "success": true
}
```

### WordEntry 结构

```dart
class WordEntry {
  final String word;
  final String? phonetic;
  final List<Definition> definitions;
  final List<Example> examples;
}
```

***

## 风险和注意事项

### 风险 1：StarDict definition 格式不统一

* **描述**：不同的 StarDict 词典可能有不同的 definition 格式

* **缓解**：先支持常见格式，后续逐步添加更多格式支持

### 风险 2：解压时间较长

* **描述**：大的词典文件解压可能需要较长时间

* **缓解**：添加进度指示器，让用户知道正在处理

### 风险 3：Python 后端可能未初始化

* **描述**：查询时 Python 后端可能还没启动

* **缓解**：检查状态，必要时自动初始化

***

## 成功标准

### 功能完整度

* [ ] 可以下载 StarDict 词典

* [ ] 下载后自动解压

* [ ] 可以查询单词

* [ ] 查询结果正确显示

* [ ] 错误情况有适当处理

### 代码质量

* [ ] 代码结构清晰

* [ ] 有适当的错误处理

* [ ] 可维护性好

### 用户体验

* [ ] 界面响应流畅

* [ ] 反馈清晰及时

* [ ] 功能符合预期

***

## 附录

### 相关文件

* `python_backend/llm_server.py` - Python 后端

* `lib/features/dictionary/domain/dictionary_manager.dart` - 词典管理器

* `lib/features/llm/data/datasources/python_llm_datasource.dart` - Python 数据源

* `lib/features/dictionary/data/datasources/stardict_datasource.dart` - StarDict 数据源

* `lib/features/translation/presentation/providers/translation_provider.dart` - 翻译提供者

### 参考资源

* StarDict 格式说明：<http://download.huzheng.org/StarDictFileFormat>

* xxyzz/wiktionary\_stardict：<https://github.com/xxyzz/wikt>

