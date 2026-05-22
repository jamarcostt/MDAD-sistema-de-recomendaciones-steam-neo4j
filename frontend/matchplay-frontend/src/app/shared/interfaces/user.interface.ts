export interface User {
  user_id: number;
  products: number;
  reviews: number;
  preferences?: string[]; // Para gestionar los gustos en el frontend
}