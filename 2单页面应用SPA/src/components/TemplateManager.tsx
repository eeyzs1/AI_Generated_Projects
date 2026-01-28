import React, { useState, useEffect } from 'react'

export type TemplateItem = {
  id: string
  name: string
  tags: string[]
  parts: {
    titleTemplate?: string
    sellingPointsTemplates?: string[]
    imageTemplate?: string
  }
  createdAt?: string
}

export default function TemplateManager() {
  const [templates, setTemplates] = useState<TemplateItem[]>([])
  const [showForm, setShowForm] = useState(false)
  const [newTemplate, setNewTemplate] = useState({
    name: '',
    tags: '',
    titleTemplate: '',
    sellingPointsTemplates: '',
  })

  useEffect(() => {
    // Load templates from localStorage
    const saved = localStorage.getItem('product_templates')
    if (saved) {
      setTemplates(JSON.parse(saved))
    }
  }, [])

  const saveTemplate = () => {
    const template: TemplateItem = {
      id: 'tpl-' + Date.now(),
      name: newTemplate.name,
      tags: newTemplate.tags.split(',').map(t => t.trim()).filter(Boolean),
      parts: {
        titleTemplate: newTemplate.titleTemplate,
        sellingPointsTemplates: newTemplate.sellingPointsTemplates
          .split('\n')
          .map(s => s.trim())
          .filter(Boolean),
      },
      createdAt: new Date().toISOString(),
    }
    const updated = [...templates, template]
    setTemplates(updated)
    localStorage.setItem('product_templates', JSON.stringify(updated))
    setNewTemplate({ name: '', tags: '', titleTemplate: '', sellingPointsTemplates: '' })
    setShowForm(false)
    alert('模板已保存！')
  }

  const deleteTemplate = (id: string) => {
    const updated = templates.filter(t => t.id !== id)
    setTemplates(updated)
    localStorage.setItem('product_templates', JSON.stringify(updated))
  }

  return (
    <div style={styles.container}>
      <h2>模板库</h2>
      <button onClick={() => setShowForm(!showForm)} style={styles.btn}>
        {showForm ? '取消' : '新建模板'}
      </button>

      {showForm && (
        <div style={styles.form}>
          <input
            type="text"
            placeholder="模板名称"
            value={newTemplate.name}
            onChange={(e) => setNewTemplate({ ...newTemplate, name: e.target.value })}
            style={styles.input}
          />
          <input
            type="text"
            placeholder="标签（逗号分隔）"
            value={newTemplate.tags}
            onChange={(e) => setNewTemplate({ ...newTemplate, tags: e.target.value })}
            style={styles.input}
          />
          <textarea
            placeholder="标题模板（例如：【{brand}】{name} {color}）"
            value={newTemplate.titleTemplate}
            onChange={(e) => setNewTemplate({ ...newTemplate, titleTemplate: e.target.value })}
            style={styles.textarea}
          />
          <textarea
            placeholder="卖点模板（每行一条，支持 {material} {size} {color} 等占位符）"
            value={newTemplate.sellingPointsTemplates}
            onChange={(e) => setNewTemplate({ ...newTemplate, sellingPointsTemplates: e.target.value })}
            style={styles.textarea}
          />
          <button onClick={saveTemplate} style={styles.btn}>保存模板</button>
        </div>
      )}

      <div style={styles.list}>
        {templates.length === 0 ? (
          <p>暂无模板</p>
        ) : (
          templates.map((tpl) => (
            <div key={tpl.id} style={styles.item}>
              <h3>{tpl.name}</h3>
              <p>标签: {tpl.tags.join(', ') || '无'}</p>
              <p><strong>标题模板:</strong> {tpl.parts.titleTemplate}</p>
              <p><strong>卖点:</strong></p>
              <ul>
                {tpl.parts.sellingPointsTemplates?.map((p, i) => <li key={i}>{p}</li>)}
              </ul>
              <button onClick={() => deleteTemplate(tpl.id)} style={styles.btnDanger}>删除</button>
            </div>
          ))
        )}
      </div>
    </div>
  )
}

const styles = {
  container: {
    padding: '20px',
    backgroundColor: '#f5f5f5',
    borderRadius: '8px',
  } as React.CSSProperties,
  form: {
    backgroundColor: '#fff',
    padding: '12px',
    borderRadius: '4px',
    marginBottom: '16px',
  } as React.CSSProperties,
  input: {
    display: 'block',
    width: '100%',
    padding: '8px',
    marginBottom: '8px',
    borderRadius: '4px',
    border: '1px solid #d9d9d9',
    fontFamily: 'inherit',
  } as React.CSSProperties,
  textarea: {
    display: 'block',
    width: '100%',
    padding: '8px',
    marginBottom: '8px',
    minHeight: '80px',
    borderRadius: '4px',
    border: '1px solid #d9d9d9',
    fontFamily: 'inherit',
  } as React.CSSProperties,
  btn: {
    padding: '8px 12px',
    backgroundColor: '#1890ff',
    color: '#fff',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer',
    marginBottom: '12px',
  } as React.CSSProperties,
  btnDanger: {
    padding: '6px 10px',
    backgroundColor: '#ff4d4f',
    color: '#fff',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer',
    fontSize: '12px',
  } as React.CSSProperties,
  list: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fill, minmax(300px, 1fr))',
    gap: '12px',
  } as React.CSSProperties,
  item: {
    backgroundColor: '#fff',
    padding: '12px',
    borderRadius: '4px',
    border: '1px solid #ddd',
  } as React.CSSProperties,
}
