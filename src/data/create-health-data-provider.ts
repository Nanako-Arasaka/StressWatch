import { Platform } from "react-native";

import { FallbackHealthDataProvider } from "@/data/fallback-health-data-provider";
import type { HealthDataProvider } from "@/data/health-data-provider";
import { MockHealthDataProvider } from "@/data/mock-health-data-provider";
import { runtimeConfig } from "@/config/runtime";

declare const require: (moduleName: string) => {
  HealthKitDataProvider: new () => HealthDataProvider;
};

export function createHealthDataProvider(): HealthDataProvider {
  const mockProvider = new MockHealthDataProvider();

  if (!runtimeConfig.useRealHealthKit) {
    return mockProvider;
  }

  if (Platform.OS !== "ios") {
    runtimeConfig.lastHealthKitError = "HealthKit only runs on iOS native builds.";
    return mockProvider;
  }

  try {
    const module = require("./healthkit-data-provider");
    const Provider = module?.HealthKitDataProvider;

    if (!Provider) {
      runtimeConfig.lastHealthKitError = "HealthKit native provider module is unavailable.";
      return mockProvider;
    }

    return new FallbackHealthDataProvider(new Provider(), mockProvider);
  } catch (error) {
    runtimeConfig.lastHealthKitError =
      error instanceof Error ? error.message : "Failed to load HealthKit native module.";
    return mockProvider;
  }
}
