import { Game } from './game.interface';

// Hereda de Game pero incluye la puntuación del motor que lo generó
export interface Recommendation extends Game {
  coincidencias?: number; // Exclusivo de recomendación por contenido
  popularidad?: number;   // Exclusivo de recomendación colaborativa
  hybridScore?: number;   // Exclusivo de recomendación híbrida
}