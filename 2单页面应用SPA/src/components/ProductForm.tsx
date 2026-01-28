import React, { useState } from 'react'

export type Product = {
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

export type ProductFormProps = {
  onSubmit?: (product: Product) => void
  onCancel?: () => void
  initialData?: Partial<Product>
  isLoading?: boolean
}

export default function ProductForm({ onSubmit, onCancel, initialData, isLoading }: ProductFormProps) {
  const [form, setForm] = useState({
    name: initialData?.name || '',
    category: initialData?.category || '',
    brand: initialData?.brand || '',
    material: initialData?.material || '',
    size: initialData?.size || '',
    color: initialData?.color || '',
    targetAudience: initialData?.targetAudience || '',
  })

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (!form.name.trim()) {
      alert('请输入商品名称')
      return
    }

    const product: Product = {
      id: 'p-manual-' + Date.now(),
      name: form.name.trim(),
      category: form.category.trim() || undefined,
      brand: form.brand.trim() || undefined,
      material: form.material.trim() || undefined,
      size: form.size.trim() || undefined,
      color: form.color.trim() || undefined,
      targetAudience: form.targetAudience.trim() || undefined,
    }

    onSubmit?.(product)
    // 重置表单
    setForm({ name: '', category: '', brand: '', material: '', size: '', color: '', targetAudience: '' })
  }

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    const { name, value } = e.target
    setForm({ ...form, [name]: value })
  }

  return (
    <form onSubmit={handleSubmit} style={styles.form}>
      <fieldset style={styles.fieldset} disabled={isLoading}>
        <legend style={styles.legend}>📝 手动添加商品</legend>
        
        <div style={styles.grid}>
          <label style={styles.label}>
            商品名称 <span style={styles.required}>*</span>：<br />
            <input
              type="text"
              name="name"
              value={form.name}
              onChange={handleChange}
              placeholder="例如：羊绒围巾"
              style={styles.input}
              required
            />
          </label>

          <label style={styles.label}>
            品牌：<br />
            <input
              type="text"
              name="brand"
              value={form.brand}
              onChange={handleChange}
              placeholder="例如：Luxe"
              style={styles.input}
            />
          </label>

          <label style={styles.label}>
            分类：<br />
            <input
              type="text"
              name="category"
              value={form.category}
              onChange={handleChange}
              placeholder="例如：围巾"
              style={styles.input}
            />
          </label>

          <label style={styles.label}>
            颜色：<br />
            <input
              type="text"
              name="color"
              value={form.color}
              onChange={handleChange}
              placeholder="例如：深灰色"
              style={styles.input}
            />
          </label>

          <label style={styles.label}>
            材质：<br />
            <input
              type="text"
              name="material"
              value={form.material}
              onChange={handleChange}
              placeholder="例如：100% 羊绒"
              style={styles.input}
            />
          </label>

          <label style={styles.label}>
            尺寸：<br />
            <input
              type="text"
              name="size"
              value={form.size}
              onChange={handleChange}
              placeholder="例如：180cm x 30cm"
              style={styles.input}
            />
          </label>

          <label style={{ ...styles.label, gridColumn: 'span 2' }}>
            目标人群：<br />
            <input
              type="text"
              name="targetAudience"
              value={form.targetAudience}
              onChange={handleChange}
              placeholder="例如：白领女性"
              style={styles.input}
            />
          </label>
        </div>

        <div style={styles.actions}>
          <button type="submit" style={styles.btnPrimary} disabled={isLoading}>
            {isLoading ? '添加中...' : '✅ 添加商品'}
          </button>
          {onCancel && (
            <button type="button" onClick={onCancel} style={styles.btnSecondary} disabled={isLoading}>
              取消
            </button>
          )}
        </div>
      </fieldset>
    </form>
  )
}

const styles = {
  form: {
    padding: '0',
    marginBottom: '16px',
  } as React.CSSProperties,
  fieldset: {
    padding: '16px',
    backgroundColor: '#f9fafb',
    borderRadius: '4px',
    border: '1px solid #e5e7eb',
  } as React.CSSProperties,
  legend: {
    padding: '0 8px',
    fontSize: '16px',
    fontWeight: 'bold',
    color: '#1f2937',
  } as React.CSSProperties,
  grid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
    gap: '12px',
    marginBottom: '16px',
  } as React.CSSProperties,
  label: {
    display: 'block',
    fontSize: '14px',
    color: '#374151',
  } as React.CSSProperties,
  input: {
    display: 'block',
    width: '100%',
    padding: '8px',
    marginTop: '4px',
    borderRadius: '4px',
    border: '1px solid #d1d5db',
    fontFamily: 'inherit',
    fontSize: '14px',
    boxSizing: 'border-box',
  } as React.CSSProperties,
  required: {
    color: '#ef4444',
    fontSize: '16px',
  } as React.CSSProperties,
  actions: {
    display: 'flex',
    gap: '8px',
  } as React.CSSProperties,
  btnPrimary: {
    padding: '10px 16px',
    backgroundColor: '#3b82f6',
    color: '#fff',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer',
    fontSize: '14px',
    fontWeight: '500',
  } as React.CSSProperties,
  btnSecondary: {
    padding: '10px 16px',
    backgroundColor: '#e5e7eb',
    color: '#374151',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer',
    fontSize: '14px',
  } as React.CSSProperties,
}
