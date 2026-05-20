import type { HealthDataProvider } from "@/data/health-data-provider";
import type { HealthKitAuthStatus, HealthMetric, MetricType } from "@/models/types";
import { startOfDay } from "@/utils/date";

type DailyValues = {
  hr: number;
  hrv: number;
  restingHR: number;
  steps: number;
  sleep: number;
};

const DAILY_VALUES: DailyValues[] = [
  { hr: 72, hrv: 42, restingHR: 59, steps: 7600, sleep: 7.1 },
  { hr: 78, hrv: 36, restingHR: 63, steps: 9400, sleep: 6.4 },
  { hr: 69, hrv: 48, restingHR: 58, steps: 6900, sleep: 7.6 },
  { hr: 81, hrv: 33, restingHR: 65, steps: 11200, sleep: 5.9 },
  { hr: 74, hrv: 40, restingHR: 61, steps: 8200, sleep: 6.8 },
  { hr: 68, hrv: 51, restingHR: 57, steps: 7200, sleep: 7.8 },
  { hr: 76, hrv: 38, restingHR: 62, steps: 9800, sleep: 6.2 }
];

export class MockHealthDataProvider implements HealthDataProvider {
  constructor(private readonly daysOfData = 7) {}

  async requestAuthorization(): Promise<void> {
    return Promise.resolve();
  }

  authorizationStatus(): HealthKitAuthStatus {
    return "authorized";
  }

  async fetchMetrics(types: MetricType[], from: Date, to: Date): Promise<HealthMetric[]> {
    return this.fixedMetrics().filter((metric) => {
      const date = new Date(metric.date);
      return types.includes(metric.type) && date >= from && date <= to;
    });
  }

  private fixedMetrics(): HealthMetric[] {
    const today = startOfDay(new Date());
    const selectedValues = DAILY_VALUES.slice(-this.daysOfData);

    return selectedValues.flatMap((values, index) => {
      const daysBack = selectedValues.length - 1 - index;
      const day = new Date(today);
      day.setDate(today.getDate() - daysBack);

      return [
        metric("heartRate", values.hr, "bpm", day, 9),
        metric("hrv", values.hrv, "ms", day, 7),
        metric("restingHeartRate", values.restingHR, "bpm", day, 6),
        metric("steps", values.steps, "steps", day, 20),
        metric("sleep", values.sleep, "hours", day, 6)
      ];
    });
  }
}

function metric(
  type: MetricType,
  value: number,
  unit: string,
  day: Date,
  hour: number
): HealthMetric {
  const date = new Date(day);
  date.setHours(hour, 0, 0, 0);

  return {
    id: `${type}-${date.toISOString()}`,
    type,
    value,
    unit,
    date: date.toISOString()
  };
}
