# 产品图文草稿生成系统 (Product Draft SPA)

一个单页面应用，帮助运营批量生成第一版图文草稿（包括主图、标题、卖点），并沉淀可复用的模板库。

## 🚀 快速开始

### 前置要求
- Node.js >= 16
- npm 或 yarn

### 安装依赖
```bash
npm install
```

### 运行开发服务器
```bash
npm run dev
```

这将启动：
- **前端**: [http://localhost:5173](http://localhost:5173) （Vite React）
- **后端**: [http://localhost:3000](http://localhost:3000) （Express Mock API）

### 生成示例数据
```bash
npm run gen-samples
```

这会在 `examples/products.xlsx` 生成 5 条示例商品数据。

## 📖 使用流程

### 步骤 1：导入商品
1. 打开应用首页的"导入和生成"页签
2. 上传一个 Excel 文件（见 `examples/products.xlsx` 作参考）
3. 系统自动解析 Excel，检查字段映射

### 步骤 2：批量生成草稿
1. 点击"生成草稿"按钮
2. 系统调用 `/api/generate-batch` 生成：
   - 主图草稿（基于 SVG 合成，可下载）
   - 标题草稿（基于规则引擎或模板生成）
   - 卖点文案（1-2 条）

### 步骤 3：编辑和导出
1. 查看每条生成结果卡片
2. 点击"编辑"修改标题和卖点
3. 点击"收藏为模板"保存当前结果为可复用模板
4. 点击"导出 CSV"导出所有结果

### 步骤 4：管理模板库
1. 切换到"模板库"页签
2. 新建模板（支持标题和卖点模板）
3. 给模板打标签以便分类和检索
4. 下次导入新商品时，可选择使用某个模板套用

## 🏗️ 项目结构

```
.
├── src/
│   ├── pages/
│   │   ├── App.tsx              # 主应用入口
│   │   └── ImportPage.tsx       # 导入、生成、编辑页面
│   ├── components/
│   │   ├── ResultCard.tsx       # 单条生成结果卡片
│   │   └── TemplateManager.tsx  # 模板库管理组件
│   ├── main.tsx                 # React 入口
│   ├── styles.css               # 全局样式
│   └── types.d.ts               # TypeScript 类型定义
├── server/
│   └── index.js                 # Express Mock API
├── examples/
│   ├── products.xlsx            # 示例商品数据（需要生成）
│   └── generate-sample-excel.js # 生成示例脚本
├── package.json
├── vite.config.ts               # Vite 配置
├── index.html
└── README.md
```

## 🔌 API 接口

### POST /api/generate-batch
批量生成商品草稿。

**请求:**
```json
{
  "items": [
    {
      "id": "p-0",
      "name": "羊绒围巾",
      "category": "围巾",
      "brand": "Luxe",
      "material": "100% 羊绒",
      "size": "180cm x 30cm",
      "color": "深灰色",
      "targetAudience": "白领女性"
    }
  ],
  "options": {
    "saveToLibrary": false,
    "templateId": "tpl-xxx"  // 可选，使用指定模板
  }
}
```

**响应:**
```json
{
  "results": [
    {
      "productId": "p-0",
      "mainImageDraft": "data:image/svg+xml;base64,...",
      "titleDraft": "【Luxe】羊绒围巾，深灰色",
      "sellingPoints": [
        "100% 羊绒 材质",
        "适合白领女性"
      ]
    }
  ]
}
```

### GET /api/templates
获取所有模板。

**响应:**
```json
{
  "templates": [
    {
      "id": "tpl-xxx",
      "name": "高端包包模板",
      "tags": ["女包", "高端"],
      "parts": {
        "titleTemplate": "【{brand}】{name} {color} {material}",
        "sellingPointsTemplates": ["{material} 材质", "适合{targetAudience}"]
      },
      "createdAt": "2026-01-27T..."
    }
  ]
}
```

### POST /api/templates
创建新模板。

**请求:**
```json
{
  "name": "高端包包模板",
  "tags": ["女包", "高端"],
  "parts": {
    "titleTemplate": "【{brand}】{name} {color} {material}",
    "sellingPointsTemplates": ["{material} 材质", "适合{targetAudience}"]
  }
}
```

### DELETE /api/templates/:id
删除模板。

### PUT /api/templates/:id
更新模板。

## 🤖 如何替换为真实 AI 服务

目前系统使用**规则引擎**生成标题和卖点。要替换为真实 LLM 或图片生成服务：

### 1. 替换标题/卖点生成

在 `server/index.js` 的 `generateDraftForItem()` 函数中，调用真实 AI API：

```javascript
// 示例：使用 OpenAI GPT-4
const generateDraftWithAI = async (item) => {
  const prompt = `
    根据以下商品信息生成一条有吸引力的电商标题（不超过50字）：
    品牌：${item.brand}
    名称：${item.name}
    材质：${item.material}
    颜色：${item.color}
    目标人群：${item.targetAudience}
  `
  
  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${process.env.OPENAI_API_KEY}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      model: 'gpt-4',
      messages: [{ role: 'user', content: prompt }]
    })
  })
  
  const data = await response.json()
  return data.choices[0].message.content
}
```

### 2. 替换图片生成

调用图片生成服务（如 DALL-E、Midjourney API）：

```javascript
// 示例：使用 DALL-E
const generateImageWithAI = async (item) => {
  const prompt = `
    Create a product showcase image for an e-commerce listing:
    Product: ${item.name}
    Brand: ${item.brand}
    Color: ${item.color}
    Material: ${item.material}
    Style: professional, clean, white background
  `
  
  const response = await fetch('https://api.openai.com/v1/images/generations', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${process.env.OPENAI_API_KEY}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      prompt: prompt,
      n: 1,
      size: '512x512'
    })
  })
  
  const data = await response.json()
  return data.data[0].url // 返回图片 URL
}
```

### 3. 环境变量配置

在项目根目录创建 `.env` 文件：

```env
OPENAI_API_KEY=sk-xxx
AI_MODEL=gpt-4
IMAGE_GEN_SERVICE=dall-e
```

## 📋 数据模型

### Product
```typescript
{
  id: string
  name: string              // 商品名称
  category?: string         // 分类
  brand?: string            // 品牌
  material?: string         // 材质
  size?: string             // 尺寸
  color?: string            // 颜色
  targetAudience?: string   // 目标人群
  images?: string[]         // 图片列表（data URL）
}
```

### GenerateResult
```typescript
{
  productId: string
  mainImageDraft: string    // 主图草稿（data URL）
  titleDraft: string        // 标题草稿
  sellingPoints: string[]   // 卖点文案（1-2 条）
}
```

### Template
```typescript
{
  id: string
  name: string
  tags: string[]
  parts: {
    titleTemplate?: string
    sellingPointsTemplates?: string[]
    imageTemplate?: object
  }
  createdAt?: string
}
```

## 🧪 测试流程

### 手动验收清单

- [ ] **导入测试**
  1. 运行 `npm run gen-samples` 生成示例 Excel
  2. 在首页上传 `examples/products.xlsx`
  3. 确认 5 条商品被正确解析

- [ ] **生成测试**
  1. 点击"生成草稿"
  2. 查看每条结果的主图、标题、卖点
  3. 确认字段值被正确映射

- [ ] **编辑测试**
  1. 点击某条卡片的"编辑"
  2. 修改标题和卖点
  3. 保存修改并验证更新

- [ ] **导出测试**
  1. 点击"导出 CSV"
  2. 下载 CSV 文件
  3. 检查数据完整性（productId、title、sellingPoints、imageUrl）

- [ ] **模板测试**
  1. 点击某条卡片的"收藏为模板"
  2. 切换到"模板库"页签
  3. 验证新模板出现在列表中
  4. 编辑、删除模板

## 📦 生产部署

### 构建前端
```bash
npm run build
```

### 部署到服务器
1. 将 `dist/` 目录部署到 CDN 或 Web 服务器
2. 将 `server/index.js` 部署到 Node.js 服务器
3. 配置反向代理或 CORS，使前端能调用后端 API
4. 配置 `.env` 环境变量（AI 服务密钥等）

## 🛠️ 故障排除

### 前端无法连接后端
- 确保后端在 `http://localhost:3000` 运行
- 检查浏览器控制台的 CORS 错误
- 如需跨域，确保后端启用了 CORS

### Excel 导入失败
- 确认 Excel 第一行是列头（字段名）
- 支持的字段: `name`, `category`, `brand`, `material`, `size`, `color`, `targetAudience`
- 其他字段会被忽略

### 模板套用不生效
- 检查模板的 `titleTemplate` 是否包含有效的占位符（如 `{name}`, `{brand}`）
- 确保商品对象包含模板所需的字段

## 📝 License

MIT

## 📧 联系方式

如有问题或建议，请提交 Issue 或联系开发团队。

