import React, { useState } from 'react'
import * as XLSX from 'xlsx'
import ResultCard from '../components/ResultCard'
import TemplateManager from '../components/TemplateManager'
import ProductForm from '../components/ProductForm'

type Product = {
  id: string
  name: string
  category?: string
  brand?: string
  material?: string
  size?: string
  color?: string
  targetAudience?: string
  images?: string[]
}

type GenerateResult = {
  productId: string
  mainImageDraft: string
  titleDraft: string
  sellingPoints: string[]
}

export default function ImportPage() {
  const [products, setProducts] = useState<Product[]>([])
  const [results, setResults] = useState<GenerateResult[]>([])
  const [isLoading, setIsLoading] = useState(false)
  const [activeTab, setActiveTab] = useState<'import' | 'template'>('import')
  const [editedResults, setEditedResults] = useState<Map<string, GenerateResult>>(new Map())
  const [showProductForm, setShowProductForm] = useState(false)

  function handleFile(e: React.ChangeEvent<HTMLInputElement>) {
    const f = e.target.files?.[0]
    if (!f) return
    const reader = new FileReader()
    reader.onload = (ev) => {
      const data = ev.target?.result
      const wb = XLSX.read(data, { type: 'array' })
      const ws = wb.Sheets[wb.SheetNames[0]]
      const json = XLSX.utils.sheet_to_json(ws, { header: 1 }) as any[]
      const headers = json[0] as string[]
      const rows = json.slice(1)
      const items = rows.map((r, idx) => {
        const obj: any = { id: 'p-' + idx }
        headers.forEach((h, i) => {
          obj[h] = r[i]
        })
        return obj as Product
      })
      setProducts(items)
      setResults([])
      setEditedResults(new Map())
    }
    reader.readAsArrayBuffer(f)
  }

  async function generate() {
    if (products.length === 0) {
      alert('请先导入商品')
      return
    }
    setIsLoading(true)
    try {
      const res = await fetch('http://localhost:3000/api/generate-batch', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ items: products, options: { saveToLibrary: false } })
      })
      const data = await res.json()
      setResults(data.results || [])
      setEditedResults(new Map(data.results.map((r: GenerateResult) => [r.productId, r])))
    } catch (err) {
      console.error('生成失败:', err)
      alert('生成失败: ' + (err instanceof Error ? err.message : '未知错误'))
    } finally {
      setIsLoading(false)
    }
  }

  const handleEditResult = (productId: string, title: string, points: string[]) => {
    const updated = new Map(editedResults)
    const result = updated.get(productId)
    if (result) {
      result.titleDraft = title
      result.sellingPoints = points
      updated.set(productId, result)
      setEditedResults(updated)
      alert('已保存修改')
    }
  }

  const handleSaveTemplate = async (productId: string, title: string, points: string[]) => {
    const result = editedResults.get(productId)
    if (!result) return
    
    const templateData = {
      id: 'tpl-' + productId + '-' + Date.now(),
      name: `${products.find(p => p.id === productId)?.name || '商品'} - 模板`,
      tags: [],
      parts: {
        titleTemplate: title,
        sellingPointsTemplates: points,
      },
      createdAt: new Date().toISOString(),
    }
    
    const templates = JSON.parse(localStorage.getItem('product_templates') || '[]')
    templates.push(templateData)
    localStorage.setItem('product_templates', JSON.stringify(templates))
    alert('已收藏为模板！')
  }

  const handleAddProduct = (product: Product) => {
    setProducts([...products, product])
    alert(`✅ 已添加商品: ${product.name}`)
    setShowProductForm(false)
  }

  const handleDeleteProduct = (productId: string) => {
    setProducts(products.filter(p => p.id !== productId))
    // 如果已有生成结果，也删除对应的结果
    const updated = new Map(editedResults)
    updated.delete(productId)
    setEditedResults(updated)
  }

  const exportCSV = () => {
    if (editedResults.size === 0) {
      alert('没有可导出的数据')
      return
    }

    const data = Array.from(editedResults.values()).map(r => ({
      productId: r.productId,
      title: r.titleDraft,
      sellingPoints: r.sellingPoints.join('|'),
      imageUrl: r.mainImageDraft,
    }))

    const ws = XLSX.utils.json_to_sheet(data)
    const wb = XLSX.utils.book_new()
    XLSX.utils.book_append_sheet(wb, ws, 'results')
    XLSX.writeFile(wb, `product-draft-${Date.now()}.csv`)
  }

  return (
    <div style={styles.container}>
      <div style={styles.tabs}>
        <button
          onClick={() => setActiveTab('import')}
          style={{ ...styles.tab, ...(activeTab === 'import' ? styles.tabActive : {}) }}
        >
          导入和生成
        </button>
        <button
          onClick={() => setActiveTab('template')}
          style={{ ...styles.tab, ...(activeTab === 'template' ? styles.tabActive : {}) }}
        >
          模板库
        </button>
      </div>

      {activeTab === 'import' && (
        <div style={styles.content}>
          <div style={styles.section}>
            <h2>方式 1: 导入 Excel 文件</h2>
            <div>
              <label style={styles.label}>
                上传 Excel 文件 (.xlsx 或 .xls):
                <input type="file" accept=".xlsx,.xls" onChange={handleFile} />
              </label>
            </div>
          </div>

          <div style={styles.divider}></div>

          <div style={styles.section}>
            <h2>方式 2: 手动添加单个商品</h2>
            {!showProductForm ? (
              <button onClick={() => setShowProductForm(true)} style={styles.btnSecondary}>
                + 打开表单手动添加商品
              </button>
            ) : (
              <ProductForm
                onSubmit={handleAddProduct}
                onCancel={() => setShowProductForm(false)}
              />
            )}
          </div>

          {products.length > 0 && (
            <div style={styles.section}>
              <h3>已导入商品 ({products.length})</h3>
              <div style={styles.productList}>
                {products.map((p) => (
                  <div key={p.id} style={styles.productItem}>
                    <div style={styles.productInfo}>
                      <div><strong>{p.name}</strong></div>
                      <div style={{ fontSize: '12px', color: '#666' }}>
                        {p.brand && `品牌: ${p.brand}`}
                        {p.brand && p.category && ' • '}
                        {p.category && `分类: ${p.category}`}
                      </div>
                    </div>
                    <button
                      onClick={() => handleDeleteProduct(p.id)}
                      style={styles.btnDelete}
                    >
                      🗑️ 删除
                    </button>
                  </div>
                ))}
              </div>
            </div>
          )}

          <div style={styles.section}>
            <h2>步骤 2: 批量生成草稿</h2>
            <button
              onClick={generate}
              disabled={products.length === 0 || isLoading}
              style={styles.btnPrimary}
            >
              {isLoading ? '生成中...' : '🎨 生成草稿'}
            </button>
          </div>

          {results.length > 0 && (
            <div style={styles.section}>
              <h2>步骤 3: 查看和编辑结果</h2>
              <div style={styles.actions}>
                <button onClick={exportCSV} style={styles.btnSecondary}>📥 导出 CSV</button>
              </div>

              <div style={styles.resultsGrid}>
                {Array.from(editedResults.values()).map(result => (
                  <ResultCard
                    key={result.productId}
                    productId={result.productId}
                    titleDraft={result.titleDraft}
                    sellingPoints={result.sellingPoints}
                    mainImageDraft={result.mainImageDraft}
                    onEdit={(title, points) => handleEditResult(result.productId, title, points)}
                    onSaveTemplate={(title, points) => handleSaveTemplate(result.productId, title, points)}
                  />
                ))}
              </div>
            </div>
          )}
        </div>
      )}

      {activeTab === 'template' && (
        <div style={styles.content}>
          <TemplateManager />
        </div>
      )}
    </div>
  )
}

const styles = {
  container: {
    maxWidth: '1200px',
    margin: '0 auto',
    padding: '20px',
  } as React.CSSProperties,
  tabs: {
    display: 'flex',
    gap: '8px',
    marginBottom: '20px',
    borderBottom: '2px solid #f0f0f0',
  } as React.CSSProperties,
  tab: {
    padding: '10px 16px',
    backgroundColor: 'transparent',
    border: 'none',
    cursor: 'pointer',
    fontSize: '16px',
    color: '#666',
    borderBottom: '2px solid transparent',
  } as React.CSSProperties,
  tabActive: {
    color: '#1890ff',
    borderBottomColor: '#1890ff',
  } as React.CSSProperties,
  content: {
    backgroundColor: '#fff',
    borderRadius: '8px',
    padding: '20px',
  } as React.CSSProperties,
  section: {
    marginBottom: '32px',
  } as React.CSSProperties,
  divider: {
    height: '1px',
    backgroundColor: '#f0f0f0',
    margin: '24px 0',
  } as React.CSSProperties,
  label: {
    display: 'block',
    marginBottom: '12px',
    fontSize: '14px',
  } as React.CSSProperties,
  list: {
    listStyle: 'none',
    padding: '0',
  } as React.CSSProperties,
  productList: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fill, minmax(200px, 1fr))',
    gap: '12px',
    marginTop: '12px',
  } as React.CSSProperties,
  productItem: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: '12px',
    backgroundColor: '#f9f9f9',
    borderRadius: '4px',
    border: '1px solid #eee',
  } as React.CSSProperties,
  productInfo: {
    flex: 1,
  } as React.CSSProperties,
  actions: {
    display: 'flex',
    gap: '8px',
    marginBottom: '16px',
  } as React.CSSProperties,
  btnPrimary: {
    padding: '10px 16px',
    backgroundColor: '#1890ff',
    color: '#fff',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer',
    fontSize: '16px',
  } as React.CSSProperties,
  btnSecondary: {
    padding: '8px 12px',
    backgroundColor: '#fff',
    color: '#1890ff',
    border: '1px solid #1890ff',
    borderRadius: '4px',
    cursor: 'pointer',
  } as React.CSSProperties,
  btnDelete: {
    padding: '6px 8px',
    backgroundColor: '#fff',
    color: '#ff4d4f',
    border: '1px solid #ff4d4f',
    borderRadius: '4px',
    cursor: 'pointer',
    fontSize: '12px',
  } as React.CSSProperties,
  resultsGrid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fill, minmax(350px, 1fr))',
    gap: '16px',
  } as React.CSSProperties,
}
