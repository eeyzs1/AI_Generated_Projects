# 文档查询 Agent - 配置指南（游客模式）

这是一个基于 LangChain + MCP + RAG 的智能文档查询系统，**无需任何 API Key 即可使用**。

## 🎯 功能特性

- ✅ **游客模式**：无需配置任何 API Key，即开即用
- ✅ **文档上传与处理**：支持 PDF、DOCX、TXT、Markdown 格式
- ✅ **本地关键词检索**：使用关键词匹配实现 RAG 功能
- ✅ **MCP（模型上下文协议）**：集成多个工具增强 AI 能力
- ✅ **本地 AI 服务**：使用 z-ai-web-dev-sdk，无需外部 API
- ✅ **现代化界面**：基于 Next.js 16 + shadcn/ui

## 🚀 快速开始（游客模式）

### 1. 环境要求

- Node.js 18+
- Bun (推荐) 或 npm/yarn

### 2. 安装依赖

```bash
bun install
```

### 3. 环境配置

编辑 `.env` 文件：

```env
# MySQL 数据库连接（可选，游客模式使用内存存储）
DATABASE_URL="mysql://root:password@localhost:3306/document_query_db"

# 游客模式 - 无需任何 API Key
# 使用本地 z-ai-web-dev-sdk 和关键词匹配
```

**游客模式特点**：
- ❌ 不需要 OpenAI API Key
- ❌ 不需要任何第三方 API Key
- ✅ 使用本地 z-ai-web-dev-sdk
- ✅ 使用关键词匹配进行文档检索
- ✅ 完全免费，无需付费

### 4. 运行开发服务器

```bash
bun run dev
```

应用将在 `http://localhost:3000` 启动

## 📁 项目结构

```
src/
├── app/
│   ├── api/
│   │   ├── documents/
│   │   │   ├── route.ts          # 文档列表 API
│   │   │   ├── upload/
│   │   │   │   └── route.ts      # 文档上传 API
│   │   │   └── [id]/
│   │   │       └── route.ts      # 文档删除 API
│   │   └── chat/
│   │       └── route.ts          # 聊天对话 API（使用 z-ai-web-dev-sdk）
│   ├── page.tsx                  # 主页面（前端）
│   └── layout.tsx
├── lib/
│   ├── memory-store.ts           # 内存存储（游客模式默认）
│   ├── document-processor.ts     # 文档处理
│   ├── vector-store.ts           # 关键词检索存储（游客模式）
│   ├── mcp-tools.ts              # MCP 工具集成
│   └── db.ts                     # 数据库客户端
└── components/ui/                # shadcn/ui 组件

prisma/
└── schema.prisma                 # 数据库 Schema
```

## 🛠️ 游客模式技术实现

### 1. 文档检索（关键词匹配）

使用本地关键词匹配替代 OpenAI Embeddings：

```typescript
// src/lib/vector-store.ts
class KeywordVectorStore {
  // 提取关键词
  private extractKeywords(text: string): string[] {
    // 中文和英文关键词提取
    // 移除停用词
    // 返回关键词列表
  }

  // 计算关键词匹配分数
  private calculateScore(queryKeywords: string[], docKeywords: string[]): number {
    // 计算关键词重叠度
    // 返回匹配分数
  }
}
```

### 2. AI 对话（z-ai-web-dev-sdk）

使用本地的 z-ai-web-dev-sdk 替代 OpenAI API：

```typescript
// src/app/api/chat/route.ts
const { createLLMClient } = await import('z-ai-web-dev-sdk')
const llmClient = createLLMClient()

const result = await llmClient.chat({
  messages: messages,
  model: 'gpt-4o-mini'
})
```

### 3. 降级策略

如果 z-ai-web-dev-sdk 不可用，会自动使用基于规则的降级响应：

```typescript
function generateFallbackResponse(query: string, relevantDocs: any[]): string {
  // 返回基于文档的简单响应
  // 提示用户这是游客模式
}
```

## 🛠️ MCP 工具说明

系统内置了以下 MCP 工具：

1. **get_current_time**: 获取当前时间和日期
2. **calculate**: 计算数学表达式
3. **web_search**: 网络搜索（占位符，需集成真实API）
4. **get_document_stats**: 获取文档统计信息
5. **summarize_text**: 文本摘要
6. **extract_key_info**: 提取关键信息

添加新工具，编辑 `src/lib/mcp-tools.ts`：

```typescript
this.registerTool({
  name: 'your_tool_name',
  description: '工具描述',
  execute: async (params) => {
    // 实现工具逻辑
    return '工具执行结果'
  }
})
```

## 📚 RAG 工作流程（游客模式）

1. **文档上传** → 解析文本内容
2. **文本分块** → 使用 RecursiveCharacterTextSplitter
3. **关键词提取** → 提取中英文关键词
4. **本地存储** → 保存关键词和文档块
5. **用户查询** → 提取查询关键词
6. **关键词匹配** → 计算关键词重叠度
7. **上下文增强** → 将匹配结果作为上下文
8. **生成回答** → 使用 z-ai-web-dev-sdk 生成响应

## 🎨 前端组件

- **左侧边栏**：文档列表和上传，显示"游客模式"标识
- **主区域**：聊天对话界面
- **消息展示**：支持来源引用
- **响应式设计**：适配移动端

## 📝 使用示例

### 上传文档

1. 点击左侧 "上传文档" 按钮
2. 选择支持格式的文件（PDF、DOCX、TXT、MD）
3. 等待处理完成（状态变为"就绪"）

### 查询文档

在聊天输入框中输入问题，例如：
- "总结这篇文档的主要观点"
- "文档中提到了哪些关键数据？"
- "解释这个概念的含义"

## 🆚 游客模式 vs 完整模式

| 特性 | 游客模式 | 完整模式 |
|------|---------|---------|
| API Key | 不需要 | 需要 OpenAI API Key |
| 文档检索 | 关键词匹配 | 向量嵌入 |
| AI 模型 | z-ai-web-dev-sdk | OpenAI GPT |
| 检索精度 | 中等 | 高 |
| 成本 | 完全免费 | 按使用付费 |
| 设置难度 | 零配置 | 需要配置 API |

## 🔒 注意事项

1. **游客模式限制**：
   - 文档检索精度较低（关键词匹配）
   - AI 响应可能不够智能
   - 仅支持中英文关键词

2. **文件大小限制**：建议单个文件不超过 10MB

3. **数据存储**：游客模式使用内存存储，服务器重启后数据会丢失

## 🚀 性能优化建议

1. **改进关键词匹配**：
   - 实现词干提取
   - 添加同义词扩展
   - 使用 TF-IDF 算法

2. **本地向量模型**：
   - 使用 @xenova/transformers
   - 加载轻量级嵌入模型
   - 在本地进行向量化

3. **实现缓存机制**：缓存常见查询结果

## 🐛 故障排除

### 问题：文档上传失败

- 检查文件格式是否支持
- 查看服务器日志获取详细错误信息

### 问题：聊天无响应

- 检查 z-ai-web-dev-sdk 是否正常
- 确认网络连接正常
- 查看浏览器控制台错误信息

### 问题：检索无结果

- 确认文档已成功处理（状态为"就绪"）
- 检查文档内容是否为空
- 尝试调整查询关键词

## 📄 技术栈

- **前端**：Next.js 16, React, TypeScript, Tailwind CSS, shadcn/ui
- **后端**：Next.js API Routes, LangChain
- **AI 服务**：z-ai-web-dev-sdk（游客模式）
- **文档处理**：pdf-parse, mammoth
- **文档检索**：关键词匹配（可升级为向量检索）
- **存储**：内存存储（可升级为 MySQL + 向量数据库）

## 🔄 升级到完整模式

如果需要更好的效果，可以升级到完整模式：

### 步骤 1：配置 OpenAI API

```env
OPENAI_API_KEY="your-openai-api-key-here"
```

### 步骤 2：修改向量存储

编辑 `src/lib/vector-store.ts`，替换关键词存储为向量存储：

```typescript
// 使用 OpenAI Embeddings
import { OpenAIEmbeddings } from '@langchain/openai'
```

### 步骤 3：修改聊天 API

编辑 `src/app/api/chat/route.ts`，使用 OpenAI LLM：

```typescript
import { ChatOpenAI } from '@langchain/openai'
```

## 📞 支持

如有问题，请查看：
- [LangChain 文档](https://js.langchain.com/)
- [Next.js 文档](https://nextjs.org/docs)
- [z-ai-web-dev-sdk 文档](https://sdk.z.ai/)

---

**游客模式特点**：
- ✅ 无需任何 API Key
- ✅ 完全免费使用
- ✅ 零配置启动
- ✅ 适合演示和测试
- ⚠️ 检索精度有限
- ⚠️ 数据不持久化
