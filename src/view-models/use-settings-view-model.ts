import { useMemo, useState } from "react";
import { Platform } from "react-native";

import { runtimeConfig } from "@/config/runtime";
import { LocalStorage } from "@/storage/local-storage";

type HealthKitDebugStatus = "unchecked" | "available" | "unavailable";

type HealthKitProviderForDebug = {
  checkAvailability(): Promise<boolean>;
  requestPermissions(): Promise<boolean>;
  fetchLast7DaysSummary(): Promise<unknown[]>;
};

declare const require: (moduleName: string) => {
  HealthKitDataProvider: new () => HealthKitProviderForDebug;
};

export function useSettingsViewModel() {
  const storage = useMemo(() => new LocalStorage(), []);
  const [baselineWindowDays, setBaselineWindowDays] = useState(7);
  const [sourceRevision, setSourceRevision] = useState(0);
  const [healthKitAvailability, setHealthKitAvailability] =
    useState<HealthKitDebugStatus>("unchecked");
  const [lastError, setLastError] = useState<string | null>(runtimeConfig.lastHealthKitError);
  const [lastSummaryCount, setLastSummaryCount] = useState<number | null>(null);
  const [isCheckingHealthKit, setIsCheckingHealthKit] = useState(false);
  const useMockData = !runtimeConfig.useRealHealthKit;
  const currentDataSource = runtimeConfig.useRealHealthKit ? "Apple Health" : "Mock";

  async function clearAllData() {
    await storage.deleteOldData(new Date(8640000000000000));
  }

  async function checkHealthKitAvailability() {
    setIsCheckingHealthKit(true);
    setLastError(null);

    try {
      const provider = createDebugProvider();
      const available = await provider.checkAvailability();
      setHealthKitAvailability(available ? "available" : "unavailable");
      if (!available) {
        setLastError("HealthKit is unavailable on this device or runtime.");
      }
    } catch (error) {
      setHealthKitAvailability("unavailable");
      setLastError(messageFromError(error));
    } finally {
      setIsCheckingHealthKit(false);
    }
  }

  async function requestHealthKitPermissions() {
    setIsCheckingHealthKit(true);
    setLastError(null);

    try {
      const provider = createDebugProvider();
      const granted = await provider.requestPermissions();
      setHealthKitAvailability(granted ? "available" : "unavailable");

      if (!granted) {
        setLastError("HealthKit permission request did not complete.");
        return;
      }

      const summary = await provider.fetchLast7DaysSummary();
      setLastSummaryCount(summary.length);
    } catch (error) {
      setLastError(messageFromError(error));
    } finally {
      setIsCheckingHealthKit(false);
    }
  }

  function useAppleHealthSource() {
    runtimeConfig.useRealHealthKit = true;
    runtimeConfig.lastHealthKitError = null;
    setLastError(null);
    setSourceRevision((value) => value + 1);
  }

  function useDemoDataSource() {
    runtimeConfig.useRealHealthKit = false;
    runtimeConfig.lastHealthKitError = null;
    setLastError(null);
    setSourceRevision((value) => value + 1);
  }

  return {
    baselineWindowDays,
    setBaselineWindowDays,
    currentDataSource,
    healthKitAvailability,
    isCheckingHealthKit,
    lastError,
    lastSummaryCount,
    sourceRevision,
    useMockData,
    clearAllData,
    checkHealthKitAvailability,
    requestHealthKitPermissions,
    useAppleHealthSource,
    useDemoDataSource
  };
}

function createDebugProvider(): HealthKitProviderForDebug {
  if (Platform.OS !== "ios") {
    throw new Error("HealthKit debug tools require an iOS native runtime.");
  }

  const module = require("../data/healthkit-data-provider");
  const Provider = module?.HealthKitDataProvider;

  if (!Provider) {
    throw new Error("HealthKit native provider is unavailable.");
  }

  return new Provider();
}

function messageFromError(error: unknown): string {
  return error instanceof Error ? error.message : "Unknown HealthKit error.";
}
