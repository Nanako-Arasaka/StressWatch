export type MetricType =
  | "heartRate"
  | "hrv"
  | "restingHeartRate"
  | "steps"
  | "sleep";

export type StressLevel = "low" | "medium" | "high";
export type RecoveryLevel = "poor" | "fair" | "good";
export type HealthKitAuthStatus =
  | "notDetermined"
  | "authorized"
  | "denied"
  | "unavailable";

export type HealthMetric = {
  id: string;
  type: MetricType;
  value: number;
  unit: string;
  date: string;
};

export type Baseline = {
  avgHR: number;
  avgHRV: number;
  avgRestingHR: number;
  avgDailySteps: number;
  avgSleepHours: number;
  calculatedAt: string;
  dataWindowDays: number;
};

export type StressComponents = {
  hrDeviationFactor: number;
  inverseHRVFactor: number;
  activityLoadFactor: number;
  sleepDebtFactor: number;
};

export type StressScore = {
  id: string;
  value: number;
  level: StressLevel;
  date: string;
  components: StressComponents;
};

export type RecoveryScore = {
  id: string;
  value: number;
  level: RecoveryLevel;
  date: string;
};

export type DashboardState = {
  stressScore: StressScore | null;
  recoveryScore: RecoveryScore | null;
  baseline: Baseline | null;
  todayHR: HealthMetric[];
  todayHRV: HealthMetric[];
  allMetrics: HealthMetric[];
  isLoading: boolean;
  errorMessage: string | null;
  needsMoreData: boolean;
};
