import type {
  Baseline,
  HealthMetric,
  MetricType,
  RecoveryLevel,
  RecoveryScore
} from "@/models/types";

export interface RecoveryCalculator {
  compute(current: HealthMetric[], baseline: Baseline): RecoveryScore;
}

export class RecoveryModel implements RecoveryCalculator {
  compute(current: HealthMetric[], baseline: Baseline): RecoveryScore {
    const currentHRV = latestValue("hrv", current) ?? baseline.avgHRV;
    const currentRestingHR =
      latestValue("restingHeartRate", current) ?? baseline.avgRestingHR;
    const currentSleep = latestValue("sleep", current) ?? baseline.avgSleepHours;

    const hrvScore = clamp((currentHRV / safeDenominator(baseline.avgHRV)) * 40, 0, 40);
    const restingHRScore = clamp(
      (baseline.avgRestingHR / safeDenominator(currentRestingHR)) * 30,
      0,
      30
    );
    const sleepScore = clamp(
      (currentSleep / safeDenominator(baseline.avgSleepHours)) * 30,
      0,
      30
    );
    const value = Math.max(0, Math.min(100, Math.round(hrvScore + restingHRScore + sleepScore)));
    const sortedDates = current.map((metric) => metric.date).sort();
    const date = sortedDates[sortedDates.length - 1] ?? new Date().toISOString();

    return {
      id: `recovery-${date}`,
      value,
      level: recoveryLevel(value),
      date
    };
  }
}

function latestValue(type: MetricType, metrics: HealthMetric[]): number | null {
  return (
    metrics
      .filter((metric) => metric.type === type)
      .sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime())[0]?.value ?? null
  );
}

function recoveryLevel(value: number): RecoveryLevel {
  if (value <= 33) {
    return "poor";
  }
  if (value <= 66) {
    return "fair";
  }
  return "good";
}

function safeDenominator(value: number): number {
  return Math.max(value, 0.0001);
}

function clamp(value: number, minValue: number, maxValue: number): number {
  return Math.min(Math.max(value, minValue), maxValue);
}
