# 前后端通信快速参考

## 🔄 通信方式总结

| 项目 | 详情 |
|------|------|
| **协议** | HTTP REST API |
| **数据格式** | JSON |
| **跨域** | ✅ CORS 已启用 |
| **调用方式** | 前端 `fetch()` 原生 API |

---

## 📡 5 个核心 API 端点

### 1️⃣ POST `/api/generate-batch` — 批量生成草稿

**何时调用**: 用户点击"生成草稿"按钮

**请求**:
```javascript
fetch('http://localhost:3000/api/generate-batch', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    items: [                              // 商品列表
      { id: "p-0", name: "羊绒围巾", brand: "Luxe", ... },
      { id: "p-1", name: "运动鞋", brand: "SpeedRun", ... }
    ],
    options: {
      saveToLibrary: false,               // 是否保存到素材库
      templateId: "tpl-xxx"               // 可选：使用指定模板
    }
  })
})
```

**响应** (200 OK):
```javascript
{
  "results": [
    {
      "productId": "p-0",
      "mainImageDraft": "data:image/svg+xml;base64,...",
      "titleDraft": "Luxe 羊绒围巾 深灰色",
      "sellingPoints": ["100% 羊绒 材质", "适合白领女性"]
    }
  ]
}
```

**后端处理**: 
- 对每个商品调用 `generateDraftForItem()`
- 如果有 `templateId`，使用模板生成；否则使用规则引擎

---

### 2️⃣ GET `/api/templates` — 获取所有模板

**何时调用**: 打开"模板库"页签时

**请求**:
```javascript
fetch('http://localhost:3000/api/templates')
```

**响应**:
```javascript
{
  "templates": [
    {
      "id": "tpl-001",
      "name": "高端包包模板",
      "tags": ["女包", "高端"],
      "parts": {
        "titleTemplate": "【{brand}】{name} {color}",
        "sellingPointsTemplates": ["{material} 材质", "适合{targetAudience}"]
      },
      "createdAt": "2026-01-27T..."
    }
  ]
}
```

---

### 3️⃣ POST `/api/templates` — 创建新模板

**何时调用**: 用户点击"收藏为模板"

**请求**:
```javascript
fetch('http://localhost:3000/api/templates', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    name: "羊绒围巾 - 模板",
    tags: ["围巾", "秋冬"],
    parts: {
      titleTemplate: "【{brand}】{name} {color} {material}",
      sellingPointsTemplates: ["{material} 材质", "适合{targetAudience}"]
    }
  })
})
```

**响应**:
```javascript
{
  "template": {
    "id": "tpl-1704768000000",
    "name": "羊绒围巾 - 模板",
    "tags": ["围巾", "秋冬"],
    "parts": {...},
    "createdAt": "2026-01-27T..."
  }
}
```

---

### 4️⃣ PUT `/api/templates/:id` — 更新模板

**何时调用**: 用户编辑现有模板

**请求**:
```javascript
fetch('http://localhost:3000/api/templates/tpl-001', {
  method: 'PUT',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    name: "新模板名称",
    tags: ["新标签"],
    parts: { ... }
  })
})
```

---

### 5️⃣ DELETE `/api/templates/:id` — 删除模板

**何时调用**: 用户删除模板

**请求**:
```javascript
fetch('http://localhost:3000/api/templates/tpl-001', {
  method: 'DELETE'
})
```

**响应**:
```javascript
{
  "success": true
}
```

---

## 📊 数据流示意

```
前端 ImportPage.tsx                后端 server/index.js
        │                                  │
        │ 1. 导入 Excel                   │
        │    XLSX.read()                  │
        │ setProducts([...])              │
        │                                  │
        │ 2. 点击"生成草稿"                │
        ├─→ fetch POST                    │
        │   /api/generate-batch           ├─→ generateDraftForItem()
        │                                  │   (规则 + SVG)
        │←─ JSON response                 │
        │ setResults([...])               │
        │                                  │
        │ 3. 编辑标题/卖点                 │
        │ handleEditResult()               │
        │ (本地修改)                       │
        │                                  │
        │ 4. 收藏为模板                    │
        ├─→ POST /api/templates ─────────→├─→ templates.push()
        │←─ JSON response                 │
        │                                  │
        │ 5. 导出 CSV                      │
        │ XLSX.writeFile()                 │
        │ (完全前端)                       │
```

---

## 🎯 新增功能：手动添加商品

现在已支持两种导入方式：

### 方式 1: 导入 Excel（现有）
```javascript
const reader = new FileReader()
reader.onload = (ev) => {
  const wb = XLSX.read(ev.target.result, { type: 'array' })
  const json = XLSX.utils.sheet_to_json(ws, { header: 1 })
  setProducts(items)
}
```

### 方式 2: 手动输入单个商品（新增 ✅）
```javascript
const handleAddProduct = (product: Product) => {
  setProducts([...products, product])
}
```

**对应的 UI 组件**: `ProductForm.tsx`
- 表单字段：name（必填）、category、brand、material、size、color、targetAudience
- 提交后自动重置表单
- 支持删除已添加的商品

---

## 🔧 前端调用示例

```typescript
// 生成
async function generate() {
  const res = await fetch('http://localhost:3000/api/generate-batch', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ items: products, options: {} })
  })
  const data = await res.json()
  setResults(data.results)
}

// 收藏模板
async function saveTemplate(title, points) {
  const res = await fetch('http://localhost:3000/api/templates', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      name: 'My Template',
      tags: [],
      parts: { titleTemplate: title, sellingPointsTemplates: points }
    })
  })
  const data = await res.json()
  console.log('Template saved:', data.template.id)
}

// 获取所有模板
async function loadTemplates() {
  const res = await fetch('http://localhost:3000/api/templates')
  const data = await res.json()
  console.log('Templates:', data.templates)
}
```

---

## 📍 URL 地址

| 服务 | 地址 |
|------|------|
| 前端 | http://localhost:5173 |
| 后端 API | http://localhost:3000 |
| 文档 | README.md, COMMUNICATION_GUIDE.md |

---

## 🚀 测试步骤

1. **启动服务**: `npm run dev`
2. **导入商品**: 方式 1（Excel）或方式 2（手动表单）
3. **生成草稿**: 点击"生成草稿" → 触发 `POST /api/generate-batch`
4. **编辑结果**: 前端本地修改，无需调用后端
5. **收藏模板**: 点击"收藏为模板" → 触发 `POST /api/templates`
6. **导出 CSV**: 前端生成，下载到本地
7. **管理模板**: 切换到"模板库"页签 → 支持 GET/POST/PUT/DELETE

---

## ⚠️ 常见问题

### Q: 为什么生成速度有点慢？
A: 后端在内存中生成 SVG 并转换为 base64，纯前端操作，正常。

### Q: 编辑后的数据会保存到后端吗？
A: 否。编辑只保存在前端 state 中。导出 CSV 时才固化到本地文件。

### Q: 如何实现商品持久化？
A: 添加 `POST /api/products` 和 `GET /api/products` 端点，使用数据库存储。

### Q: 如何用真实 AI 生成？
A: 修改 `server/index.js` 的 `generateDraftForItem()` 函数，调用 OpenAI/Claude API。详见 README.md。

---

## 📝 改进建议

- [ ] 添加请求错误处理和重试机制
- [ ] 实现前端缓存（减少 API 调用）
- [ ] 添加商品后端持久化
- [ ] 实现草稿版本历史
- [ ] 添加批量模板套用功能
- [ ] 前端表单验证增强
