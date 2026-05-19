import { Tag } from './tag.interface';

export interface Game {
  appId: number;
  title: string;
  dateRelease: string;
  price: number;
  positiveRatio: number;
  userReviews: number;
  rating: string;
  tags?: Tag[];
}