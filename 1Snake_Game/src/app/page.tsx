'use client'

import { useState, useEffect, useRef, useCallback } from 'react'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Progress } from '@/components/ui/progress'
import { Badge } from '@/components/ui/badge'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { Play, Pause, RotateCcw, RefreshCw, Image as ImageIcon, BookOpen, Star, Volume2, VolumeX, Trophy } from 'lucide-react'
import { WordFood, CollectedWord, generateRandomWord, getRarityConfig, getRarityStars, type RarityType } from '@/lib/wordSystem'

type Direction = 'UP' | 'DOWN' | 'LEFT' | 'RIGHT'

interface Position {
  x: number
  y: number
}

const GRID_SIZE = 20
const CELL_SIZE = 25
const INITIAL_SPEED = 200
const MIN_SPEED = 80
const TARGET_WORDS = 8

export default function SnakeGame() {
  // 游戏状态
  const [snake, setSnake] = useState<Position[]>([{ x: 10, y: 10 }])
  const [direction, setDirection] = useState<Direction>('RIGHT')
  const [nextDirection, setNextDirection] = useState<Direction>('RIGHT')
  const [food, setFood] = useState<WordFood | null>(null)
  const [collectedWords, setCollectedWords] = useState<CollectedWord[]>([])
  
  // 游戏控制
  const [isPlaying, setIsPlaying] = useState(false)
  const [isPaused, setIsPaused] = useState(false)
  const [gameOver, setGameOver] = useState(false)
  
  // 游戏数据
  const [score, setScore] = useState(0)
  const [level, setLevel] = useState(1)
  const [speed, setSpeed] = useState(INITIAL_SPEED)
  
  // AI生成状态
  const [poem, setPoem] = useState('')
  const [isGeneratingPoem, setIsGeneratingPoem] = useState(false)
  const [isGeneratingImage, setIsGeneratingImage] = useState(false)
  const [generatedImage, setGeneratedImage] = useState<string | null>(null)
  const [showPoemAndImage, setShowPoemAndImage] = useState(false)
  const [currentStyle, setCurrentStyle] = useState('')
  
  // 游戏时间
  const [gameTime, setGameTime] = useState(0)
  
  // 最高分
  const [highScore, setHighScore] = useState(0)
  
  const gameLoopRef = useRef<NodeJS.Timeout | null>(null)
  const timerRef = useRef<NodeJS.Timeout | null>(null)
  const canvasRef = useRef<HTMLCanvasElement>(null)

  // 从localStorage加载最高分
  useEffect(() => {
    const savedHighScore = localStorage.getItem('snakeGameHighScore')
    if (savedHighScore) {
      setHighScore(parseInt(savedHighScore, 10))
    }
  }, [])

  // 保存最高分
  useEffect(() => {
    if (score > highScore) {
      setHighScore(score)
      localStorage.setItem('snakeGameHighScore', score.toString())
    }
  }, [score, highScore])

  // 游戏计时器
  useEffect(() => {
    if (isPlaying && !isPaused && !gameOver) {
      timerRef.current = setInterval(() => {
        setGameTime(prev => prev + 1)
      }, 1000)
      return () => {
        if (timerRef.current) clearInterval(timerRef.current)
      }
    }
  }, [isPlaying, isPaused, gameOver])

  // 格式化时间
  const formatTime = (seconds: number) => {
    const mins = Math.floor(seconds / 60)
    const secs = seconds % 60
    return `${mins}:${secs.toString().padStart(2, '0')}`
  }

  // 生成随机食物位置
  const generateRandomFoodPosition = useCallback((snake: Position[]): Position => {
    let newPosition: Position
    let isValid = false

    do {
      newPosition = {
        x: Math.floor(Math.random() * GRID_SIZE),
        y: Math.floor(Math.random() * GRID_SIZE)
      }

      // 检查是否在蛇身上
      isValid = !snake.some(segment => segment.x === newPosition.x && segment.y === newPosition.y)
    } while (!isValid)

    return newPosition
  }, [])

  // 初始化食物
  useEffect(() => {
    if (!food) {
      const wordData = generateRandomWord()
      const position = generateRandomFoodPosition(snake)
      setFood({
        ...wordData,
        x: position.x,
        y: position.y
      })
    }
  }, [food, snake, generateRandomFoodPosition])

  // 更新速度
  const updateSpeed = useCallback((foodCount: number) => {
    const newLevel = Math.floor(foodCount / 5) + 1
    setLevel(newLevel)

    const speedIncrease = Math.min(0.1 * newLevel, 0.6) // 最多增加60%
    const newSpeed = Math.max(INITIAL_SPEED * (1 - speedIncrease), MIN_SPEED)
    setSpeed(newSpeed)
  }, [])

  // 游戏循环
  useEffect(() => {
    if (!isPlaying || isPaused || gameOver) return

    gameLoopRef.current = setInterval(() => {
      setSnake(prevSnake => {
        const head = { ...prevSnake[0] }

        setDirection(nextDirection)

        switch (nextDirection) {
          case 'UP':
            head.y -= 1
            break
          case 'DOWN':
            head.y += 1
            break
          case 'LEFT':
            head.x -= 1
            break
          case 'RIGHT':
            head.x += 1
            break
        }

        // 检查墙壁碰撞
        if (head.x < 0 || head.x >= GRID_SIZE || head.y < 0 || head.y >= GRID_SIZE) {
          setGameOver(true)
          setIsPlaying(false)
          return prevSnake
        }

        // 检查自身碰撞
        if (prevSnake.some(pos => pos.x === head.x && pos.y === head.y)) {
          setGameOver(true)
          setIsPlaying(false)
          return prevSnake
        }

        const newSnake = [head, ...prevSnake]

        // 检查是否吃到食物
        if (food && head.x === food.x && head.y === food.y) {
          const points = food.points
          setScore(prev => prev + points)
          
          const newWord: CollectedWord = {
            id: collectedWords.length + 1,
            word: food.word,
            rarity: food.rarity,
            category: food.category,
            points: food.points,
            timestamp: Date.now()
          }
          
          const newCollectedWords = [...collectedWords, newWord]
          setCollectedWords(newCollectedWords)
          
          // 更新速度
          updateSpeed(newCollectedWords.length)
          
          // 生成新食物
          const wordData = generateRandomWord()
          const position = generateRandomFoodPosition(newSnake)
          setFood({
            ...wordData,
            x: position.x,
            y: position.y
          })
        } else {
          newSnake.pop()
        }

        return newSnake
      })
    }, speed)

    return () => {
      if (gameLoopRef.current) {
        clearInterval(gameLoopRef.current)
      }
    }
  }, [isPlaying, isPaused, gameOver, nextDirection, food, speed, collectedWords, generateRandomFoodPosition, updateSpeed])

  // 检查是否收集到目标单词数量
  useEffect(() => {
    if (collectedWords.length >= TARGET_WORDS && !poem) {
      setIsPlaying(false)
      setIsPaused(true)
      generatePoem()
    }
  }, [collectedWords, poem])

  // 绘制游戏
  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return

    const ctx = canvas.getContext('2d')
    if (!ctx) return

    // 清空画布
    ctx.fillStyle = '#fafafa'
    ctx.fillRect(0, 0, canvas.width, canvas.height)

    // 绘制网格
    ctx.strokeStyle = '#e5e7eb'
    ctx.lineWidth = 0.5
    for (let i = 0; i <= GRID_SIZE; i++) {
      ctx.beginPath()
      ctx.moveTo(i * CELL_SIZE, 0)
      ctx.lineTo(i * CELL_SIZE, canvas.height)
      ctx.stroke()

      ctx.beginPath()
      ctx.moveTo(0, i * CELL_SIZE)
      ctx.lineTo(canvas.width, i * CELL_SIZE)
      ctx.stroke()
    }

    // 绘制蛇
    snake.forEach((segment, index) => {
      const isHead = index === 0
      
      // 渐变色
      const gradient = ctx.createLinearGradient(
        segment.x * CELL_SIZE,
        segment.y * CELL_SIZE,
        segment.x * CELL_SIZE + CELL_SIZE,
        segment.y * CELL_SIZE + CELL_SIZE
      )
      
      if (isHead) {
        gradient.addColorStop(0, '#166534')
        gradient.addColorStop(1, '#15803d')
      } else {
        const intensity = 1 - (index / snake.length) * 0.5
        gradient.addColorStop(0, `rgba(34, 197, 94, ${intensity})`)
        gradient.addColorStop(1, `rgba(134, 239, 172, ${intensity})`)
      }

      ctx.fillStyle = gradient
      ctx.beginPath()
      ctx.roundRect(
        segment.x * CELL_SIZE + 1,
        segment.y * CELL_SIZE + 1,
        CELL_SIZE - 2,
        CELL_SIZE - 2,
        4
      )
      ctx.fill()

      // 蛇头眼睛
      if (isHead) {
        ctx.fillStyle = '#ffffff'
        const eyeOffset = 6
        const eyeSize = 3
        
        switch (direction) {
          case 'RIGHT':
            ctx.beginPath()
            ctx.arc(segment.x * CELL_SIZE + CELL_SIZE - eyeOffset, segment.y * CELL_SIZE + 8, eyeSize, 0, Math.PI * 2)
            ctx.arc(segment.x * CELL_SIZE + CELL_SIZE - eyeOffset, segment.y * CELL_SIZE + CELL_SIZE - 8, eyeSize, 0, Math.PI * 2)
            ctx.fill()
            break
          case 'LEFT':
            ctx.beginPath()
            ctx.arc(segment.x * CELL_SIZE + eyeOffset, segment.y * CELL_SIZE + 8, eyeSize, 0, Math.PI * 2)
            ctx.arc(segment.x * CELL_SIZE + eyeOffset, segment.y * CELL_SIZE + CELL_SIZE - 8, eyeSize, 0, Math.PI * 2)
            ctx.fill()
            break
          case 'UP':
            ctx.beginPath()
            ctx.arc(segment.x * CELL_SIZE + 8, segment.y * CELL_SIZE + eyeOffset, eyeSize, 0, Math.PI * 2)
            ctx.arc(segment.x * CELL_SIZE + CELL_SIZE - 8, segment.y * CELL_SIZE + eyeOffset, eyeSize, 0, Math.PI * 2)
            ctx.fill()
            break
          case 'DOWN':
            ctx.beginPath()
            ctx.arc(segment.x * CELL_SIZE + 8, segment.y * CELL_SIZE + CELL_SIZE - eyeOffset, eyeSize, 0, Math.PI * 2)
            ctx.arc(segment.x * CELL_SIZE + CELL_SIZE - 8, segment.y * CELL_SIZE + CELL_SIZE - eyeOffset, eyeSize, 0, Math.PI * 2)
            ctx.fill()
            break
        }
        
        // 瞳孔
        ctx.fillStyle = '#000000'
        const pupilOffset = 2
        switch (direction) {
          case 'RIGHT':
            ctx.beginPath()
            ctx.arc(segment.x * CELL_SIZE + CELL_SIZE - eyeOffset + pupilOffset, segment.y * CELL_SIZE + 8, eyeSize / 2, 0, Math.PI * 2)
            ctx.arc(segment.x * CELL_SIZE + CELL_SIZE - eyeOffset + pupilOffset, segment.y * CELL_SIZE + CELL_SIZE - 8, eyeSize / 2, 0, Math.PI * 2)
            ctx.fill()
            break
          case 'LEFT':
            ctx.beginPath()
            ctx.arc(segment.x * CELL_SIZE + eyeOffset - pupilOffset, segment.y * CELL_SIZE + 8, eyeSize / 2, 0, Math.PI * 2)
            ctx.arc(segment.x * CELL_SIZE + eyeOffset - pupilOffset, segment.y * CELL_SIZE + CELL_SIZE - 8, eyeSize / 2, 0, Math.PI * 2)
            ctx.fill()
            break
          case 'UP':
            ctx.beginPath()
            ctx.arc(segment.x * CELL_SIZE + 8, segment.y * CELL_SIZE + eyeOffset - pupilOffset, eyeSize / 2, 0, Math.PI * 2)
            ctx.arc(segment.x * CELL_SIZE + CELL_SIZE - 8, segment.y * CELL_SIZE + eyeOffset - pupilOffset, eyeSize / 2, 0, Math.PI * 2)
            ctx.fill()
            break
          case 'DOWN':
            ctx.beginPath()
            ctx.arc(segment.x * CELL_SIZE + 8, segment.y * CELL_SIZE + CELL_SIZE - eyeOffset + pupilOffset, eyeSize / 2, 0, Math.PI * 2)
            ctx.arc(segment.x * CELL_SIZE + CELL_SIZE - 8, segment.y * CELL_SIZE + CELL_SIZE - eyeOffset + pupilOffset, eyeSize / 2, 0, Math.PI * 2)
            ctx.fill()
            break
        }
      }
    })

    // 绘制食物（单词）
    if (food) {
      const rarityConfig = getRarityConfig(food.rarity)
      const sizeMultiplier = rarityConfig.size
      const radius = (CELL_SIZE / 2 - 2) * sizeMultiplier

      // 食物背景（圆形）
      ctx.fillStyle = rarityConfig.color
      ctx.beginPath()
      ctx.arc(
        food.x * CELL_SIZE + CELL_SIZE / 2,
        food.y * CELL_SIZE + CELL_SIZE / 2,
        radius,
        0,
        Math.PI * 2
      )
      ctx.fill()

      // 传说级食物发光效果
      if (food.rarity === 'LEGENDARY') {
        ctx.strokeStyle = 'rgba(239, 68, 68, 0.3)'
        ctx.lineWidth = 4
        ctx.beginPath()
        ctx.arc(
          food.x * CELL_SIZE + CELL_SIZE / 2,
          food.y * CELL_SIZE + CELL_SIZE / 2,
          radius + 3,
          0,
          Math.PI * 2
        )
        ctx.stroke()
      }

      // 食物文字
      ctx.fillStyle = '#ffffff'
      ctx.font = `bold ${10 * sizeMultiplier}px "PingFang SC", "Microsoft YaHei", sans-serif`
      ctx.textAlign = 'center'
      ctx.textBaseline = 'middle'
      ctx.fillText(
        food.word,
        food.x * CELL_SIZE + CELL_SIZE / 2,
        food.y * CELL_SIZE + CELL_SIZE / 2
      )
    }
  }, [snake, food, direction])

  // 键盘控制
  useEffect(() => {
    const handleKeyPress = (e: KeyboardEvent) => {
      if (e.key === ' ' || e.code === 'Space') {
        e.preventDefault()
        if (isPlaying && !gameOver) {
          setIsPaused(prev => !prev)
        } else if (!isPlaying && !gameOver && collectedWords.length < TARGET_WORDS) {
          startGame()
        }
        return
      }

      switch (e.key) {
        case 'ArrowUp':
        case 'w':
        case 'W':
          if (direction !== 'DOWN') setNextDirection('UP')
          break
        case 'ArrowDown':
        case 's':
        case 'S':
          if (direction !== 'UP') setNextDirection('DOWN')
          break
        case 'ArrowLeft':
        case 'a':
        case 'A':
          if (direction !== 'RIGHT') setNextDirection('LEFT')
          break
        case 'ArrowRight':
        case 'd':
        case 'D':
          if (direction !== 'LEFT') setNextDirection('RIGHT')
          break
      }
    }

    window.addEventListener('keydown', handleKeyPress)
    return () => window.removeEventListener('keydown', handleKeyPress)
  }, [direction, isPlaying, gameOver, collectedWords.length])

  // 生成诗歌
  const generatePoem = async () => {
    setIsGeneratingPoem(true)
    try {
      const words = collectedWords.map(w => w.word)
      const response = await fetch('/api/generate-poem', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ words })
      })
      const data = await response.json()
      if (data.success) {
        setPoem(data.poem)
        setShowPoemAndImage(true)
      }
    } catch (error) {
      console.error('Failed to generate poem:', error)
    } finally {
      setIsGeneratingPoem(false)
    }
  }

  // 重新混合诗歌
  const remixPoem = async () => {
    setIsGeneratingPoem(true)
    try {
      const words = collectedWords.map(w => w.word)
      const response = await fetch('/api/remix-poem', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ 
          words,
          previousPoem: poem 
        })
      })
      const data = await response.json()
      if (data.success) {
        setPoem(data.poem)
        setCurrentStyle(data.style || '')
      }
    } catch (error) {
      console.error('Failed to remix poem:', error)
    } finally {
      setIsGeneratingPoem(false)
    }
  }

  // 生成图像
  const generateImage = async () => {
    setIsGeneratingImage(true)
    try {
      const response = await fetch('/api/generate-image', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ poem })
      })
      const data = await response.json()
      if (data.success && data.image) {
        setGeneratedImage(data.image)
      }
    } catch (error) {
      console.error('Failed to generate image:', error)
    } finally {
      setIsGeneratingImage(false)
    }
  }

  // 当诗歌生成后，自动生成图像
  useEffect(() => {
    if (poem && !generatedImage && !isGeneratingImage) {
      generateImage()
    }
  }, [poem])

  // 开始游戏
  const startGame = () => {
    const initialSnake = [{ x: 10, y: 10 }]
    setSnake(initialSnake)
    setDirection('RIGHT')
    setNextDirection('RIGHT')
    setCollectedWords([])
    setGameOver(false)
    setPoem('')
    setGeneratedImage(null)
    setShowPoemAndImage(false)
    setScore(0)
    setLevel(1)
    setSpeed(INITIAL_SPEED)
    setGameTime(0)
    setCurrentStyle('')
    
    const wordData = generateRandomWord()
    const position = generateRandomFoodPosition(initialSnake)
    setFood({
      ...wordData,
      x: position.x,
      y: position.y
    })
    
    setIsPlaying(true)
    setIsPaused(false)
  }

  // 切换暂停
  const togglePause = () => {
    if (isPlaying && !gameOver) {
      setIsPaused(prev => !prev)
    }
  }

  // 重置游戏
  const resetGame = () => {
    setSnake([{ x: 10, y: 10 }])
    setDirection('RIGHT')
    setNextDirection('RIGHT')
    setCollectedWords([])
    setGameOver(false)
    setPoem('')
    setGeneratedImage(null)
    setShowPoemAndImage(false)
    setScore(0)
    setLevel(1)
    setSpeed(INITIAL_SPEED)
    setGameTime(0)
    setCurrentStyle('')
    
    const wordData = generateRandomWord()
    const position = generateRandomFoodPosition([{ x: 10, y: 10 }])
    setFood({
      ...wordData,
      x: position.x,
      y: position.y
    })
    
    setIsPlaying(false)
    setIsPaused(false)
  }

  // 计算总进度
  const progress = (collectedWords.length / TARGET_WORDS) * 100

  // 计算总得分
  const totalScore = collectedWords.reduce((sum, word) => sum + word.points, 0)

  return (
    <div className="min-h-screen bg-gradient-to-br from-green-50 via-green-50/50 to-yellow-50/30 p-4 md:p-8">
      <div className="max-w-7xl mx-auto">
        {/* 页面头部 */}
        <div className="text-center mb-8">
          <h1 className="text-4xl md:text-5xl font-bold text-gray-800 mb-2">
            🐍 诗意贪吃蛇
          </h1>
          <p className="text-gray-600 text-sm md:text-base">
            控制蛇收集诗意单词，AI将为您创作诗歌与艺术图像
          </p>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* 左侧 - 游戏区域 */}
          <div className="lg:col-span-2 space-y-6">
            {/* 游戏卡片 */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center justify-between">
                  <span>🎮 游戏区域</span>
                  <div className="flex items-center gap-4 text-sm">
                    <span className="text-yellow-600 font-bold flex items-center gap-1">
                      <Trophy className="w-4 h-4" />
                      {score}分
                    </span>
                    <span className="text-gray-600">
                      Lv.{level}
                    </span>
                  </div>
                </CardTitle>
                <CardDescription>
                  使用方向键或WASD控制移动，空格键暂停/继续
                </CardDescription>
              </CardHeader>
              <CardContent>
                <div className="flex flex-col items-center gap-4">
                  {/* 游戏画布 */}
                  <div className="border-4 border-gray-300 rounded-lg shadow-lg bg-white relative">
                    <canvas
                      ref={canvasRef}
                      width={GRID_SIZE * CELL_SIZE}
                      height={GRID_SIZE * CELL_SIZE}
                      className="block"
                    />
                    {isPaused && isPlaying && (
                      <div className="absolute inset-0 bg-black/50 flex items-center justify-center rounded">
                        <div className="text-white text-2xl font-bold">已暂停</div>
                      </div>
                    )}
                  </div>

                  {/* 游戏控制 */}
                  <div className="flex gap-3 flex-wrap justify-center">
                    {!isPlaying && !gameOver && (
                      <Button onClick={startGame} size="lg" className="bg-green-600 hover:bg-green-700">
                        <Play className="w-4 h-4 mr-2" />
                        开始游戏
                      </Button>
                    )}
                    {gameOver && (
                      <>
                        <Button onClick={startGame} size="lg" className="bg-green-600 hover:bg-green-700">
                          <Play className="w-4 h-4 mr-2" />
                          再玩一次
                        </Button>
                        <Button onClick={resetGame} size="lg" variant="outline">
                          <RotateCcw className="w-4 h-4 mr-2" />
                          重置
                        </Button>
                      </>
                    )}
                    {isPlaying && !gameOver && (
                      <>
                        <Button onClick={togglePause} size="lg" variant="outline">
                          {isPaused ? <Play className="w-4 h-4 mr-2" /> : <Pause className="w-4 h-4 mr-2" />}
                          {isPaused ? '继续' : '暂停'}
                        </Button>
                        <Button onClick={resetGame} size="lg" variant="outline">
                          <RotateCcw className="w-4 h-4 mr-2" />
                          重置
                        </Button>
                      </>
                    )}
                  </div>

                  {/* 游戏状态信息 */}
                  <div className="flex gap-6 text-sm text-gray-600 justify-center">
                    <span>时间: {formatTime(gameTime)}</span>
                    <span>速度: {speed}ms/格</span>
                    <span>最高分: {highScore}</span>
                  </div>

                  {/* 游戏结束提示 */}
                  {gameOver && (
                    <Alert variant="destructive">
                      <AlertDescription>
                        游戏结束！蛇撞到了墙壁或自己。得分: {score}
                      </AlertDescription>
                    </Alert>
                  )}
                </div>
              </CardContent>
            </Card>

            {/* 创作展示区域 */}
            {showPoemAndImage && (
              <Card>
                <CardHeader>
                  <CardTitle className="flex items-center gap-2">
                    <BookOpen className="w-5 h-5" />
                    AI创作成果
                  </CardTitle>
                </CardHeader>
                <CardContent className="space-y-6">
                  {/* 诗歌展示 */}
                  <div>
                    <div className="flex items-center justify-between mb-3">
                      <h3 className="text-lg font-semibold text-gray-800 flex items-center gap-2">
                        📝 AI创作的诗歌
                      </h3>
                      {currentStyle && (
                        <Badge variant="outline" className="text-purple-600 border-purple-300">
                          {currentStyle}
                        </Badge>
                      )}
                      <Button
                        onClick={remixPoem}
                        disabled={isGeneratingPoem || isGeneratingImage}
                        size="sm"
                        variant="outline"
                      >
                        <RefreshCw className={`w-4 h-4 mr-2 ${isGeneratingPoem ? 'animate-spin' : ''}`} />
                        重新混合
                      </Button>
                    </div>
                    {isGeneratingPoem ? (
                      <div className="bg-gradient-to-br from-purple-50 to-pink-50 border-2 border-purple-200 rounded-lg p-8 text-center">
                        <div className="text-4xl mb-4">✨</div>
                        <p className="text-purple-600 text-lg">AI正在挥毫泼墨...</p>
                        <p className="text-purple-400 text-sm mt-2">创作需要一些时间，请稍候</p>
                      </div>
                    ) : (
                      <div className="bg-gradient-to-br from-purple-50 via-pink-50 to-purple-50 border-2 border-purple-200 rounded-lg p-8">
                        <p className="text-gray-800 leading-loose text-center whitespace-pre-wrap font-serif text-lg">
                          {poem}
                        </p>
                      </div>
                    )}
                  </div>

                  {/* 图像展示 */}
                  <div>
                    <h3 className="text-lg font-semibold text-gray-800 mb-3">
                      <ImageIcon className="w-5 h-5 inline mr-1" />
                      AI生成的艺术图像
                    </h3>
                    {isGeneratingImage ? (
                      <div className="bg-gradient-to-br from-blue-50 to-cyan-50 border-2 border-blue-200 rounded-lg p-8 text-center">
                        <div className="text-4xl mb-4">🎨</div>
                        <p className="text-blue-600 text-lg">AI正在创作艺术图像...</p>
                        <p className="text-blue-400 text-sm mt-2">根据诗歌意境生成画面</p>
                      </div>
                    ) : generatedImage ? (
                      <div className="bg-gradient-to-br from-blue-50 via-cyan-50 to-blue-50 border-2 border-blue-200 rounded-lg p-6">
                        <img
                          src={generatedImage}
                          alt="AI生成的艺术图像"
                          className="w-full rounded-lg shadow-xl"
                        />
                        <p className="text-center text-gray-600 mt-4 text-sm">
                          基于诗歌意境创作
                        </p>
                      </div>
                    ) : null}
                  </div>
                </CardContent>
              </Card>
            )}
          </div>

          {/* 右侧 - 侧边栏 */}
          <div className="space-y-6">
            {/* 进度卡片 */}
            <Card>
              <CardHeader>
                <CardTitle>收集进度</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="space-y-4">
                  <Progress value={progress} className="h-3" />
                  <div className="flex justify-between items-center">
                    <span className="text-3xl font-bold text-gray-800">
                      {collectedWords.length}
                      <span className="text-gray-500 text-xl"> / {TARGET_WORDS}</span>
                    </span>
                    <Badge variant="secondary" className="text-sm px-3 py-1">
                      {collectedWords.length >= TARGET_WORDS ? '✓ 完成' : '进行中'}
                    </Badge>
                  </div>
                  <div className="flex justify-between text-sm text-gray-600 pt-2 border-t">
                    <span>当前得分: {totalScore}</span>
                    <span>等级: {level}</span>
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* 单词收集盒 */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  📦 诗意单词收集盒
                </CardTitle>
                <CardDescription>
                  蛇吃掉的单词会在这里显示，收集8个单词触发AI创作
                </CardDescription>
              </CardHeader>
              <CardContent>
                <div className="space-y-2 max-h-96 overflow-y-auto">
                  {collectedWords.length === 0 ? (
                    <div className="text-center text-gray-400 py-8">
                      <div className="text-4xl mb-2">📝</div>
                      <p>还没有收集到单词</p>
                      <p className="text-sm mt-2">开始游戏来收集诗意单词吧！</p>
                    </div>
                  ) : (
                    <div className="flex flex-wrap gap-2">
                      {collectedWords.map((item) => {
                        const rarityConfig = getRarityConfig(item.rarity)
                        const stars = getRarityStars(item.rarity)
                        
                        return (
                          <Badge
                            key={item.id}
                            variant="outline"
                            className={`text-base px-3 py-2 border-2 transition-all hover:scale-105 cursor-default`}
                            style={{
                              borderColor: rarityConfig.color,
                              backgroundColor: `${rarityConfig.color}10`,
                              color: rarityConfig.color
                            }}
                          >
                            <span className="font-semibold mr-1">{item.id}.</span>
                            {item.word}
                            {stars && (
                              <span className="ml-1 text-yellow-600">{stars}</span>
                            )}
                          </Badge>
                        )
                      })}
                    </div>
                  )}
                </div>
              </CardContent>
            </Card>

            {/* 游戏说明 */}
            <Card>
              <CardHeader>
                <CardTitle>🎯 游戏说明</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="space-y-2.5 text-sm text-gray-600">
                  <div className="flex items-start gap-2">
                    <span className="font-semibold text-gray-800 mt-0.5">1.</span>
                    <span>使用方向键或WASD控制蛇移动</span>
                  </div>
                  <div className="flex items-start gap-2">
                    <span className="font-semibold text-gray-800 mt-0.5">2.</span>
                    <span>吃掉带有中文单词的食物收集单词</span>
                  </div>
                  <div className="flex items-start gap-2">
                    <span className="font-semibold text-gray-800 mt-0.5">3.</span>
                    <span>收集8个单词后自动生成诗歌</span>
                  </div>
                  <div className="flex items-start gap-2">
                    <span className="font-semibold text-gray-800 mt-0.5">4.</span>
                    <span>诗歌生成后自动创作艺术图像</span>
                  </div>
                  <div className="flex items-start gap-2">
                    <span className="font-semibold text-gray-800 mt-0.5">5.</span>
                    <span>可以重新混合诗歌创作不同风格</span>
                  </div>
                  <div className="flex items-start gap-2">
                    <span className="font-semibold text-gray-800 mt-0.5">6.</span>
                    <span>稀有度越高得分越多（普通10分，传说50分）</span>
                  </div>
                  <div className="flex items-start gap-2">
                    <span className="font-semibold text-gray-800 mt-0.5">7.</span>
                    <span>每吃5个食物速度增加，提升挑战性</span>
                  </div>
                  <div className="flex items-start gap-2">
                    <span className="font-semibold text-gray-800 mt-0.5">8.</span>
                    <span>避免撞到墙壁或蛇自己</span>
                  </div>
                </div>

                {/* 稀有度说明 */}
                <div className="mt-4 pt-4 border-t">
                  <p className="text-xs font-semibold text-gray-700 mb-2">单词稀有度：</p>
                  <div className="space-y-1 text-xs">
                    <div className="flex items-center gap-2">
                      <div className="w-3 h-3 rounded" style={{ backgroundColor: '#10b981' }}></div>
                      <span>普通（10分）</span>
                    </div>
                    <div className="flex items-center gap-2">
                      <div className="w-3 h-3 rounded" style={{ backgroundColor: '#8b5cf6' }}></div>
                      <span>稀有 ★（20分）</span>
                    </div>
                    <div className="flex items-center gap-2">
                      <div className="w-3 h-3 rounded" style={{ backgroundColor: '#f59e0b' }}></div>
                      <span>史诗 ★★（30分）</span>
                    </div>
                    <div className="flex items-center gap-2">
                      <div className="w-3 h-3 rounded" style={{ backgroundColor: '#ef4444' }}></div>
                      <span>传说 ★★★（50分）</span>
                    </div>
                  </div>
                </div>
              </CardContent>
            </Card>
          </div>
        </div>

        {/* 页脚 */}
        <footer className="mt-12 text-center text-sm text-gray-500 pb-4">
          <p>🎮 诗意贪吃蛇 - AI驱动的艺术创作游戏</p>
        </footer>
      </div>
    </div>
  )
}
