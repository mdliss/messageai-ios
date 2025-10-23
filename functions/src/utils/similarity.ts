/**
 * Vector similarity utilities for RAG search
 */

/**
 * Calculate cosine similarity between two embedding vectors
 * Formula: similarity = dot(v1, v2) / (||v1|| * ||v2||)
 * 
 * @param vec1 First embedding vector (1536 dimensions)
 * @param vec2 Second embedding vector (1536 dimensions)
 * @returns Similarity score between -1 and 1 (1 = identical, 0 = orthogonal, -1 = opposite)
 */
export function cosineSimilarity(vec1: number[], vec2: number[]): number {
  if (vec1.length !== vec2.length) {
    throw new Error(`Vector dimensions must match: ${vec1.length} !== ${vec2.length}`);
  }
  
  if (vec1.length === 0) {
    return 0;
  }
  
  // Calculate dot product
  let dotProduct = 0;
  for (let i = 0; i < vec1.length; i++) {
    dotProduct += vec1[i] * vec2[i];
  }
  
  // Calculate magnitudes (L2 norms)
  let magnitude1 = 0;
  let magnitude2 = 0;
  for (let i = 0; i < vec1.length; i++) {
    magnitude1 += vec1[i] * vec1[i];
    magnitude2 += vec2[i] * vec2[i];
  }
  
  magnitude1 = Math.sqrt(magnitude1);
  magnitude2 = Math.sqrt(magnitude2);
  
  // Avoid division by zero
  if (magnitude1 === 0 || magnitude2 === 0) {
    return 0;
  }
  
  // Calculate cosine similarity
  const similarity = dotProduct / (magnitude1 * magnitude2);
  
  return similarity;
}

/**
 * Calculate cosine similarities between a query vector and multiple vectors
 * Optimized for batch processing
 * 
 * @param queryVec Query embedding vector
 * @param vectors Array of embedding vectors to compare against
 * @returns Array of similarity scores in same order as input vectors
 */
export function batchCosineSimilarity(
  queryVec: number[],
  vectors: number[][]
): number[] {
  return vectors.map(vec => cosineSimilarity(queryVec, vec));
}

/**
 * Find top K most similar vectors
 * 
 * @param queryVec Query embedding vector
 * @param vectors Array of embedding vectors with metadata
 * @param k Number of top results to return
 * @returns Array of indices and scores, sorted by similarity (highest first)
 */
export function topKSimilar<T>(
  queryVec: number[],
  vectors: Array<{ embedding: number[]; data: T }>,
  k: number
): Array<{ index: number; score: number; data: T }> {
  // Calculate all similarities
  const results = vectors.map((item, index) => ({
    index,
    score: cosineSimilarity(queryVec, item.embedding),
    data: item.data
  }));
  
  // Sort by score descending
  results.sort((a, b) => b.score - a.score);
  
  // Return top K
  return results.slice(0, k);
}

