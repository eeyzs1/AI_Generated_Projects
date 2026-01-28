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

export type GenerateResult = {
  productId: string
  mainImageDraft: string
  titleDraft: string
  sellingPoints: string[]
}
