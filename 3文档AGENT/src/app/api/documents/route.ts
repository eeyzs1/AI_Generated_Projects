import { NextResponse } from 'next/server'
import { memoryStore } from '@/lib/memory-store'

export async function GET() {
  try {
    const documents = memoryStore.getAllDocuments()
    console.log('[GET /api/documents] Current documents count:', documents.length)
    console.log('[GET /api/documents] Documents:', documents.map(d => ({
      id: d.id,
      name: d.name,
      status: d.status
    })))

    const response = documents.map(doc => ({
      id: doc.id,
      name: doc.name,
      originalName: doc.originalName,
      size: Number(doc.size),
      status: doc.status,
      uploadTime: doc.createdAt.toISOString(),
      errorMessage: doc.errorMessage
    }))

    return NextResponse.json(response)
  } catch (error) {
    console.error('Error fetching documents:', error)
    return NextResponse.json(
      { error: 'Failed to fetch documents' },
      { status: 500 }
    )
  }
}
