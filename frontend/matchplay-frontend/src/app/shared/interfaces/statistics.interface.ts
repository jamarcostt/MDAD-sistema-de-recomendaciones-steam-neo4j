export interface TagCount {
  tag: string;
  total: number;
}

export interface PriceDistribution {
  free: number;
  under5: number;
  under20: number;
  over20: number;
}

export interface MetricComparison {
  userAvg: number;
  globalAvg: number;
}