const express = require('express')
const cors = require('cors')
const bodyParser = require('body-parser')

const app = express()
app.use(cors())
app.use(bodyParser.json({ limit: '10mb' }))

// In-memory storage (or use localStorage on client)
let templates = []

/**
 * 生成单个商品的草稿
 * @param {Object} item - 商品对象
 * @param {Object} template - 可选模板对象，用于套用模板样式
 */
function generateDraftForItem(item, template = null) {
  let titleDraft = ''
  let sellingPoints = []

  if (template && template.parts && template.parts.titleTemplate) {
    // 使用模板生成标题
    titleDraft = template.parts.titleTemplate
    titleDraft = titleDraft.replace(/{name}/g, item.name || '')
    titleDraft = titleDraft.replace(/{brand}/g, item.brand || '')
    titleDraft = titleDraft.replace(/{color}/g, item.color || '')
    titleDraft = titleDraft.replace(/{material}/g, item.material || '')
    titleDraft = titleDraft.replace(/{size}/g, item.size || '')
    titleDraft = titleDraft.replace(/{category}/g, item.category || '')
    titleDraft = titleDraft.replace(/{targetAudience}/g, item.targetAudience || '')
    
    // 使用模板生成卖点
    sellingPoints = (template.parts.sellingPointsTemplates || []).map(sp => {
      let result = sp
      result = result.replace(/{name}/g, item.name || '')
      result = result.replace(/{brand}/g, item.brand || '')
      result = result.replace(/{color}/g, item.color || '')
      result = result.replace(/{material}/g, item.material || '')
      result = result.replace(/{size}/g, item.size || '')
      result = result.replace(/{category}/g, item.category || '')
      result = result.replace(/{targetAudience}/g, item.targetAudience || '')
      return result
    })
  } else {
    // 使用规则引擎生成
    titleDraft = `${item.brand || ''} ${item.name || ''} ${item.color || ''}`.trim()
    
    if (item.material) sellingPoints.push(`${item.material} 材质`)
    if (item.targetAudience) sellingPoints.push(`适合${item.targetAudience}`)
    if (item.size) sellingPoints.push(`尺寸：${item.size}`)
  }

  // 生成简单的 SVG 图片草稿
  const productName = (item.name || '商品').slice(0, 30)
  const productTitle = (titleDraft || '默认标题').slice(0, 50)
  const svg = `<svg xmlns='http://www.w3.org/2000/svg' width='800' height='800'>
    <rect width='100%' height='100%' fill='#ffffff'/>
    <rect width='100%' height='200' y='600' fill='#f5f5f5'/>
    <text x='20' y='50' font-size='28' font-weight='bold' fill='#111'>${productName}</text>
    <text x='20' y='90' font-size='16' fill='#666'>${productTitle}</text>
    <text x='20' y='650' font-size='14' fill='#999'>生成时间: ${new Date().toLocaleString('zh-CN')}</text>
  </svg>`
  
  const img = 'data:image/svg+xml;base64,' + Buffer.from(svg).toString('base64')

  return {
    productId: item.id,
    mainImageDraft: img,
    titleDraft: titleDraft || '默认标题',
    sellingPoints: sellingPoints.slice(0, 2),
  }
}

/**
 * POST /api/generate-batch
 * 批量生成商品草稿
 */
app.post('/api/generate-batch', (req, res) => {
  const { items, options } = req.body
  const templateId = options?.templateId
  
  let template = null
  if (templateId) {
    template = templates.find(t => t.id === templateId)
  }

  const results = (items || []).map(item => generateDraftForItem(item, template))
  res.json({ results })
})

/**
 * GET /api/templates
 * 获取所有模板
 */
app.get('/api/templates', (req, res) => {
  res.json({ templates })
})

/**
 * POST /api/templates
 * 创建新模板
 */
app.post('/api/templates', (req, res) => {
  const { name, tags, parts } = req.body
  const template = {
    id: 'tpl-' + Date.now(),
    name,
    tags: tags || [],
    parts: parts || {},
    createdAt: new Date().toISOString(),
  }
  templates.push(template)
  res.json({ template })
})

/**
 * DELETE /api/templates/:id
 * 删除模板
 */
app.delete('/api/templates/:id', (req, res) => {
  const { id } = req.params
  templates = templates.filter(t => t.id !== id)
  res.json({ success: true })
})

/**
 * PUT /api/templates/:id
 * 更新模板
 */
app.put('/api/templates/:id', (req, res) => {
  const { id } = req.params
  const { name, tags, parts } = req.body
  const idx = templates.findIndex(t => t.id === id)
  if (idx >= 0) {
    templates[idx] = { ...templates[idx], name, tags, parts }
    res.json({ template: templates[idx] })
  } else {
    res.status(404).json({ error: 'Template not found' })
  }
})

/**
 * 演示用：AI 接口占位
 * 如何替换为真实 LLM 或视觉服务，请参考 README
 */
app.post('/api/ai/generate-title', (req, res) => {
  const { product } = req.body
  // TODO: 替换为真实 AI 调用（OpenAI, Claude, etc）
  const title = `【${product.brand || '品牌'}】${product.name}，${product.color}，${product.material || '优选'}`
  res.json({ title })
})

app.listen(3000, () => {
  console.log('✅ Mock API server listening on http://localhost:3000')
  console.log('📝 Endpoints:')
  console.log('  POST /api/generate-batch - 批量生成草稿')
  console.log('  GET  /api/templates - 获取所有模板')
  console.log('  POST /api/templates - 创建新模板')
  console.log('  PUT  /api/templates/:id - 更新模板')
  console.log('  DELETE /api/templates/:id - 删除模板')
})
