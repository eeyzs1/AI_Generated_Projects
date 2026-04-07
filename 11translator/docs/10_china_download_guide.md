# 国内用户模型下载指南

国内用户访问 Hugging Face 可能存在网络问题，本指南提供多种解决方案。

---

## 方案一：自动检测下载源（推荐）

### 1.1 自动检测最佳源

应用内置了自动检测功能，会按以下优先级自动选择最佳下载源：

```
1. Hugging Face（官方）→ 2. ModelScope（阿里云）
```

系统会先测试每个下载源的连通性，自动选择最快的可用源。

### 1.2 手动选择下载源

在 "AI 模型" 页面，用户也可以手动选择下载源：

| 下载源 | 说明 | 国内可用性 |
|--------|------|-----------|
| **自动检测** | 系统自动选择最佳源 | ✅ 默认推荐 |
| **Hugging Face** | 官方源 | 可能需要代理 |
| **ModelScope** | 阿里云模型库 | ✅ 国内访问快 |

---

## 方案二：使用 ModelScope（阿里模型库）

ModelScope 是阿里云的模型库，国内访问速度快，推荐国内用户使用。

### 2.1 支持的模型

| 模型 | ModelScope ID | 说明 |
|------|---------------|------|
| OPUS-MT en→zh | AI-ModelScope/opus-mt-en-zh | 英译中 |
| OPUS-MT zh→en | AI-ModelScope/opus-mt-zh-en | 中译英 |
| MarianMT en→de | AI-ModelScope/marianmt-en-de | 英语→德语 |
| MarianMT en→fr | AI-ModelScope/marianmt-en-fr | 英语→法语 |
| MarianMT en→es | AI-ModelScope/marianmt-en-es | 英语→西班牙语 |
| M2M-100 418M | AI-ModelScope/m2m100-418m | 100+ 语言互译 |

### 2.2 目录结构

下载后确保目录结构如下：
```
models/translation/
├── opus-mt-en-zh/
│   ├── config.json
│   ├── pytorch_model.bin
│   ├── source.spm
│   ├── target.spm
│   └── vocab.json
├── opus-mt-zh-en/
│   ├── config.json
│   ├── pytorch_model.bin
│   ├── source.spm
│   ├── target.spm
│   └── vocab.json
├── marianmt-en-de/
│   └── ...
└── m2m100-418m/
    └── ...
```

---

## 方案三：使用国内网盘下载

### 3.1 百度网盘 / 夸克网盘

我们会在项目 Release 页面提供网盘下载链接：

- OPUS-MT en→zh: [链接待补充]
- OPUS-MT zh→en: [链接待补充]
- MarianMT en→de: [链接待补充]
- MarianMT en→fr: [链接待补充]
- MarianMT en→es: [链接待补充]
- M2M-100 418M: [链接待补充]

### 3.2 下载步骤

1. 下载对应语言对的压缩包
2. 解压到 `%USERPROFILE%\Documents\11Translator\models\translation\`
3. 确保目录结构正确

---

## 方案四：使用代理下载

如果你有代理，可以配置使用代理下载。

### 4.1 环境变量配置

```bash
# Windows PowerShell
$env:HTTP_PROXY = "http://127.0.0.1:7890"
$env:HTTPS_PROXY = "http://127.0.0.1:7890"

# Linux/Mac
export HTTP_PROXY=http://127.0.0.1:7890
export HTTPS_PROXY=http://127.0.0.1:7890
```

### 4.2 手动选择 Hugging Face

在应用中手动选择 "Hugging Face" 作为下载源。

---

## 模型目录说明

### 默认路径

```
Windows: %USERPROFILE%\Documents\11Translator\models\translation\
```

### 自定义路径

在应用设置中可以自定义模型存储路径。

---

## 验证模型是否正确安装

启动应用后，在"AI 模型"页面：
1. 查看模型是否显示"已安装"标签
2. 尝试翻译一段文本，验证是否正常工作

---

## 常见问题

### Q: 下载源都无法访问？
A: 尝试使用网盘下载方案，或检查网络连接。

### Q: 下载的模型如何使用？
A: 解压到正确的目录结构后，重启应用即可自动识别。

### Q: 可以同时安装多个模型吗？
A: 可以！所有支持的模型都可以同时安装。

### Q: M2M-100 模型很大，我的机器能跑吗？
A: M2M-100 418M 需要至少 6GB RAM（推荐 12GB），请确保机器配置足够。

---

## 技术支持

如果遇到问题，请查看：
1. Python 后端日志（应用控制台）
2. 项目 Issues 页面
