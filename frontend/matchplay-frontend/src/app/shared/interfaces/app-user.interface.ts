import { Game } from './game.interface';

export interface AppUser {
  id: string;
  name: string;
  library: Game[];
}