/**
 * 单词分类和稀有度系统
 * 用于诗意贪吃蛇游戏的食物生成
 */

// 单词分类
export const WORD_CATEGORIES = {
  自然: ['星空', '月光', '晨曦', '晚霞', '春风', '秋雨', '山川', '河流', '大海', '森林', '晨雾', '云海'],
  情感: ['思念', '温暖', '希望', '梦想', '勇气', '温柔', '孤独', '自由', '友谊', '爱情', '期待', '憧憬'],
  时间: ['岁月', '时光', '瞬间', '永恒', '昨天', '明天', '黎明', '黄昏', '往事', '未来', '刹那', '永恒'],
  抽象: ['理想', '信念', '智慧', '灵感', '奇迹', '宿命', '缘分', '回忆', '幻想', '憧憬', '诗意', '远方'],
  意象: ['荷花', '梅花', '竹影', '松涛', '流水', '落花', '飞雪', '流云', '寒霜', '暖阳', '彩虹', '露珠']
} as const;

// 稀有度定义
export const RARITY = {
  COMMON: {
    key: 'COMMON',
    name: '普通',
    color: '#10b981', // 绿色
    size: 1,
    points: 10,
    probability: 0.70,
    stars: 0
  },
  RARE: {
    key: 'RARE',
    name: '稀有',
    color: '#8b5cf6', // 紫色
    size: 1.2,
    points: 20,
    probability: 0.25,
    stars: 1
  },
  EPIC: {
    key: 'EPIC',
    name: '史诗',
    color: '#f59e0b', // 橙色
    size: 1.4,
    points: 30,
    probability: 0.04,
    stars: 2
  },
  LEGENDARY: {
    key: 'LEGENDARY',
    name: '传说',
    color: '#ef4444', // 红色
    size: 1.6,
    points: 50,
    probability: 0.01,
    stars: 3
  }
} as const;

// 稀有度类型
export type RarityType = keyof typeof RARITY;

// 收集的单词接口
export interface CollectedWord {
  id: number;
  word: string;
  rarity: RarityType;
  category: string;
  points: number;
  timestamp: number;
}

// 食物接口
export interface WordFood {
  word: string;
  rarity: RarityType;
  category: string;
  points: number;
  x: number;
  y: number;
}

// 随机生成单词（带稀有度）
export function generateRandomWord(): WordFood {
  // 1. 根据概率选择稀有度
  const rarity = selectRarity();

  // 2. 从对应稀有度的单词池中选择单词
  const categories = Object.keys(WORD_CATEGORIES);
  const randomCategory = categories[Math.floor(Math.random() * categories.length)];
  const words = WORD_CATEGORIES[randomCategory as keyof typeof WORD_CATEGORIES];
  const word = words[Math.floor(Math.random() * words.length)];

  return {
    word,
    rarity,
    category: randomCategory,
    points: RARITY[rarity].points,
    x: 0, // 将在游戏逻辑中设置
    y: 0  // 将在游戏逻辑中设置
  };
}

// 根据概率选择稀有度
function selectRarity(): RarityType {
  const random = Math.random();
  let cumulative = 0;

  for (const [key, config] of Object.entries(RARITY)) {
    cumulative += config.probability;
    if (random < cumulative) {
      return key as RarityType;
    }
  }

  return 'COMMON';
}

// 获取所有单词的扁平数组
export function getAllWords(): string[] {
  const allWords: string[] = [];
  for (const category of Object.values(WORD_CATEGORIES)) {
    allWords.push(...category);
  }
  return allWords;
}

// 获取稀有度配置
export function getRarityConfig(rarity: RarityType) {
  return RARITY[rarity];
}

// 根据稀有度获取星星字符串
export function getRarityStars(rarity: RarityType): string {
  const config = getRarityConfig(rarity);
  return '★'.repeat(config.stars);
}
