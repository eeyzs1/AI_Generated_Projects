#!/usr/bin/env node

/**
 * 生成示例 Excel 文件用于演示
 * 运行: node examples/generate-sample-excel.js
 */

const XLSX = require('xlsx')
const path = require('path')

// 示例商品数据
const products = [
  {
    name: '羊绒围巾',
    category: '围巾',
    brand: 'Luxe',
    material: '100% 羊绒',
    size: '180cm x 30cm',
    color: '深灰色',
    targetAudience: '白领女性',
  },
  {
    name: '运动跑步鞋',
    category: '运动鞋',
    brand: 'SpeedRun',
    material: '网布 + 橡胶',
    size: 'M~XL',
    color: '黑白拼色',
    targetAudience: '健身爱好者',
  },
  {
    name: '真皮手提包',
    category: '女包',
    brand: 'ClassicBag',
    material: '意大利进口真皮',
    size: '35cm x 25cm x 12cm',
    color: '棕色',
    targetAudience: '职场女性',
  },
  {
    name: '无线蓝牙耳机',
    category: '电子产品',
    brand: 'SoundMax',
    material: '铝合金 + 硅胶',
    size: '5cm x 5cm',
    color: '深空黑',
    targetAudience: '科技爱好者',
  },
  {
    name: '棉质T恤',
    category: '服装',
    brand: 'ComfortWear',
    material: '100% 纯棉',
    size: 'XS~XXL',
    color: '纯白',
    targetAudience: '全年龄段',
  },
]

// 创建 workbook 和 worksheet
const ws = XLSX.utils.json_to_sheet(products)
const wb = XLSX.utils.book_new()
XLSX.utils.book_append_sheet(wb, ws, 'Products')

// 保存文件
const filePath = path.join(__dirname, 'products.xlsx')
XLSX.writeFile(wb, filePath)

console.log(`✅ 示例 Excel 文件已生成: ${filePath}`)
console.log(`📊 包含 ${products.length} 件商品`)
