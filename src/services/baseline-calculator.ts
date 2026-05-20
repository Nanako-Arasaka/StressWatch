import type { Baseline, HealthMetric, MetricType } from "@/models/types";
import { startOfDay } from "@/utils/date";

export interface BaselineCalculator {
  calculate(metrics: HealthMetric[]): Baseline | null;
}

export class BaselineEngine implements BaselineCalculator {
  constructor(private readonly minimumDaysRequired = 3) {}

  calculate(metrics: HealthMetric[]): Baseline | null {
    const dayKeys = new Set(
      metrics.map((metric) => startOfDay(new Date(metric.date)).toISOString())
    );

    if (dayKeys.size < this.minimumDaysRequired) {
      return null;
    }

    return {
      avgHR: averageValue("heartRate", metrics),
      avgHRV: averageValue("hrv", metrics),
      avgRestingHR: averageValue("restingHeartRate", metrics),
      avgDailySteps: averageValue("steps", metrics),
      avgSleepHours: averageValue("sleep", metrics),
      calculatedAt: new Date().toISOString(),
      dataWindowDays: dayKeys.size
    };
  }
}

function averageValue(type: MetricType, metrics: HealthMetric[]): number {
  const values = metrics.filter((metric) => metric.type === type).map((metric) => metric.value);
  if (values.length === 0) {
    return 0;
  }

  return values.reduce((sum, value) => sum + value, 0) / values.length;
}
