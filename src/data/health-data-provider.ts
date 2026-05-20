import type { HealthKitAuthStatus, HealthMetric, MetricType } from "@/models/types";

export interface HealthDataProvider {
  requestAuthorization(): Promise<void>;
  authorizationStatus(): HealthKitAuthStatus;
  fetchMetrics(types: MetricType[], from: Date, to: Date): Promise<HealthMetric[]>;
}
