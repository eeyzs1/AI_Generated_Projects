# 前后端通信分析与改进方案

## 📡 当前前后端通信机制

### 通信方式
- **协议**: HTTP REST API + JSON
- **跨域**: 启用 CORS（后端 `app.use(cors())`）
- **数据格式**: JSON
- **通信库**: 前端使用原生 `fetch()` API

### 通信流程图

```
┌─────────────────────┐                     ┌──────────────────────┐
│   前端 (Vite React) │                     │ 后端 (Express)       │
│ http://localhost:5173                     │ http://localhost:3000│
└─────────────────────┘                     └──────────────────────┘
         │                                            │
         │ 1. handleFile() 读取 Excel 文件           │
         │    (本地处理，不涉及后端)                  │
         │                                            │
         │ 2. generate() 发送批量生成请求              │
         ├─────POST /api/generate-batch──────────────>│
         │  {                                         │
         │    "items": [...Product[]...],             │
         │    "options": {                            │
         │      "saveToLibrary": false,               │
         │      "templateId": "tpl-xxx" (可选)        │
         │    }                                       │
         │  }                                         │
         │                                  generateDraftForItem()
         │                                  - 规则引擎/模板替换
         │                                  - SVG 主图合成
         │                                            │
         │<─────响应 200 OK (JSON)────────────────────┤
         │  {                                         │
         │    "results": [                            │
         │      {                                     │
         │        "productId": "p-0",                 │
         │        "mainImageDraft": "data:image/...", │
         │        "titleDraft": "...",                │
         │        "sellingPoints": ["...", "..."]     │
         │      }                                     │
         │    ]                                       │
         │  }                                         │
         │                                            │
         │ 3. handleEditResult() 本地编辑             │
         │    (修改存储在前端 state)                  │
         │                                            │
         │ 4. handleSaveTemplate() 收藏到本地存储      │
         │    localStorage.setItem('product_templates')│
         │    (可选：也可 POST 到后端)                │
         │                                            │
         │ 5. 模板库管理                              │
         ├─────GET /api/templates────────────────────>│
         │<─────[{ id, name, tags, parts }, ...]─────┤
         │                                            │
         ├─────POST /api/templates───────────────────>│
         │  { "name": "...", "tags": [...], "parts": {...} }
         │<─────{ "template": {...} }─────────────────┤
         │                                            │
         ├─────DELETE /api/templates/:id─────────────>│
         │<─────{ "success": true }───────────────────┤
         │                                            │
         ├─────PUT /api/templates/:id────────────────>│
         │<─────{ "template": {...} }─────────────────┤
```

---

## 📊 数据流详解

### 1️⃣ 批量导入（前端本地处理）

**操作**: 用户上传 Excel 文件 → 前端解析

```javascript
// 前端 ImportPage.tsx
const reader = new FileReader()
reader.onload = (ev) => {
  const wb = XLSX.read(ev.target.result, { type: 'array' })
  const json = XLSX.utils.sheet_to_json(ws, { header: 1 })
  // 解析后的商品列表存储在 state: products
  setProducts(items)
}
```

**数据结构**:
```javascript
Product {
  id: "p-0",
  name: "羊绒围巾",
  category: "围巾",
  brand: "Luxe",
  material: "100% 羊绒",
  size: "180cm x 30cm",
  color: "深灰色",
  targetAudience: "白领女性"
}
```

### 2️⃣ 批量生成（POST /api/generate-batch）

**发送请求**:
```javascript
// 前端发送
fetch('http://localhost:3000/api/generate-batch', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    items: products,        // 前面导入的商品列表
    options: {
      saveToLibrary: false,
      templateId: "tpl-xxx" // 可选，如果使用模板
    }
  })
})
```

**后端处理流程**:
```javascript
// server/index.js
app.post('/api/generate-batch', (req, res) => {
  const { items, options } = req.body
  const templateId = options?.templateId
  
  // 如果指定了模板，查找模板
  let template = null
  if (templateId) {
    template = templates.find(t => t.id === templateId)
  }
  
  // 对每个商品调用 generateDraftForItem()
  const results = items.map(item => generateDraftForItem(item, template))
  
  res.json({ results })
})
```

**生成逻辑**:
```javascript
function generateDraftForItem(item, template = null) {
  // ① 优先使用模板生成
  if (template && template.parts.titleTemplate) {
    titleDraft = template.parts.titleTemplate
      .replace(/{name}/g, item.name)
      .replace(/{brand}/g, item.brand)
      // ... 其他字段替换
  } else {
    // ② 否则使用规则引擎
    titleDraft = `${item.brand} ${item.name} ${item.color}`.trim()
    // 字段 → 卖点映射
  }
  
  // ③ 生成 SVG 主图
  const svg = `<svg>...</svg>`
  const img = 'data:image/svg+xml;base64,' + btoa(svg)
  
  return {
    productId: item.id,
    mainImageDraft: img,
    titleDraft,
    sellingPoints: [...]
  }
}
```

**返回数据**:
```javascript
{
  "results": [
    {
      "productId": "p-0",
      "mainImageDraft": "data:image/svg+xml;base64,PHN2ZyB4bWxucz0n...",
      "titleDraft": "Luxe 羊绒围巾 深灰色",
      "sellingPoints": ["100% 羊绒 材质", "适合白领女性"]
    },
    // ... 其他商品
  ]
}
```

### 3️⃣ 编辑与保存（前端本地）

**编辑流程**:
```javascript
// 所有编辑都在前端 state 中进行
const handleEditResult = (productId, title, points) => {
  const updated = new Map(editedResults)
  const result = updated.get(productId)
  if (result) {
    result.titleDraft = title  // 修改标题
    result.sellingPoints = points  // 修改卖点
    updated.set(productId, result)
    setEditedResults(updated)  // 保存到前端 state
  }
}
```

**注意**: 这是完全的**前端本地修改**，没有发送到后端。只有导出或收藏时才涉及后端。

### 4️⃣ 模板收藏与管理

#### 方案 A：前端 localStorage（当前实现）
```javascript
const handleSaveTemplate = (productId, title, points) => {
  const templateData = {
    id: 'tpl-' + productId + '-' + Date.now(),
    name: `${product.name} - 模板`,
    tags: [],
    parts: {
      titleTemplate: title,
      sellingPointsTemplates: points,
    }
  }
  
  // 保存到浏览器本地存储
  const templates = JSON.parse(localStorage.getItem('product_templates') || '[]')
  templates.push(templateData)
  localStorage.setItem('product_templates', JSON.stringify(templates))
}
```

#### 方案 B：后端存储（推荐，但当前未实现）
```javascript
// 应该改为：
const res = await fetch('http://localhost:3000/api/templates', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(templateData)
})
```

---

## ❌ 问题 1: 为什么前端无法创建单个商品数据？

### 根本原因

**当前架构只支持 3 种操作**:
1. ✅ 导入 Excel（批量）
2. ✅ 编辑已生成的结果（本地）
3. ❌ 手动输入单个商品（**缺失**）

### 原因分析

在 `ImportPage.tsx` 中：
- 只有 `handleFile()` 函数处理文件导入
- 没有"新增单条"的 UI 或逻辑
- 产品列表 `products` 只能通过 Excel 更新

---

## ✅ 改进方案：添加"新增单个商品"功能

### 第 1 步：添加产品表单组件

创建新文件 `src/components/ProductForm.tsx`:

```typescript
import React, { useState } from 'react'

export type ProductFormProps = {
  onSubmit?: (product: Product) => void
  initialData?: Partial<Product>
}

export default function ProductForm({ onSubmit, initialData }: ProductFormProps) {
  const [form, setForm] = useState({
    name: initialData?.name || '',
    category: initialData?.category || '',
    brand: initialData?.brand || '',
    material: initialData?.material || '',
    size: initialData?.size || '',
    color: initialData?.color || '',
    targetAudience: initialData?.targetAudience || '',
  })

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (!form.name) {
      alert('请输入商品名称')
      return
    }
    
    const product = {
      id: 'p-' + Date.now(),
      ...form
    }
    
    onSubmit?.(product)
    setForm({ name: '', category: '', brand: '', material: '', size: '', color: '', targetAudience: '' })
  }

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target
    setForm({ ...form, [name]: value })
  }

  return (
    <form onSubmit={handleSubmit} style={styles.form}>
      <div style={styles.grid}>
        <label>商品名称（必填）：<br />
          <input type="text" name="name" value={form.name} onChange={handleChange} required />
        </label>
        <label>品牌：<br />
          <input type="text" name="brand" value={form.brand} onChange={handleChange} />
        </label>
        <label>分类：<br />
          <input type="text" name="category" value={form.category} onChange={handleChange} />
        </label>
        <label>颜色：<br />
          <input type="text" name="color" value={form.color} onChange={handleChange} />
        </label>
        <label>材质：<br />
          <input type="text" name="material" value={form.material} onChange={handleChange} />
        </label>
        <label>尺寸：<br />
          <input type="text" name="size" value={form.size} onChange={handleChange} />
        </label>
        <label>目标人群：<br />
          <input type="text" name="targetAudience" value={form.targetAudience} onChange={handleChange} />
        </label>
      </div>
      <button type="submit" style={styles.btn}>添加商品</button>
    </form>
  )
}

const styles = {
  form: { padding: '16px', backgroundColor: '#f9f9f9', borderRadius: '4px', marginBottom: '16px' } as React.CSSProperties,
  grid: { display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(150px, 1fr))', gap: '12px', marginBottom: '12px' } as React.CSSProperties,
  btn: { padding: '8px 12px', backgroundColor: '#1890ff', color: '#fff', border: 'none', borderRadius: '4px', cursor: 'pointer' } as React.CSSProperties,
}
```

### 第 2 步：在 ImportPage 中集成表单

在 `ImportPage.tsx` 添加：

```typescript
import ProductForm from '../components/ProductForm'

export default function ImportPage() {
  // ... 现有代码 ...
  
  const handleAddProduct = (product: Product) => {
    setProducts([...products, product])
    alert(`已添加商品: ${product.name}`)
  }

  return (
    <div style={styles.container}>
      {/* ... 现有标签页代码 ... */}
      
      {activeTab === 'import' && (
        <div style={styles.content}>
          {/* 现有的文件导入 */}
          <div style={styles.section}>
            <h2>方式 1: 导入 Excel 文件</h2>
            <input type="file" accept=".xlsx,.xls" onChange={handleFile} />
          </div>
          
          {/* 新增：手动添加单个商品 */}
          <div style={styles.section}>
            <h2>方式 2: 手动添加商品</h2>
            <ProductForm onSubmit={handleAddProduct} />
          </div>
          
          {/* 已导入商品列表 */}
          {products.length > 0 && (
            <div style={styles.section}>
              <h3>已导入商品 ({products.length})</h3>
              <ul>
                {products.map(p => (
                  <li key={p.id}>
                    {p.name} - {p.brand} 
                    <button onClick={() => {
                      setProducts(products.filter(x => x.id !== p.id))
                    }} style={{ marginLeft: '12px', color: '#ff4d4f' }}>
                      删除
                    </button>
                  </li>
                ))}
              </ul>
            </div>
          )}
          
          {/* ... 现有生成按钮 ... */}
        </div>
      )}
    </div>
  )
}
```

---

## 📈 完整的前后端通信时序图

```
用户操作                      前端                          后端
    │                        │                              │
    ├─ 上传 Excel ─────────→ handleFile()                  │
    │                        │ XLSX.read()                  │
    │                        │ setProducts()                │
    │                        │                              │
    ├─ 或手动输入 ─────────→ handleAddProduct()            │
    │                        │ setProducts()                │
    │                        │                              │
    ├─ 点击"生成草稿" ──────→ generate()                   │
    │                        │ fetch POST                   │
    │                        ├─────/api/generate-batch─────→ generateDraftForItem()
    │                        │                              │ (规则引擎 or 模板)
    │                        │<─────JSON response──────────│
    │                        │ setResults()                 │
    │                        │                              │
    ├─ 查看结果 ───────────→ ResultCard 展示               │
    │                        │                              │
    ├─ 编辑标题/卖点 ──────→ handleEditResult()            │
    │                        │ (本地修改)                   │
    │                        │                              │
    ├─ 收藏为模板 ────────→ handleSaveTemplate()          │
    │                        │ localStorage (or)            │
    │                        ├─────POST /api/templates────→ templates.push()
    │                        │<─────{ template: {...} }───│
    │                        │                              │
    ├─ 导出 CSV ───────────→ exportCSV()                   │
    │                        │ XLSX.utils.json_to_sheet()   │
    │                        │ XLSX.writeFile()             │
    │                        │                              │
    └─ (下次)使用模板生成 ──→ generate(templateId)        │
                             ├─────/api/generate-batch────→
                             │     { templateId: "..." }    │
                             │<─────(套用模板生成)──────────│
```

---

## 🔧 如何修复"无法创建单个商品"问题

### 快速修复（已提供方案）
1. 创建 `ProductForm.tsx` 组件
2. 在 `ImportPage.tsx` 集成表单
3. 添加 `handleAddProduct()` 方法
4. 支持删除已添加的商品

### 高级修复（可选）
- 从后端持久化商品库：`POST /api/products`
- 实现草稿保存：`POST /api/drafts` 存储草稿历史
- 实现商品库管理：前端可浏览/编辑/删除已保存商品

---

## 📚 数据在各环节的完整流向

| 阶段 | 数据位置 | 存储方式 | 可访问范围 |
|------|---------|--------|----------|
| 1. 导入 | `state: products` | 内存 | 当前会话 |
| 2. 生成 | `state: results` | 内存 | 当前会话 |
| 3. 编辑 | `state: editedResults (Map)` | 内存 | 当前会话 |
| 4. 导出 | CSV 文件 | 本地文件系统 | 永久 |
| 5. 收藏模板 | `localStorage` 或后端 | 本地存储/DB | 跨会话 |

---

## 🎯 总结

| 问题 | 答案 |
|------|------|
| **前后端如何通信？** | HTTP REST API + JSON，前端用 fetch() 调用后端的 5 个端点 |
| **传递了哪些数据？** | Product[], GenerateResult[], Template 对象，通过 POST/GET/PUT/DELETE 操作 |
| **为什么无法创建单个商品？** | 当前只有 Excel 导入入口，缺少"手动添加"的 UI 和逻辑 |
| **如何修复？** | 添加 ProductForm 组件，实现手动输入商品的功能（见上面的代码示例） |
