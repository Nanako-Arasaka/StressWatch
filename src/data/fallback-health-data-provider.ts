import type { HealthDataProvider } from "@/data/health-data-provider";
import type { HealthKitAuthStatus, HealthMetric, MetricType } from "@/models/types";

export class FallbackHealthDataProvider implements HealthDataProvider {
  private usingFallback = false;

  constructor(
    private readonly primary: HealthDataProvider,
    private readonly fallback: HealthDataProvider
  ) {}

  async requestAuthorization(): Promise<void> {
    try {
      await this.primary.requestAuthorization();
      this.usingFallback = false;
    } catch {
      this.usingFallback = true;
      await this.fallback.requestAuthorization();
    }
  }

  authorizationStatus(): HealthKitAuthStatus {
    return this.usingFallback
      ? this.fallback.authorizationStatus()
      : this.primary.authorizationStatus();
  }

  async fetchMetrics(types: MetricType[], from: Date, to: Date): Promise<HealthMetric[]> {
    try {
      if (!this.usingFallback) {
        const metrics = await this.primary.fetchMetrics(types, from, to);
        if (metrics.length > 0) {
          return metrics;
        }
      }
    } catch {
      this.usingFallback = true;
    }

    return this.fallback.fetchMetrics(types, from, to);
  }
}
