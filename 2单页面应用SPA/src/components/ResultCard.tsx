import React, { useState } from 'react'

export type ResultCardProps = {
  productId: string
  titleDraft: string
  sellingPoints: string[]
  mainImageDraft: string
  onEdit?: (title: string, points: string[]) => void
  onSaveTemplate?: (title: string, points: string[]) => void
}

export default function ResultCard({
  productId,
  titleDraft,
  sellingPoints,
  mainImageDraft,
  onEdit,
  onSaveTemplate,
}: ResultCardProps) {
  const [isEditing, setIsEditing] = useState(false)
  const [editTitle, setEditTitle] = useState(titleDraft)
  const [editPoints, setEditPoints] = useState(sellingPoints.join('\n'))

  const handleSave = () => {
    const points = editPoints.split('\n').filter(p => p.trim())
    onEdit?.(editTitle, points)
    setIsEditing(false)
  }

  const downloadImage = () => {
    const link = document.createElement('a')
    link.href = mainImageDraft
    link.download = `${productId}-mainimage.png`
    link.click()
  }

  return (
    <div style={styles.card}>
      <div style={styles.cardHeader}>
        <h3>商品 ID: {productId}</h3>
      </div>

      <div style={styles.imageContainer}>
        <img src={mainImageDraft} alt="主图草稿" style={styles.image} />
        <button onClick={downloadImage} style={styles.btnSmall}>下载主图</button>
      </div>

      {!isEditing ? (
        <>
          <div style={styles.section}>
            <p><strong>标题：</strong> {editTitle}</p>
            <p><strong>卖点：</strong></p>
            <ul>
              {editPoints.split('\n').map((p, i) => p.trim() && <li key={i}>{p}</li>)}
            </ul>
          </div>
          <div style={styles.actions}>
            <button onClick={() => setIsEditing(true)} style={styles.btn}>编辑</button>
            <button onClick={() => onSaveTemplate?.(editTitle, editPoints.split('\n').filter(p => p.trim()))} style={styles.btn}>收藏为模板</button>
          </div>
        </>
      ) : (
        <>
          <div style={styles.section}>
            <label>标题：<br />
              <input
                type="text"
                value={editTitle}
                onChange={(e) => setEditTitle(e.target.value)}
                style={styles.input}
              />
            </label>
            <label>卖点（每行一条）：<br />
              <textarea
                value={editPoints}
                onChange={(e) => setEditPoints(e.target.value)}
                style={styles.textarea}
              />
            </label>
          </div>
          <div style={styles.actions}>
            <button onClick={handleSave} style={styles.btn}>保存</button>
            <button onClick={() => setIsEditing(false)} style={styles.btn}>取消</button>
          </div>
        </>
      )}
    </div>
  )
}

const styles = {
  card: {
    border: '1px solid #ddd',
    borderRadius: '8px',
    padding: '16px',
    marginBottom: '16px',
    backgroundColor: '#fafafa',
  } as React.CSSProperties,
  cardHeader: {
    borderBottom: '1px solid #eee',
    paddingBottom: '8px',
    marginBottom: '12px',
  } as React.CSSProperties,
  imageContainer: {
    textAlign: 'center' as const,
    marginBottom: '12px',
  } as React.CSSProperties,
  image: {
    maxWidth: '200px',
    maxHeight: '200px',
    marginBottom: '8px',
  } as React.CSSProperties,
  section: {
    marginBottom: '12px',
  } as React.CSSProperties,
  actions: {
    display: 'flex',
    gap: '8px',
  } as React.CSSProperties,
  btn: {
    padding: '8px 12px',
    backgroundColor: '#1890ff',
    color: '#fff',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer',
  } as React.CSSProperties,
  btnSmall: {
    padding: '4px 8px',
    backgroundColor: '#1890ff',
    color: '#fff',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer',
    fontSize: '12px',
  } as React.CSSProperties,
  input: {
    width: '100%',
    padding: '8px',
    marginTop: '4px',
    borderRadius: '4px',
    border: '1px solid #d9d9d9',
    fontFamily: 'inherit',
    fontSize: 'inherit',
  } as React.CSSProperties,
  textarea: {
    width: '100%',
    padding: '8px',
    marginTop: '4px',
    minHeight: '80px',
    borderRadius: '4px',
    border: '1px solid #d9d9d9',
    fontFamily: 'inherit',
    fontSize: 'inherit',
  } as React.CSSProperties,
}
