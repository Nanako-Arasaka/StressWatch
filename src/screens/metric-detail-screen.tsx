import { useEffect, useState } from "react";
import { Text, View } from "react-native";

import { AnimatedCard } from "@/components/animated-card";
import { LineChart } from "@/components/line-chart";
import { Screen } from "@/components/screen";
import { MockHealthDataProvider } from "@/data/mock-health-data-provider";
import type { HealthMetric, MetricType } from "@/models/types";
import { colors, radius } from "@/theme/colors";
import { daysAgo, endOfDay, formatShortDate } from "@/utils/date";
import { metricLabel, metricUnit } from "@/utils/format";

type Props = {
  metricType: MetricType;
};

export function MetricDetailScreen({ metricType }: Props) {
  const metrics = useMockMetrics(metricType);
  const points = metrics.map((metric) => ({
    label: formatShortDate(metric.date),
    value: metric.value
  }));
  const latest = metrics[metrics.length - 1];

  return (
    <Screen title={metricLabel(metricType)} subtitle="固定 mock 数据的 7 天指标走势。">
      <AnimatedCard>
        <View
          style={{
            backgroundColor: colors.surface,
            borderRadius: radius.xl,
            padding: 18,
            gap: 12,
            borderWidth: 1,
            borderColor: colors.line
          }}
        >
          <View style={{ flexDirection: "row", justifyContent: "space-between", alignItems: "flex-end" }}>
            <Text selectable style={{ color: colors.text, fontSize: 18, fontWeight: "800" }}>
              指标趋势
            </Text>
            <Text
              selectable
              style={{ color: colors.text, fontSize: 28, fontWeight: "900", fontVariant: ["tabular-nums"] }}
            >
              {latest ? Math.round(latest.value) : 0}
              <Text style={{ color: colors.textMuted, fontSize: 12 }}> {metricUnit(metricType)}</Text>
            </Text>
          </View>
          <LineChart points={points} color={colors.indigo} height={240} />
        </View>
      </AnimatedCard>
    </Screen>
  );
}

function useMockMetrics(metricType: MetricType): HealthMetric[] {
  const [metrics, setMetrics] = useState<HealthMetric[]>([]);

  useEffect(() => {
    let isActive = true;
    const provider = new MockHealthDataProvider();

    provider
      .fetchMetrics([metricType], daysAgo(6), endOfDay(new Date()))
      .then((nextMetrics) => {
        if (isActive) {
          setMetrics(nextMetrics);
        }
      })
      .catch(() => {
        if (isActive) {
          setMetrics([]);
        }
      });

    return () => {
      isActive = false;
    };
  }, [metricType]);

  return metrics;
}
