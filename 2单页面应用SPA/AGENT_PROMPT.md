# 发给 Coding Agent 的完整提示词

以下是用于生成完整项目代码的提示词。你可以复制整个内容直接粘贴给 coding Agent（如 GitHub Copilot、Claude 等）。

---

## 📋 完整提示词

**任务目标**: 实现一个单页面应用（SPA）用来验证核心玩法。第一优先：批量生成第一版图文草稿（可直接拿去上架或轻改）。第二优先：把好用的输出沉淀成可复用的模板库。请输出可运行的代码仓库（前端 + 简单后端或 mock），并包含 README 与示例数据。

**技术栈建议（可接受替代）**: React + Vite + TypeScript（前端）；Node + Express（轻量后端，可选）；UI 可用 Ant Design / Mantine；文件存储使用本地 filesystem（开发时）或返回图片 data URL；模板与素材可先用 localStorage 或一个简单 JSON 文件（后端）持久化。

### 优先交付物
- 可运行的仓库（`npm install` / `pnpm` / `yarn`）；
- 前端 SPA：页面路由、导入/上传界面、批量生成结果展示、模板收藏页；
- 后端（或 mock）：`/api/generate-batch`, `/api/templates`, `/api/materials`；
- README：运行与测试步骤、示例 Excel、示例商品数据；
- 最小自动化测试或手动验收步骤。

### 功能细化（必须实现，先聚焦 1）

#### 1) 帮运营批量生成第一版图文草稿（核心优先）

**输入（前端 UI 需支持）**：
- 商品基础信息字段：`name`, `category`, `brand`, `material`, `size`, `color`, `targetAudience`, `sku` 等。
- 商品图片上传（支持多张）：白底图与场景图。
- 额外参考：上传历史爆款截图或粘贴参考链接（可选）。
- 支持 Excel 批量导入（示例：第一行字段名映射到上述字段），或在页面上在线录入/粘贴 CSV。
- 每条物料可选择"保存到素材库"（checkbox）。

**后端接口**：
- POST `/api/generate-batch` 请求体示例：
  ```json
  {
    "items": [ { product fields..., "images": [data URLs or upload ids], "references": [...] }, ... ],
    "options": { "saveToLibrary": true/false, "templateId": optional }
  }
  ```
- 返回示例：
  ```json
  {
    "results": [ { "productId": "...", "mainImageDraft": "data:image/...", "titleDraft": "...", "sellingPoints": ["...","..."], "confidence": 0.8 }, ... ]
  }
  ```

**生成策略**（可实现 mock 或简单规则 + 可插入 AI Hook）：
- 如果没有 AI key，可实现基于模板的占位生成：标题模板示例 `"【品牌】{name}，{color}，适合{targetAudience}，{material}材质"`；卖点从字段映射拼接 1-2 句。
- 同时在代码中保留一个 `generateWithAI(item)` 接口占位，文档说明如何替换为真实 LLM/视觉生成服务（例如 OpenAI/其他）。

**输出（UI 要清晰展示并支持复制/导出）**：
- 每个商品展示一张主图草稿（可基于白底图在 Canvas 上添加占位文字/标签，或生成带文字水印的组合图），并能下载。
- 每个商品展示标题草稿和 1–2 条卖点文案，支持编辑并保存为最终稿或导出 CSV。
- 支持批量"接受全部/接受选中/重新生成选中"操作。

**验收标准**：
- 能上传或导入至少 5 条商品并触发批量生成，前端展示对应主图草稿、标题与卖点草稿；
- 单条编辑并保存生效（保存到本地或后端 mock 存储）；
- 导出功能能把选中条目导出为 CSV（包含图片为 data URL 或外链）。

#### 2) 模板库（次要，需提供基础实现以验证流程）

**任意输出可"一键收藏"**：
- 支持收藏整套（主图+标题+卖点）或只收藏标题结构/卖点段落。

**收藏项元数据**：`id, name, tags[], scope(store/shop), createdBy, templateParts:{imageTemplate?, titleTemplate?, sellingPointsTemplate[]}`。

**收藏后能做**：
- 复用：批量套用模板到新商品集合（调用 `/api/generate-batch` 时传 `templateId`，后端把模板结构和新品数据合成草稿）；
- 编辑：在前端直接修改标题/卖点并另存为新模板；
- 管理：给模板起名、打标签、按店铺/标签筛选。

**简化实现建议**：模板存储在 localStorage 或后端 JSON 文件，界面提供：收藏、列表、套用到选中商品、编辑并保存。

### 数据模型示例

**Product**:
```javascript
{
  id: string,
  name: string,
  category: string,
  brand: string,
  material?: string,
  size?: string,
  color?: string,
  targetAudience?: string,
  images: string[] // data URLs or upload ids
}
```

**Template**:
```javascript
{
  id: string,
  name: string,
  tags: string[],
  parts: { titleTemplate?: string, sellingPointsTemplates?: string[], imageTemplate?: object }
}
```

**GenerateResult**:
```javascript
{
  productId: string,
  mainImageDraft: string, // data URL
  titleDraft: string,
  sellingPoints: string[],
  templateUsed?: string
}
```

### UX 关键点（为开发提供明确实现期望）

- **批量导入界面**：文件拖拽、字段映射弹窗（Excel 列 → 系统字段）、校验反馈（缺少必填字段高亮）。
- **批量生成后台任务感**：前端展示任务进度（队列/进度条），每条生成后即时展示。
- **生成结果卡片**：显示缩略图、标题、卖点、操作按钮（编辑、收藏为模板、下载、重新生成）。
- **模板管理界面**：列表、搜索/过滤、详情预览、套用按钮。

### 实现细节/实现提示给 coding Agent

- 先做前端 MVP 与简单 mock 后端，保证可以本地运行与演示；
- 图像草稿可用 Canvas API 合成：把上传白底图放置为底图，自动在图上右下角写上商品短标题与标签（使用简洁样式即可）；
- 标题与卖点初版用规则引擎（模板 + 字段填充），并在代码中写明如何替换为 LLM 调用（示例：`/api/ai/generate`）；
- Excel 导入推荐使用 `xlsx` 库解析并提供列映射 UI；
- 用 TypeScript 定义所有主要接口与数据模型，便于后续替换真实后端；
- 提供示例 Excel（5 条商品）和几张示例白底图以便演示。

### 验收交付清单（deliverables）

- 完整项目代码仓库，包含 `README.md`（运行、替换 AI Hook、部署说明）；
- 示例数据：`examples/products.xlsx`, `examples/images/*`；
- 演示步骤（手动验收清单）：
  - 启动后端与前端；
  - 在导入页上传 `products.xlsx` 并映射列；
  - 触发批量生成，查看并编辑结果、导出 CSV；
  - 收藏一条模板并用该模板对新导入的一批商品重新生成草稿；
  -（可选）简单单元/集成测试覆盖关键逻辑：导入解析、生成模板替换、模板套用。

### 给 coding Agent 的额外要求

- 代码须干净、模块化且包含注释（说明关键位置：AI 接口、图片合成、模板套用逻辑）；
- 在 README 明确标注：如何替换 mock 生成逻辑为真实 LLM/视觉服务（示例请求格式与字段映射）；
- 若时间有限，请至少完整实现"批量上传/导入 → 生成草稿 → 编辑/导出"闭环，然后把模板库实现为可基本操作的最小版本。

---

## 💡 示例 Prompt 片段（可直接用于代码注释或 README）

"第一步请实现批量导入并基于字段模板生成标题与卖点文本，图片草稿使用 Canvas 在上传白底图上叠加短文本与角标。把生成逻辑封装为 `generateDraft(product, template?)`，并暴露 REST 接口 `/api/generate-batch`。模板持久化先用 localStorage（或后端 JSON），并提供 `GET/POST /api/templates`。"

---

## 使用说明

1. 将上述提示词复制到你选择的 Coding Agent（如 GitHub Copilot、Claude 等）
2. 根据反馈和生成的代码，进行迭代优化
3. 参考本仓库中的 `server/` 和 `src/` 目录作为实现参考
4. 遇到问题时，可以补充更多具体的错误日志或需求细化
