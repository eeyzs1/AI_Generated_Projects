import { NextResponse } from 'next/server'
import { memoryStore } from '@/lib/memory-store'
import { vectorStoreManager } from '@/lib/vector-store'

export async function DELETE(
  request: Request,
  { params }: { params: { id: string } }
) {
  try {
    const { id } = params

    // Delete from vector store
    await vectorStoreManager.deleteDocument(id)

    // Delete from memory store
    memoryStore.deleteDocument(id)

    return NextResponse.json({ success: true })
  } catch (error) {
    console.error('Delete error:', error)
    return NextResponse.json(
      { error: 'Failed to delete document' },
      { status: 500 }
    )
  }
}
