import { NextRequest, NextResponse } from 'next/server'
import ZAI from 'z-ai-web-dev-sdk'

// 诗歌风格定义
const POETRY_STYLES = [
  {
    id: 'philosophical',
    name: '深情而哲思',
    description: '充满哲理思辨，语言深沉而有深度',
    systemPrompt: `你是一位哲学诗人，擅长用深邃的语言探索人生的意义和价值。

风格特点：
- 语言深沉，富有哲理性
- 探讨生命、时间、存在等深刻主题
- 使用隐喻和象征表达思想
- 情感真挚而克制
- 富有思辨性和启发性

请用这种风格创作诗歌，确保：
1. 风格明显不同，充满哲理思辨
2. 情感基调深沉而有深度
3. 语言表达富有哲学意味
4. 依然融入所有给定的词语
5. 保持诗歌的美感和思想性`
  },
  {
    id: 'romantic',
    name: '轻快而浪漫',
    description: '轻松愉悦，充满浪漫情调',
    systemPrompt: `你是一位浪漫诗人，擅长创作轻快愉悦、充满情调的诗歌。

风格特点：
- 语言轻快流畅，节奏明快
- 充满浪漫情怀和美好想象
- 温柔而富有诗意
- 营造轻松愉快的氛围
- 富有画面感和情感美

请用这种风格创作诗歌，确保：
1. 风格明显不同，轻快而浪漫
2. 情感基调愉悦而温柔
3. 语言表达富有浪漫情调
4. 依然融入所有给定的词语
5. 保持诗歌的美感和韵律`
  },
  {
    id: 'epic',
    name: '宏大而壮阔',
    description: '气势磅礴，意境宏大',
    systemPrompt: `你是一位史诗诗人，擅长创作气势磅礴、意境宏大的诗歌。

风格特点：
- 语言雄浑有力，气势磅礴
- 意象宏大，画面壮丽
- 节奏铿锵有力
- 充满力量感和震撼力
- 富有史诗般的壮阔

请用这种风格创作诗歌，确保：
1. 风格明显不同，宏大而壮阔
2. 情感基调激昂有力
3. 语言表达富有史诗感
4. 依然融入所有给定的词语
5. 保持诗歌的气势和美感`
  },
  {
    id: 'gentle',
    name: '细腻而温婉',
    description: '温柔细腻，情感婉约',
    systemPrompt: `你是一位婉约诗人，擅长创作温柔细腻、情感婉约的诗歌。

风格特点：
- 语言细腻精致，情感丰富
- 温婉而含蓄，意蕴悠长
- 细腻入微的描写
- 情感真挚而温柔
- 富有东方美学韵味

请用这种风格创作诗歌，确保：
1. 风格明显不同，细腻而温婉
2. 情感基调温柔含蓄
3. 语言表达富有婉约美
4. 依然融入所有给定的词语
5. 保持诗歌的细腻和诗意`
  },
  {
    id: 'dreamy',
    name: '梦幻而抽象',
    description: '充满想象，意境梦幻',
    systemPrompt: `你是一位梦幻诗人，擅长创作充满想象、意境梦幻的诗歌。

风格特点：
- 语言富有想象力，超现实
- 意境梦幻，如梦似幻
- 使用抽象意象和联想
- 营造神秘而梦幻的氛围
- 充满创意和奇思妙想

请用这种风格创作诗歌，确保：
1. 风格明显不同，梦幻而抽象
2. 情感基调神秘梦幻
3. 语言表达富有想象力
4. 依然融入所有给定的词语
5. 保持诗歌的梦幻和创意`
  },
  {
    id: 'concise',
    name: '简洁而有力',
    description: '语言简练，直击人心',
    systemPrompt: `你是一位简约诗人，擅长创作语言简练、直击人心的诗歌。

风格特点：
- 语言简洁有力，不冗余
- 直击内心，富有感染力
- 节奏明快，一针见血
- 情感真挚而直接
- 富有力量和共鸣

请用这种风格创作诗歌，确保：
1. 风格明显不同，简洁而有力
2. 情感基调直接而有力
3. 语言表达简洁明快
4. 依然融入所有给定的词语
5. 保持诗歌的简洁和力量`
  }
]

// 基础系统提示词
const BASE_SYSTEM_PROMPT = `你是一位多才多艺的诗人，能够用不同的风格重新诠释同一组词语。

你拥有多种创作风格，每种风格都有其独特的魅力和特点。
你需要根据当前指定的风格，用全新的角度和表达方式创作诗歌。

请始终保持：
1. 高水准的诗歌质量
2. 自然地融入所有给定的词语
3. 符合指定风格的特点
4. 富有美感和感染力
5. 直接输出诗歌，不要包含任何标题、说明或额外文字`

export async function POST(request: NextRequest) {
  try {
    const { words, previousPoem, styleId } = await request.json()

    if (!words || !Array.isArray(words) || words.length === 0) {
      return NextResponse.json(
        { success: false, error: 'Words array is required' },
        { status: 400 }
      )
    }

    const zai = await ZAI.create()

    // 随机选择一个风格，或者使用指定的风格
    let selectedStyle
    if (styleId) {
      selectedStyle = POETRY_STYLES.find(s => s.id === styleId)
    }
    
    if (!selectedStyle) {
      // 随机选择一个风格
      const randomIndex = Math.floor(Math.random() * POETRY_STYLES.length)
      selectedStyle = POETRY_STYLES[randomIndex]
    }

    // 构建系统提示词
    const systemPrompt = `${BASE_SYSTEM_PROMPT}

${selectedStyle.systemPrompt}`

    // 构建词语列表
    const wordsString = words.join('、')

    // 构建用户提示词
    let userPrompt = `请使用以下词语，以【${selectedStyle.name}】风格创作一首新的现代诗歌：

词语列表：${wordsString}`

    // 如果有之前的诗歌，作为参考
    if (previousPoem) {
      userPrompt += `

之前创作的诗歌（作为参考，请创作风格完全不同的新版本）：
${previousPoem}`
    }

    userPrompt += `

请开始创作：`

    const completion = await zai.chat.completions.create({
      messages: [
        {
          role: 'assistant',
          content: systemPrompt
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
      throw new Error('Failed to remix poem')
    }

    return NextResponse.json({
      success: true,
      poem: poem,
      style: selectedStyle.name,
      styleId: selectedStyle.id
    })
  } catch (error) {
    console.error('Error remixing poem:', error)
    return NextResponse.json(
      {
        success: false,
        error: error instanceof Error ? error.message : 'Failed to remix poem'
      },
      { status: 500 }
    )
  }
}
