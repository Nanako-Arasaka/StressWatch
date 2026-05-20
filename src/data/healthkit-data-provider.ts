import { Platform } from "react-native";
import {
  isHealthDataAvailable,
  queryCategorySamples,
  queryQuantitySamples,
  requestAuthorization
} from "@kingstinct/react-native-healthkit";

import type { HealthDataProvider } from "@/data/health-data-provider";
import type { HealthKitAuthStatus, HealthMetric, MetricType } from "@/models/types";

type QuantityIdentifier =
  | "HKQuantityTypeIdentifierHeartRate"
  | "HKQuantityTypeIdentifierHeartRateVariabilitySDNN"
  | "HKQuantityTypeIdentifierRestingHeartRate"
  | "HKQuantityTypeIdentifierStepCount";

type HealthKitQuantitySample = {
  uuid?: string;
  quantity?: number;
  unit?: string;
  startDate?: Date | string;
  endDate?: Date | string;
};

type HealthKitCategorySample = {
  uuid?: string;
  value?: number;
  startDate?: Date | string;
  endDate?: Date | string;
};

const quantityMap: Record<Exclude<MetricType, "sleep">, QuantityIdentifier> = {
  heartRate: "HKQuantityTypeIdentifierHeartRate",
  hrv: "HKQuantityTypeIdentifierHeartRateVariabilitySDNN",
  restingHeartRate: "HKQuantityTypeIdentifierRestingHeartRate",
  steps: "HKQuantityTypeIdentifierStepCount"
};

const unitMap: Record<QuantityIdentifier, string> = {
  HKQuantityTypeIdentifierHeartRate: "count/min",
  HKQuantityTypeIdentifierHeartRateVariabilitySDNN: "ms",
  HKQuantityTypeIdentifierRestingHeartRate: "count/min",
  HKQuantityTypeIdentifierStepCount: "count"
};

export class HealthKitDataProvider implements HealthDataProvider {
  private authorized = false;

  async checkAvailability(): Promise<boolean> {
    if (Platform.OS !== "ios") {
      return false;
    }

    try {
      return await isHealthDataAvailable();
    } catch {
      return false;
    }
  }

  async requestPermissions(): Promise<boolean> {
    try {
      await this.requestAuthorization();
      return true;
    } catch {
      return false;
    }
  }

  async fetchLast7DaysSummary(): Promise<HealthMetric[]> {
    const to = new Date();
    const from = new Date(to);
    from.setDate(to.getDate() - 6);
    from.setHours(0, 0, 0, 0);

    return this.fetchMetrics(
      ["heartRate", "hrv", "restingHeartRate", "steps", "sleep"],
      from,
      to
    );
  }

  async requestAuthorization(): Promise<void> {
    if (Platform.OS !== "ios") {
      throw new Error("HealthKit is only available on iOS.");
    }

    const available = await isHealthDataAvailable();
    if (!available) {
      throw new Error("Health data is not available on this device.");
    }

    await requestAuthorization({
      toRead: [
        "HKQuantityTypeIdentifierHeartRate",
        "HKQuantityTypeIdentifierHeartRateVariabilitySDNN",
        "HKQuantityTypeIdentifierRestingHeartRate",
        "HKQuantityTypeIdentifierStepCount",
        "HKCategoryTypeIdentifierSleepAnalysis"
      ]
    });
    this.authorized = true;
  }

  authorizationStatus(): HealthKitAuthStatus {
    if (Platform.OS !== "ios") {
      return "unavailable";
    }
    return this.authorized ? "authorized" : "notDetermined";
  }

  async fetchMetrics(types: MetricType[], from: Date, to: Date): Promise<HealthMetric[]> {
    if (!this.authorized) {
      await this.requestAuthorization();
    }

    const metrics: HealthMetric[] = [];

    for (const type of types) {
      if (type === "sleep") {
        metrics.push(...(await this.fetchSleep(from, to)));
      } else {
        metrics.push(...(await this.fetchQuantity(type, from, to)));
      }
    }

    return metrics.sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime());
  }

  private async fetchQuantity(
    type: Exclude<MetricType, "sleep">,
    from: Date,
    to: Date
  ): Promise<HealthMetric[]> {
    const identifier = quantityMap[type];
    const samples = (await queryQuantitySamples(identifier, {
      limit: 200,
      ascending: true,
      unit: unitMap[identifier],
      filter: {
        date: {
          startDate: from,
          endDate: to
        }
      }
    } as never)) as readonly HealthKitQuantitySample[];

    return samples.map((sample, index) => ({
      id: sample.uuid ?? `${type}-${index}-${dateValue(sample.endDate ?? sample.startDate)}`,
      type,
      value: Number(sample.quantity ?? 0),
      unit: displayUnit(type),
      date: dateValue(sample.endDate ?? sample.startDate)
    }));
  }

  private async fetchSleep(from: Date, to: Date): Promise<HealthMetric[]> {
    const samples = (await queryCategorySamples("HKCategoryTypeIdentifierSleepAnalysis", {
      limit: 100,
      ascending: true,
      filter: {
        date: {
          startDate: from,
          endDate: to
        }
      }
    } as never)) as readonly HealthKitCategorySample[];

    return samples
      .map((sample, index) => {
        const startDate = new Date(dateValue(sample.startDate));
        const endDate = new Date(dateValue(sample.endDate));
        const hours = Math.max(0, endDate.getTime() - startDate.getTime()) / 3_600_000;

        return {
          id: sample.uuid ?? `sleep-${index}-${endDate.toISOString()}`,
          type: "sleep" as const,
          value: hours,
          unit: "hours",
          date: endDate.toISOString()
        };
      })
      .filter((metric) => metric.value > 0);
  }
}

function displayUnit(type: MetricType): string {
  switch (type) {
    case "heartRate":
    case "restingHeartRate":
      return "bpm";
    case "hrv":
      return "ms";
    case "steps":
      return "steps";
    case "sleep":
      return "hours";
  }
}

function dateValue(value: Date | string | undefined): string {
  if (!value) {
    return new Date().toISOString();
  }
  return value instanceof Date ? value.toISOString() : new Date(value).toISOString();
}
