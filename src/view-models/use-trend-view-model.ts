import { useCallback, useEffect, useMemo, useState } from "react";

import { MockHealthDataProvider } from "@/data/mock-health-data-provider";
import type { StressScore } from "@/models/types";
import { BaselineEngine } from "@/services/baseline-calculator";
import { StressModel } from "@/services/stress-calculator";
import { LocalStorage } from "@/storage/local-storage";
import { daysAgo, endOfDay, isSameDay } from "@/utils/date";

export function useTrendViewModel(days = 7) {
  const storage = useMemo(() => new LocalStorage(), []);
  const [stressHistory, setStressHistory] = useState<StressScore[]>([]);
  const [isLoading, setIsLoading] = useState(false);

  const loadHistory = useCallback(async () => {
    setIsLoading(true);
    try {
      const now = new Date();
      const from = daysAgo(days - 1, now);
      const to = endOfDay(now);
      let scores = await storage.fetchStressScores(from, to);

      if (scores.length === 0) {
        scores = await seedMockTrend(days, storage);
      }

      setStressHistory(scores);
    } finally {
      setIsLoading(false);
    }
  }, [days, storage]);

  useEffect(() => {
    loadHistory();
  }, [loadHistory]);

  return {
    stressHistory,
    isLoading,
    loadHistory
  };
}

async function seedMockTrend(days: number, storage: LocalStorage): Promise<StressScore[]> {
  const provider = new MockHealthDataProvider(days);
  const metrics = await provider.fetchMetrics(
    ["heartRate", "hrv", "restingHeartRate", "steps", "sleep"],
    daysAgo(days - 1),
    endOfDay(new Date())
  );
  const baseline = new BaselineEngine().calculate(metrics);

  if (!baseline) {
    return [];
  }

  const stressModel = new StressModel();
  const scores: StressScore[] = [];

  for (const metric of metrics) {
    const dayMetrics = metrics.filter((candidate) => isSameDay(candidate.date, metric.date));
    if (scores.some((score) => isSameDay(score.date, metric.date))) {
      continue;
    }

    const score = stressModel.compute(dayMetrics, baseline);
    await storage.saveStressScore(score);
    scores.push(score);
  }

  return scores.sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime());
}
