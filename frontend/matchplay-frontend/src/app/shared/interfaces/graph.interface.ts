export interface SimilarGameEdge {
  sourceId: number;
  sourceTitle: string;
  targetId: number;
  targetTitle: string;
  shared: number; // Cantidad de etiquetas compartidas
}

export interface RelatedTagEdge {
  source: string;
  target: string;
  weight: number; // Fuerza de la relación
}