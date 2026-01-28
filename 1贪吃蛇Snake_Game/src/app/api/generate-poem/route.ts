import { NextRequest, NextResponse } from 'next/server'
import ZAI from 'z-ai-web-dev-sdk'

// 系统提示词
const SYSTEM_PROMPT = `你是一位杰出的现代诗人，擅长将零散的词语编织成优美的诗歌。

你的创作风格：
- 语言优美而凝练
- 意象丰富，画面感强
- 情感真挚，富有感染力
- 结构完整，韵律和谐
- 富有哲理和深度

创作要求：
1. 必须自然地融入所有给定的词语
2. 诗歌应该像一段完整的叙述或抒情
3. 每行字数适中（6-12字）
4. 整体长度8-14行
5. 语言要富有诗意，避免大白话
6. 可以选择自由诗或有韵律的诗体
7. 情感基调要与词语的整体氛围匹配
8. 创作时要大胆想象，不要拘泥于传统
9. 直接输出诗歌内容，不要包含任何标题、说明或额外文字`

export async function POST(request: NextRequest) {
  try {
    const { words } = await request.json()

    if (!words || !Array.isArray(words) || words.length === 0) {
      return NextResponse.json(
        { success: false, error: 'Words array is required' },
        { status: 400 }
      )
    }

    const zai = await ZAI.create()

    // 构建词语列表
    const wordsString = words.join('、')

    // 用户提示词
    const userPrompt = `请使用以下词语创作一首现代诗歌：

词语列表：${wordsString}

请开始创作：`

    const completion = await zai.chat.completions.create({
      messages: [
        {
          role: 'assistant',
          content: SYSTEM_PROMPT
        },
        {
          role: 'user',
          content: userPrompt
        }
      ],
      thinking: { type: 'disabled' }
    })

    const poem = completion.choices[0]?.message?.content

    if (!poem) {
      throw new Error('Failed to generate poem')
    }

    return NextResponse.json({
      success: true,
      poem: poem
    })
  } catch (error) {
    console.error('Error generating poem:', error)
    return NextResponse.json(
      {
        success: false,
        error: error instanceof Error ? error.message : 'Failed to generate poem'
      },
      { status: 500 }
    )
  }
}
