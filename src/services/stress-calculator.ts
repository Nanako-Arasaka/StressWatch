import type {
  Baseline,
  HealthMetric,
  MetricType,
  StressLevel,
  StressScore
} from "@/models/types";

export interface StressCalculator {
  compute(current: HealthMetric[], baseline: Baseline): StressScore;
}

export class StressModel implements StressCalculator {
  compute(current: HealthMetric[], baseline: Baseline): StressScore {
    const currentHR = latestValue("heartRate", current) ?? baseline.avgHR;
    const currentHRV = latestValue("hrv", current) ?? baseline.avgHRV;
    const currentSteps = latestValue("steps", current) ?? baseline.avgDailySteps;
    const currentSleep = latestValue("sleep", current) ?? baseline.avgSleepHours;

    const hrDeviationFactor = clamp(
      ((currentHR - baseline.avgHR) / safeDenominator(baseline.avgHR)) * 100,
      0,
      25
    );
    const inverseHRVFactor = clamp(
      ((baseline.avgHRV - currentHRV) / safeDenominator(baseline.avgHRV)) * 100,
      0,
      25
    );
    const activityLoadFactor = clamp(
      (Math.abs(currentSteps - baseline.avgDailySteps) /
        safeDenominator(baseline.avgDailySteps)) *
        50,
      0,
      25
    );
    const sleepDebtFactor = clamp(
      ((baseline.avgSleepHours - currentSleep) / safeDenominator(baseline.avgSleepHours)) * 100,
      0,
      25
    );

    const value = Math.max(
      0,
      Math.min(
        100,
        Math.round(hrDeviationFactor + inverseHRVFactor + activityLoadFactor + sleepDebtFactor)
      )
    );
    const sortedDates = current.map((metric) => metric.date).sort();
    const date = sortedDates[sortedDates.length - 1] ?? new Date().toISOString();

    return {
      id: `stress-${date}`,
      value,
      level: stressLevel(value),
      date,
      components: {
        hrDeviationFactor,
        inverseHRVFactor,
        activityLoadFactor,
        sleepDebtFactor
      }
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

function stressLevel(value: number): StressLevel {
  if (value <= 33) {
    return "low";
  }
  if (value <= 66) {
    return "medium";
  }
  return "high";
}

function safeDenominator(value: number): number {
  return Math.max(value, 0.0001);
}

function clamp(value: number, minValue: number, maxValue: number): number {
  return Math.min(Math.max(value, minValue), maxValue);
}
