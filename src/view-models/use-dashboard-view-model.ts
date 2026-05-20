import { useCallback, useEffect, useMemo, useState } from "react";

import { createHealthDataProvider } from "@/data/create-health-data-provider";
import type { DashboardState, HealthMetric } from "@/models/types";
import { BaselineEngine } from "@/services/baseline-calculator";
import { RecoveryModel } from "@/services/recovery-calculator";
import { StressModel } from "@/services/stress-calculator";
import { LocalStorage } from "@/storage/local-storage";
import { daysAgo, endOfDay, isSameDay } from "@/utils/date";

const initialState: DashboardState = {
  stressScore: null,
  recoveryScore: null,
  baseline: null,
  todayHR: [],
  todayHRV: [],
  allMetrics: [],
  isLoading: false,
  errorMessage: null,
  needsMoreData: false
};

export function useDashboardViewModel() {
  const dependencies = useMemo(
    () => ({
      healthDataProvider: createHealthDataProvider(),
      baselineEngine: new BaselineEngine(),
      stressModel: new StressModel(),
      recoveryModel: new RecoveryModel(),
      storage: new LocalStorage()
    }),
    []
  );
  const [state, setState] = useState<DashboardState>(initialState);

  const refresh = useCallback(async () => {
    setState((current) => ({
      ...current,
      isLoading: true,
      errorMessage: null,
      needsMoreData: false
    }));

    try {
      await dependencies.healthDataProvider.requestAuthorization();
      const now = new Date();
      const metrics = await dependencies.healthDataProvider.fetchMetrics(
        ["heartRate", "hrv", "restingHeartRate", "steps", "sleep"],
        daysAgo(6, now),
        endOfDay(now)
      );
      const baseline = dependencies.baselineEngine.calculate(metrics);

      if (!baseline || baseline.dataWindowDays < 3) {
        setState((current) => ({
          ...current,
          baseline: null,
          needsMoreData: true,
          isLoading: false
        }));
        return;
      }

      const todayMetrics = metricsForDay(now, metrics);
      const stressScore = dependencies.stressModel.compute(todayMetrics, baseline);
      const recoveryScore = dependencies.recoveryModel.compute(todayMetrics, baseline);

      await dependencies.storage.saveBaseline(baseline);
      await saveTrendScores(metrics, baseline, dependencies.stressModel, dependencies.storage);

      setState({
        stressScore,
        recoveryScore,
        baseline,
        todayHR: todayMetrics.filter((metric) => metric.type === "heartRate"),
        todayHRV: todayMetrics.filter((metric) => metric.type === "hrv"),
        allMetrics: metrics,
        isLoading: false,
        errorMessage: null,
        needsMoreData: false
      });
    } catch {
      setState((current) => ({
        ...current,
        isLoading: false,
        errorMessage: "无法加载模拟数据"
      }));
    }
  }, [dependencies]);

  useEffect(() => {
    refresh();
  }, [refresh]);

  return {
    state,
    refresh
  };
}

function metricsForDay(date: Date, metrics: HealthMetric[]): HealthMetric[] {
  return metrics.filter((metric) => isSameDay(metric.date, date));
}

async function saveTrendScores(
  metrics: HealthMetric[],
  baseline: NonNullable<DashboardState["baseline"]>,
  stressModel: StressModel,
  storage: LocalStorage
) {
  const groups = new Map<string, HealthMetric[]>();

  for (const metric of metrics) {
    const key = new Date(metric.date).toDateString();
    groups.set(key, [...(groups.get(key) ?? []), metric]);
  }

  for (const dayMetrics of groups.values()) {
    await storage.saveStressScore(stressModel.compute(dayMetrics, baseline));
  }
}
