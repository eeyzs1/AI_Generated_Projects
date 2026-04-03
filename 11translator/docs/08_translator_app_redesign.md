# 翻译应用重新设计 —— 11Translator

## 1. 应用定位与核心功能

### 1.1 应用名称
**11Translator** —— 简洁高效的双平台翻译应用

### 1.2 核心功能
- **智能翻译**：支持中英文双向互译，以及多语言翻译
- **本地词典查询**：保留 ECDICT 词典作为辅助功能
- **AI 增强翻译**：使用本地 LLM 提供更自然、更准确的翻译
- **翻译历史**：记录翻译历史，支持快速重译
- **收藏夹**：收藏常用翻译
- **离线优先**：核心功能无需网络，保护隐私

### 1.3 目标平台
- **Windows**：Fluent UI 设计风格
- **Android**：Material Design 3 设计风格

---

## 2. 核心功能详细设计

### 2.1 主翻译页面

#### 界面布局
```
┌─────────────────────────────────────────────────┐
│ [Logo]  11Translator                  [设置]   │ ← AppBar
├─────────────────────────────────────────────────┤
│  源语言 [▼]          [交换]          目标语言 [▼] │
├─────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────┐       │
│  │ 输入要翻译的文本...                │       │ ← 源文本输入框
│  │ （支持多行输入）                    │       │
│  │                              [清空]  │       │
│  └─────────────────────────────────────┘       │
├─────────────────────────────────────────────────┤
│                    [翻译]                         │ ← 翻译按钮
├─────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────┐       │
│  │ 翻译结果...                         │       │ ← 翻译结果显示
│  │                              [复制]  │       │
│  │                              [收藏]  │       │
│  └─────────────────────────────────────┘       │
├─────────────────────────────────────────────────┤
│  词典查询（可选）：apple                          │
│  [查询词典]                                         │ ← 词典查询入口
└─────────────────────────────────────────────────┘
```

#### 交互流程
1. **选择语言**：用户选择源语言和目标语言
2. **输入文本**：在源文本框输入要翻译的内容
3. **触发翻译**：
   - 点击"翻译"按钮
   - 或者按回车键（Windows）/ 输入法完成键（Android）
4. **查看结果**：翻译结果显示在下方
5. **后续操作**：
   - 复制翻译结果
   - 收藏该翻译
   - 如有需要，查询单词的词典详情

### 2.2 语言选择

#### 支持的语言
- 中文（简体）
- 英文
- 日文（未来扩展）
- 韩文（未来扩展）
- 法文（未来扩展）
- 德文（未来扩展）

#### 语言切换
- 快速交换按钮：一键交换源语言和目标语言
- 记住偏好：应用记住用户上次使用的语言对

### 2.3 翻译引擎

#### 多层翻译策略
应用采用多层翻译策略，确保翻译质量和可用性：

```
用户输入
    │
    ▼
┌─────────────────────────────────────────┐
│  1. 快速翻译层（本地词典）              │
│  - 单词/短语匹配                         │
│  - 即时响应（< 50ms）                   │
└─────────────────────────────────────────┘
    │ （如果是单词/短语，且词典中有）
    ▼
┌─────────────────────────────────────────┐
│  2. AI 增强层（本地 LLM）               │
│  - 句子/段落翻译                        │
│  - 上下文理解                           │
│  - 自然语言表达                         │
│  - 响应时间：1-5 秒（取决于模型大小）   │
└─────────────────────────────────────────┘
    │
    ▼
显示翻译结果
```

#### 翻译状态指示
- **翻译中**：显示加载动画
- **快速结果**：先显示词典匹配的快速结果（如有）
- **AI 增强**：AI 结果准备好后更新或追加显示
- **失败处理**：显示友好的错误提示，提供重试选项

### 2.4 词典查询功能

作为辅助功能，保留原有的词典查询能力：
- 用户可以点击"查询词典"按钮查看单词的详细释义
- 支持音标、词性、例句等完整词典信息
- 与翻译功能无缝集成

### 2.5 翻译历史

#### 功能特性
- 自动保存所有翻译记录
- 按时间倒序显示
- 显示源文本、翻译结果、语言对
- 支持点击快速重译
- 支持删除单条或全部历史
- 最多保存 500 条记录

#### 界面设计
```
┌─────────────────────────────────────┐
│  翻译历史              [清空]        │
├─────────────────────────────────────┤
│  ┌─────────────────────────────┐   │
│  │ Hello → 你好               │   │
│  │ 今天 14:30        [重译]   │   │
│  └─────────────────────────────┘   │
│  ┌─────────────────────────────┐   │
│  │ 我爱你 → I love you         │   │
│  │ 今天 14:25        [重译]   │   │
│  └─────────────────────────────┘   │
└─────────────────────────────────────┘
```

### 2.6 收藏夹

#### 功能特性
- 收藏常用翻译
- 支持分组（可选）
- 快速访问常用翻译
- 支持取消收藏

#### 界面设计
与历史记录页类似，但显示收藏标识。

### 2.7 设置页面

#### 设置选项
1. **UI 风格**：Material 3 / Fluent / Adaptive
2. **主题模式**：浅色 / 深色 / 跟随系统
3. **强调色**：用户自定义应用主色调
4. **语言**：应用界面语言（中文 / 英文）
5. **默认翻译语言对**：设置默认的源语言和目标语言
6. **AI 模型管理**：
   - 下载/切换/删除本地 LLM 模型
   - 选择模型大小（根据设备性能）
7. **数据管理**：
   - 清除翻译历史
   - 清除收藏夹
   - 清除所有数据
8. **关于**：版本信息、开源声明等

---

## 3. 技术架构调整

### 3.1 目录结构调整
```
lib/
├── core/
│   ├── localization/
│   │   └── app_localizations.dart  (已存在)
│   ├── router/
│   │   └── app_router.dart          (已存在)
│   ├── theme/
│   │   └── app_theme.dart            (已存在)
│   └── utils/
│       └── platform_utils.dart       (已存在)
├── features/
│   ├── translation/                   # 新增：翻译核心功能
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   ├── dictionary_translator.dart  # 词典翻译
│   │   │   │   └── llm_translator.dart         # LLM 翻译
│   │   │   └── repositories/
│   │   │       └── translation_repository.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── translation_result.dart
│   │   │   └── usecases/
│   │   │       └── translate_text.dart
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── translation_provider.dart
│   │       └── screens/
│   │           └── translation_screen.dart  # 主翻译页
│   ├── dictionary/                  # 保留：词典查询
│   ├── history/                     # 调整：翻译历史
│   ├── favorites/                   # 调整：收藏翻译
│   ├── llm/                         # 已存在：LLM 服务
│   └── settings/                    # 已存在：设置页
├── presentation/
│   └── shell/                       # 已存在：导航壳
└── app.dart                          # 已存在
```

### 3.2 状态管理

#### 翻译状态
```dart
// 翻译状态
final translationProvider = StateNotifierProvider<TranslationNotifier, TranslationState>((ref) {
  return TranslationNotifier(ref);
});

class TranslationState {
  final String sourceText;
  final String targetText;
  final Language sourceLang;
  final Language targetLang;
  final bool isTranslating;
  final String? error;
  final bool hasDictionaryResult;
  final bool hasLLMResult;
}

// 语言选择
final sourceLangProvider = StateProvider<Language>((ref) => Language.english);
final targetLangProvider = StateProvider<Language>((ref) => Language.chinese);
```

### 3.3 数据模型

#### 翻译结果
```dart
class TranslationResult {
  final String sourceText;
  final String targetText;
  final Language sourceLang;
  final Language targetLang;
  final DateTime translatedAt;
  final TranslationSource source;  // dictionary / llm / hybrid
  final String? dictionaryExplanation;  // 可选：词典释义
}

enum TranslationSource { dictionary, llm, hybrid }

enum Language {
  english,
  chinese,
  // 未来扩展...
}
```

#### 翻译历史记录
```dart
@HiveType(typeId: 2)
class TranslationHistory {
  @HiveField(0) String sourceText;
  @HiveField(1) String targetText;
  @HiveField(2) String sourceLang;
  @HiveField(3) String targetLang;
  @HiveField(4) DateTime translatedAt;
}
```

#### 收藏翻译
```dart
@HiveType(typeId: 3)
class FavoriteTranslation {
  @HiveField(0) String sourceText;
  @HiveField(1) String targetText;
  @HiveField(2) String sourceLang;
  @HiveField(3) String targetLang;
  @HiveField(4) DateTime addedAt;
  @HiveField(5) String? note;  // 可选：用户备注
}
```

---

## 4. 实现优先级

### Phase 1: 核心翻译功能（MVP）
- [x] 项目基础架构（已完成）
- [ ] 主翻译页面 UI
- [ ] 语言选择器
- [ ] 基于 ECDICT 的单词/短语翻译
- [ ] 翻译历史记录
- [ ] 收藏夹功能

### Phase 2: AI 增强
- [ ] 集成本地 LLM
- [ ] LLM 句子翻译
- [ ] 混合翻译策略（词典 + LLM）
- [ ] 模型下载管理

### Phase 3: 体验优化
- [ ] 翻译动画和反馈
- [ ] 离线使用优化
- [ ] 性能优化
- [ ] 多语言扩展（日、韩、法、德等）

---

## 5. 设计原则延续

- **双平台适配**：继续保持 Material 和 Fluent 两种风格
- **离线优先**：核心功能无需网络
- **隐私保护**：所有数据本地存储
- **简洁高效**：界面简洁，操作直观
- **可定制性**：支持主题、颜色、语言等个性化设置
