import AsyncStorage from "@react-native-async-storage/async-storage";

import type { Baseline, StressScore } from "@/models/types";
import { isSameDay } from "@/utils/date";

const STRESS_SCORES_KEY = "stress-watch:stress-scores";
const BASELINE_KEY = "stress-watch:baseline";

export interface LocalStorageProtocol {
  saveStressScore(score: StressScore): Promise<void>;
  fetchStressScores(from: Date, to: Date): Promise<StressScore[]>;
  saveBaseline(baseline: Baseline): Promise<void>;
  fetchBaseline(): Promise<Baseline | null>;
  deleteOldData(before: Date): Promise<void>;
}

export class LocalStorage implements LocalStorageProtocol {
  async saveStressScore(score: StressScore): Promise<void> {
    const scores = await this.loadStressScores();
    const nextScores = scores.filter((item) => !isSameDay(item.date, score.date));
    nextScores.push(score);
    nextScores.sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime());
    await AsyncStorage.setItem(STRESS_SCORES_KEY, JSON.stringify(nextScores));
  }

  async fetchStressScores(from: Date, to: Date): Promise<StressScore[]> {
    const scores = await this.loadStressScores();
    return scores
      .filter((score) => {
        const date = new Date(score.date);
        return date >= from && date <= to;
      })
      .sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime());
  }

  async saveBaseline(baseline: Baseline): Promise<void> {
    await AsyncStorage.setItem(BASELINE_KEY, JSON.stringify(baseline));
  }

  async fetchBaseline(): Promise<Baseline | null> {
    const raw = await AsyncStorage.getItem(BASELINE_KEY);
    return raw ? (JSON.parse(raw) as Baseline) : null;
  }

  async deleteOldData(before: Date): Promise<void> {
    const scores = await this.loadStressScores();
    const nextScores = scores.filter((score) => new Date(score.date) >= before);
    await AsyncStorage.setItem(STRESS_SCORES_KEY, JSON.stringify(nextScores));
  }

  private async loadStressScores(): Promise<StressScore[]> {
    const raw = await AsyncStorage.getItem(STRESS_SCORES_KEY);
    return raw ? (JSON.parse(raw) as StressScore[]) : [];
  }
}
