# 📚 完整文档索引与答疑

## 🎯 三个核心问题的回答

### ❓ Q1: 前后端是如何通信的？

**简短答案**：
- 使用 **HTTP REST API + JSON** 通信
- 前端通过 `fetch()` 调用 5 个后端端点
- 启用 CORS 支持跨域请求

**详细信息**：[COMMUNICATION_SUMMARY.md](COMMUNICATION_SUMMARY.md) 中的"问题 1"部分

**可视化参考**：[DATA_FLOW_VISUALIZATION.md](DATA_FLOW_VISUALIZATION.md) 的"整体架构图"

---

### ❓ Q2: 他们传递了哪些数据？

**简短答案**：
- **导入**: Product[] (商品列表)
- **生成**: GenerateResult[] (包含主图、标题、卖点)
- **模板**: Template (模板定义)
- **数据量**: 100-200KB (5 个商品)

**详细信息**：[COMMUNICATION_SUMMARY.md](COMMUNICATION_SUMMARY.md) 中的"问题 2"部分

**数据结构**：[DATA_FLOW_VISUALIZATION.md](DATA_FLOW_VISUALIZATION.md) 中的"数据结构对比"部分

**实时示例**：[API_QUICK_REFERENCE.md](API_QUICK_REFERENCE.md) 中的"网络请求示例"

---

### ❓ Q3: 为什么前端无法创建单个商品的数据？

**简短答案**：
- 原设计只支持 Excel 导入
- ✅ **已解决**：新增 ProductForm 组件
- 现在支持手动输入商品

**解决方案**：[COMMUNICATION_SUMMARY.md](COMMUNICATION_SUMMARY.md) 中的"解决方案"部分

**新增组件**：
- `src/components/ProductForm.tsx` （商品表单）
- `src/pages/ImportPage.tsx` （已升级，集成表单）

---

## 📖 文档导航表

| 文档 | 内容 | 推荐阅读 |
|------|------|--------|
| **README.md** | 项目整体介绍、快速开始、API 文档、AI 集成指南 | ⭐ 必读 |
| **COMMUNICATION_SUMMARY.md** | 前后端通信详解、问题回答、新增功能说明 | ⭐ 必读 |
| **API_QUICK_REFERENCE.md** | 5 个 API 端点快速查询、请求响应示例、测试步骤 | ⭐ 常用 |
| **DATA_FLOW_VISUALIZATION.md** | 架构图、数据流向图、结构对比、网络示例 | ⭐ 参考 |
| **COMMUNICATION_GUIDE.md** | 前后端通信详细分析、完整数据模型、改进建议 | 深入理解 |
| **AGENT_PROMPT.md** | 原始业务需求提示词（发给 coding Agent） | 需求查证 |

---

## 🔧 快速查询

### 我想... 

#### 了解前后端通信方式
👉 [COMMUNICATION_SUMMARY.md](COMMUNICATION_SUMMARY.md) → "前后端通信详解"

#### 查看 API 请求/响应示例
👉 [API_QUICK_REFERENCE.md](API_QUICK_REFERENCE.md) → "5 个核心 API 端点"

#### 理解数据如何流转
👉 [DATA_FLOW_VISUALIZATION.md](DATA_FLOW_VISUALIZATION.md) → "数据流向细节"

#### 了解新增功能（手动添加商品）
👉 [COMMUNICATION_SUMMARY.md](COMMUNICATION_SUMMARY.md) → "解决方案"

#### 查看完整的前后端通信时序图
👉 [DATA_FLOW_VISUALIZATION.md](DATA_FLOW_VISUALIZATION.md) → "时序图"

#### 学习如何集成真实 AI 服务
👉 [README.md](README.md) → "🤖 如何替换为真实 AI 服务"

#### 查看项目文件结构
👉 [README.md](README.md) → "📁 项目结构"

---

## 🎓 学习路线

### 初级（快速了解）
1. 阅读 [README.md](README.md) 的"快速开始"和"功能细化"
2. 扫一眼 [API_QUICK_REFERENCE.md](API_QUICK_REFERENCE.md) 的 API 列表
3. 在浏览器里实际操作一遍（导入 → 生成 → 编辑 → 导出）

### 中级（理解机制）
1. 阅读 [COMMUNICATION_SUMMARY.md](COMMUNICATION_SUMMARY.md) 的三个问题答案
2. 对照 [DATA_FLOW_VISUALIZATION.md](DATA_FLOW_VISUALIZATION.md) 的架构图理解组件关系
3. 查看 [API_QUICK_REFERENCE.md](API_QUICK_REFERENCE.md) 的测试步骤，逐个验证 API

### 高级（二次开发）
1. 阅读 [COMMUNICATION_GUIDE.md](COMMUNICATION_GUIDE.md) 的完整分析
2. 研究 `src/pages/ImportPage.tsx` 和 `server/index.js` 的源码
3. 按 [README.md](README.md) 中的"AI 集成指南"替换生成逻辑
4. 实现后端数据库持久化（参考 [COMMUNICATION_GUIDE.md](COMMUNICATION_GUIDE.md) 的改进建议）

---

## 📊 数据流速查表

| 操作 | 方向 | 大小 | 端点 |
|------|------|------|------|
| 导入 Excel | ← | ~25KB | 本地 |
| 生成草稿 | → ← | 100KB | POST /api/generate-batch |
| 编辑结果 | - | 0KB | 本地 |
| 收藏模板 | → | 5KB | POST /api/templates |
| 导出 CSV | ← | ~50KB | 本地 |
| 查看模板 | → ← | 10KB | GET /api/templates |

---

## 🚀 运行与测试

### 启动命令
```bash
npm install        # 安装依赖
npm run gen-samples # 生成示例数据
npm run dev        # 启动前后端
```

### 验证清单
- [ ] 前端 http://localhost:5173 正常打开
- [ ] 后端 http://localhost:3000 API 可访问
- [ ] 导入示例 Excel 成功
- [ ] 手动添加商品表单正常工作 ✅ 新功能
- [ ] 生成草稿成功（POST /api/generate-batch）
- [ ] 编辑结果并保存
- [ ] 收藏为模板（POST /api/templates）
- [ ] 导出 CSV 文件
- [ ] 切换模板库页签，查看已收藏模板

---

## 💡 常见问题解答 (FAQ)

### Q: 编辑后的数据会保存到后端吗？
**A**: 不会。编辑只保存在前端 state 中。如需持久化，需导出 CSV 或收藏为模板。

### Q: 刷新页面后，编辑的内容会丢失吗？
**A**: 是的。除了 localStorage 中的模板以外，其他数据都在内存中。建议导出 CSV 或收藏模板。

### Q: 后端服务重启后，模板会丢失吗？
**A**: 是的。模板存储在后端内存数组中。建议在生产环境使用数据库。

### Q: 如何将 SVG 图片转换为 PNG？
**A**: 使用 Canvas API 或服务如 `sharp` 库。参考 [README.md](README.md) 的"AI 集成指南"。

### Q: 如何支持图片上传？
**A**: 修改 ProductForm 添加 `<input type="file" accept="image/*" />`，转换为 base64 后包含在 Product 中。

### Q: 如何扩展为多租户系统？
**A**: 添加用户认证（JWT）和租户字段，按租户隔离数据。详见 [COMMUNICATION_GUIDE.md](COMMUNICATION_GUIDE.md) 的"改进建议"。

---

## 📁 项目文件一览

### 新增文件（回答问题）
```
✨ COMMUNICATION_SUMMARY.md   ← 完整答疑（问题 1-3 的详细回答）
✨ DATA_FLOW_VISUALIZATION.md ← 可视化图表（架构、数据流、状态）
✨ API_QUICK_REFERENCE.md     ← API 快速参考（5 个端点、示例、测试）
✨ 本文件 (INDEX.md)          ← 文档导航与 FAQ
```

### 新增代码（解决"无法创建商品"问题）
```
✨ src/components/ProductForm.tsx    ← 手动添加商品的表单
✨ src/pages/ImportPage.tsx (改进)   ← 集成 ProductForm，支持删除商品
```

### 原有文件（已保留）
```
📖 README.md
📖 AGENT_PROMPT.md
📖 COMMUNICATION_GUIDE.md

📁 src/pages/App.tsx
📁 src/components/ResultCard.tsx
📁 src/components/TemplateManager.tsx
📁 server/index.js
📁 examples/
📁 package.json, vite.config.ts, etc.
```

---

## 🎯 总结

| 方面 | 答案 | 参考文档 |
|------|------|--------|
| **Q: 前后端如何通信？** | HTTP REST API + JSON，fetch() 调用 5 个端点 | COMMUNICATION_SUMMARY.md |
| **Q: 传递哪些数据？** | Product[], GenerateResult[], Template，100-200KB | API_QUICK_REFERENCE.md |
| **Q: 为什么无法创建商品？** | 原设计缺少手动表单，✅ 已新增 ProductForm 组件 | COMMUNICATION_SUMMARY.md |
| **如何部署？** | 见 README.md 的"生产部署"部分 | README.md |
| **如何集成 AI？** | 修改 generateDraftForItem()，调用 LLM API | README.md |
| **如何持久化？** | 添加数据库，实现 /api/products, /api/drafts 端点 | COMMUNICATION_GUIDE.md |

---

## 🤝 反馈与改进

如果对文档或代码有任何问题，可以：

1. **检查本文档**: 先查本文档的 FAQ 部分
2. **查阅 API 文档**: [API_QUICK_REFERENCE.md](API_QUICK_REFERENCE.md)
3. **深入理解**: 读 [COMMUNICATION_GUIDE.md](COMMUNICATION_GUIDE.md) 和 [DATA_FLOW_VISUALIZATION.md](DATA_FLOW_VISUALIZATION.md)
4. **查看源码**: 阅读 `src/pages/ImportPage.tsx` 和 `server/index.js`

---

**祝你编码愉快！** 🚀✨
