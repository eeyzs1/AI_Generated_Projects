import { NextResponse } from 'next/server'
import { vectorStoreManager } from '@/lib/vector-store'
import { mcpTools } from '@/lib/mcp-tools'

/**
 * Chat API using z-ai-web-dev-sdk (Guest Mode - No API Key Required)
 */
export async function POST(request: Request) {
  try {
    const { message, history } = await request.json()

    if (!message || typeof message !== 'string') {
      return NextResponse.json(
        { error: 'Invalid message' },
        { status: 400 }
      )
    }

    // RAG: Retrieve relevant documents
    const relevantDocs = await vectorStoreManager.similaritySearch(message, 4)

    // Build context from retrieved documents
    const context = relevantDocs.length > 0
      ? relevantDocs.map(doc => doc.pageContent).join('\n\n---\n\n')
      : '没有找到相关文档内容。'

    // Build system message with RAG context
    const systemMessage = `你是一个专业的文档查询助手，使用RAG（检索增强生成）和MCP（模型上下文协议）技术来帮助用户查询和理解文档内容。

可用工具：
${mcpTools.getToolsDescription()}

以下是从文档中检索到的相关内容：
---
${context}
---

请基于以上文档内容回答用户的问题。如果文档中没有相关信息，请明确告知用户。同时，你可以使用MCP工具来增强回答能力。

回答要求：
1. 准确、简洁、专业
2. 引用文档中的具体内容支持你的回答
3. 如果使用了工具，请说明工具的使用结果
4. 用中文回答
5. 如果没有相关文档，就根据你的知识尽力帮助用户`

    // Convert history to message format
    const messages: Array<{ role: string; content: string }> = [
      { role: 'system', content: systemMessage }
    ]

    if (history && Array.isArray(history)) {
      for (const msg of history) {
        if (msg.role === 'user' || msg.role === 'assistant') {
          messages.push({
            role: msg.role === 'user' ? 'user' : 'assistant',
            content: msg.content
          })
        }
      }
    }

    // Add current message
    messages.push({
      role: 'user',
      content: message
    })

    // Use z-ai-web-dev-sdk for LLM (Guest Mode - No API Key)
    let response: string
    try {
      const { createLLMClient } = await import('z-ai-web-dev-sdk')
      const llmClient = createLLMClient()

      const result = await llmClient.chat({
        messages: messages.map(m => ({
          role: m.role as 'system' | 'user' | 'assistant',
          content: m.content
        })),
        model: 'gpt-4o-mini' // Model identifier (will use available model)
      })

      response = result.choices?.[0]?.message?.content || '抱歉，我没有收到有效的响应。'
    } catch (sdkError) {
      console.error('z-ai-web-dev-sdk error:', sdkError)

      // Fallback: Simple rule-based response
      response = generateFallbackResponse(message, relevantDocs)
    }

    // Extract sources
    const sources = relevantDocs.map(doc => {
      const metadata = doc.metadata as any
      return metadata.source || metadata.documentId || '未知来源'
    })

    // Remove duplicates
    const uniqueSources = [...new Set(sources)]

    return NextResponse.json({
      response,
      sources: uniqueSources,
      contextUsed: relevantDocs.length > 0,
      mode: 'guest' // Indicate guest mode
    })
  } catch (error) {
    console.error('Chat error:', error)

    // Return a helpful error message in guest mode
    return NextResponse.json(
      {
        error: '服务暂时不可用',
        response: '抱歉，服务暂时不可用。请稍后再试。',
        sources: [],
        contextUsed: false
      },
      { status: 500 }
    )
  }
}

/**
 * Fallback response generator when SDK is unavailable
 */
function generateFallbackResponse(query: string, relevantDocs: any[]): string {
  if (relevantDocs.length === 0) {
    return `我理解您的问题是："${query}"

抱歉，我没有找到相关的文档内容。作为游客模式，我的功能可能受限。

建议：
1. 先上传相关文档
2. 尝试使用更具体的关键词
3. 如果已有文档，请等待文档处理完成（状态显示为"就绪"）`
  }

  // Build a simple response from relevant documents
  let response = `基于您的问题"${query}"，我找到了以下相关内容：\n\n`

  for (let i = 0; i < Math.min(2, relevantDocs.length); i++) {
    const content = relevantDocs[i].pageContent
    const truncated = content.length > 200 ? content.substring(0, 200) + '...' : content
    response += `[${i + 1}] ${truncated}\n\n`
  }

  response += `注意：这是游客模式，AI 响应可能不够智能。如需更好的体验，请联系管理员配置完整的AI服务。`

  return response
}
