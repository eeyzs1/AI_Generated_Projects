import React from 'react'
import ImportPage from './ImportPage'

export default function App(){
  return (
    <div>
      <header style={{ padding: '20px', backgroundColor: '#f0f2f5', borderBottom: '1px solid #d9d9d9' }}>
        <h1 style={{ margin: 0 }}>🎨 产品图文草稿生成系统</h1>
        <p style={{ margin: '8px 0 0 0', color: '#666', fontSize: '14px' }}>
          帮助运营批量生成第一版图文草稿，并沉淀可复用模板库
        </p>
      </header>
      <ImportPage />
    </div>
  )
}
