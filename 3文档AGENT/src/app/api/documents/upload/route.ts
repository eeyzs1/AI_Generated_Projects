import { NextResponse } from 'next/server'
import { memoryStore } from '@/lib/memory-store'
import { processDocument } from '@/lib/document-processor'
import { vectorStoreManager } from '@/lib/vector-store'

export async function POST(request: Request) {
  try {
    const formData = await request.formData()
    const file = formData.get('file') as File

    if (!file) {
      return NextResponse.json(
        { error: 'No file provided' },
        { status: 400 }
      )
    }

    console.log('[POST /api/documents/upload] Uploading file:', file.name)

    // Create document record in memory store
    const document = memoryStore.createDocument({
      name: file.name,
      originalName: file.name,
      size: BigInt(file.size),
      mimeType: file.type || 'application/octet-stream',
      status: 'processing',
      errorMessage: null,
      content: null
    })

    console.log('[POST /api/documents/upload] Created document:', {
      id: document.id,
      name: document.name,
      status: document.status
    })

    // Process document in background
    processDocument(document.id, file)
      .then(async () => {
        console.log('[Document Processing] Document processed successfully:', document.id)
        memoryStore.updateDocument(document.id, {
          status: 'ready'
        })
      })
      .catch(async (error) => {
        console.error('Document processing error:', error)
        memoryStore.updateDocument(document.id, {
          status: 'error',
          errorMessage: error instanceof Error ? error.message : 'Unknown error'
        })
      })

    return NextResponse.json({
      id: document.id,
      name: file.name,
      status: 'processing'
    })
  } catch (error) {
    console.error('Upload error:', error)
    return NextResponse.json(
      { error: 'Failed to upload document' },
      { status: 500 }
    )
  }
}
