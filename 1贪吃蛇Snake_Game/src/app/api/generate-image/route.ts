import { NextRequest, NextResponse } from 'next/server'
import ZAI from 'z-ai-web-dev-sdk'

// 情感关键词分析
const EMOTION_KEYWORDS = {
  忧伤: {
    tone: '忧郁而深沉',
    colorScheme: '蓝紫色调',
    mood: '宁静而忧伤',
    lighting: '柔和的冷光'
  },
  欢快: {
    tone: '欢快而明媚',
    colorScheme: '暖黄色调',
    mood: '愉悦而明亮',
    lighting: '温暖的阳光'
  },
  宁静: {
    tone: '宁静而平和',
    colorScheme: '青绿色调',
    mood: '平静而安详',
    lighting: '柔和的自然光'
  },
  激昂: {
    tone: '激昂而热烈',
    colorScheme: '红橙色调',
    mood: '热烈而奔放',
    lighting: '明亮而强烈'
  },
  温暖: {
    tone: '温暖而柔和',
    colorScheme: '橙黄色调',
    mood: '温馨而舒适',
    lighting: '温暖的金光'
  },
  浪漫: {
    tone: '浪漫而梦幻',
    colorScheme: '粉紫色调',
    mood: '浪漫而优雅',
    lighting: '柔和的月光'
  }
}

// 意象关键词库
const IMAGERY_KEYWORDS = {
  月亮: '银色的月光、月光倒影、月色朦胧',
  星空: '璀璨星空、银河、繁星点点',
  花朵: '盛开的花朵、花瓣飘落、花香四溢',
  海洋: '浩瀚海洋、海浪拍岸、波光粼粼',
  山川: '连绵山川、群山叠嶂、山峦起伏',
  森林: '茂密森林、绿意盎然、树影婆娑',
  云彩: '流云飘过、云海翻腾、白云悠悠',
  春风: '春风拂面、花草摇曳、生机勃勃',
  秋雨: '秋雨绵绵、落叶飘零、秋意浓浓',
  雪: '白雪皑皑、雪花飘落、银装素裹',
  晨曦: '晨光熹微、朝阳初升、霞光万道',
  晚霞: '晚霞满天、夕阳西下、霞光绚丽'
}

// 风格修饰词
const STYLE_MODIFIERS = [
  '梦幻',
  '写实',
  '抽象',
  '印象派',
  '水彩',
  '油画',
  '唯美',
  '诗意'
]

/**
 * 分析诗歌的情感基调
 */
function analyzeEmotion(poem: string) {
  const poemLower = poem.toLowerCase()

  for (const [emotion, config] of Object.entries(EMOTION_KEYWORDS)) {
    if (poem.includes(emotion) || poemLower.includes(emotion.toLowerCase())) {
      return config
    }
  }

  // 默认返回宁静的情感
  return EMOTION_KEYWORDS.宁静
}

/**
 * 提取诗歌中的关键意象
 */
function extractImagery(poem: string): string[] {
  const foundImagery: string[] = []

  for (const [keyword, description] of Object.entries(IMAGERY_KEYWORDS)) {
    if (poem.includes(keyword)) {
      foundImagery.push(description)
    }
  }

  // 如果没有找到明确的意象，返回一些默认的
  if (foundImagery.length === 0) {
    foundImagery.push('诗意的自然景观', '朦胧的意境', '柔和的光影')
  }

  // 最多返回3个意象
  return foundImagery.slice(0, 3)
}

/**
 * 提取诗歌的核心主题
 */
function extractTheme(poem: string): string {
  // 提取诗歌的前两句作为主题参考
  const lines = poem.split('\n').filter(line => line.trim())
  const firstTwoLines = lines.slice(0, 2).join('，')

  // 简化主题描述
  const theme = firstTwoLines.length > 20
    ? firstTwoLines.substring(0, 20) + '...'
    : firstTwoLines

  return theme
}

/**
 * 构建图像生成提示词
 */
function buildImagePrompt(poem: string): string {
  // 1. 分析情感基调
  const emotion = analyzeEmotion(poem)

  // 2. 提取关键意象
  const imagery = extractImagery(poem)

  // 3. 提取核心主题
  const theme = extractTheme(poem)

  // 4. 随机选择风格修饰词
  const styleModifier = STYLE_MODIFIERS[Math.floor(Math.random() * STYLE_MODIFIERS.length)]

  // 5. 构建完整提示词
  const prompt = `一幅富有诗意的艺术插画，${theme}。

艺术风格：水彩画风格，${styleModifier}，柔和的笔触，梦幻的光影，东方美学元素。

情感基调：
- ${emotion.tone}
- ${emotion.mood}
- ${emotion.lighting}

视觉元素：
${imagery.map(img => `- ${img}`).join('\n')}

色彩方案：
- ${emotion.colorScheme}
- 温暖而柔和的色调
- 诗意化的色彩搭配

构图与细节：
- 诗意化的构图，富有留白艺术
- 空灵的氛围
- 精美的细节处理
- 层次丰富的画面

技术要求：
高清画质，专业插画风格，艺术画廊水准，8K分辨率。`

  return prompt
}

export async function POST(request: NextRequest) {
  try {
    const { poem } = await request.json()

    if (!poem || typeof poem !== 'string') {
      return NextResponse.json(
        { success: false, error: 'Poem is required' },
        { status: 400 }
      )
    }

    const zai = await ZAI.create()

    // 构建智能图像生成提示词
    const imagePrompt = buildImagePrompt(poem)

    // 使用横向尺寸，更适合展示诗歌意境
    const response = await zai.images.generations.create({
      prompt: imagePrompt,
      size: '1344x768' // 横向尺寸
    })

    const imageBase64 = response.data[0]?.base64

    if (!imageBase64) {
      throw new Error('Failed to generate image')
    }

    return NextResponse.json({
      success: true,
      image: `data:image/png;base64,${imageBase64}`,
      prompt: imagePrompt
    })
  } catch (error) {
    console.error('Error generating image:', error)
    return NextResponse.json(
      {
        success: false,
        error: error instanceof Error ? error.message : 'Failed to generate image'
      },
      { status: 500 }
    )
  }
}
