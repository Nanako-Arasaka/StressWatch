import { useMemo } from "react";
import { ActivityIndicator, Pressable, Text, View } from "react-native";

import { AnimatedCard } from "@/components/animated-card";
import { LineChart } from "@/components/line-chart";
import { MetricRow } from "@/components/metric-row";
import { RecoveryCard } from "@/components/recovery-card";
import { Screen } from "@/components/screen";
import { StressCard } from "@/components/stress-card";
import type { MetricType } from "@/models/types";
import { colors, radius } from "@/theme/colors";
import { useDashboardViewModel } from "@/view-models/use-dashboard-view-model";

type Props = {
  onOpenMetric: (type: MetricType) => void;
};

export function DashboardScreen({ onOpenMetric }: Props) {
  const { state, refresh } = useDashboardViewModel();
  const miniChartPoints = useMemo(
    () =>
      [...state.todayHR, ...state.todayHRV].map((metric) => ({
        label: metric.type === "heartRate" ? "HR" : "HRV",
        value: metric.value
      })),
    [state.todayHR, state.todayHRV]
  );
  const latestMetrics = useMemo(() => {
    const latest = new Map<MetricType, number>();
    for (const metric of state.allMetrics) {
      latest.set(metric.type, metric.value);
    }
    return latest;
  }, [state.allMetrics]);

  return (
    <Screen title="今日状态" subtitle="固定 mock 数据驱动的压力、恢复和健康指标概览。">
      {state.isLoading ? (
        <View style={{ minHeight: 360, alignItems: "center", justifyContent: "center" }}>
          <ActivityIndicator size="large" color={colors.indigo} />
          <Text selectable style={{ marginTop: 12, color: colors.textMuted }}>
            正在加载模拟数据
          </Text>
        </View>
      ) : state.errorMessage || state.needsMoreData ? (
        <AnimatedCard>
          <View
            style={{
              padding: 18,
              backgroundColor: colors.surface,
              borderRadius: radius.lg,
              borderWidth: 1,
              borderColor: colors.line
            }}
          >
            <Text selectable style={{ color: colors.textMuted }}>
              {state.errorMessage ?? "需要更多数据后才能生成状态"}
            </Text>
          </View>
        </AnimatedCard>
      ) : (
        <>
          <AnimatedCard delay={0}>
            <StressCard score={state.stressScore} />
          </AnimatedCard>

          <AnimatedCard delay={80}>
            <RecoveryCard score={state.recoveryScore} />
          </AnimatedCard>

          <AnimatedCard delay={140}>
            <View
              style={{
                backgroundColor: colors.surface,
                borderRadius: radius.lg,
                padding: 18,
                gap: 10,
                borderWidth: 1,
                borderColor: colors.line
              }}
            >
              <Text selectable style={{ color: colors.text, fontSize: 17, fontWeight: "800" }}>
                今日 HR / HRV
              </Text>
              <LineChart points={miniChartPoints} color={colors.teal} height={180} />
            </View>
          </AnimatedCard>

          <AnimatedCard delay={200}>
            <View style={{ gap: 10 }}>
              <MetricRow
                type="heartRate"
                value={latestMetrics.get("heartRate") ?? 0}
                onPress={() => onOpenMetric("heartRate")}
              />
              <MetricRow
                type="hrv"
                value={latestMetrics.get("hrv") ?? 0}
                onPress={() => onOpenMetric("hrv")}
              />
              <MetricRow
                type="steps"
                value={latestMetrics.get("steps") ?? 0}
                onPress={() => onOpenMetric("steps")}
              />
              <MetricRow
                type="sleep"
                value={latestMetrics.get("sleep") ?? 0}
                onPress={() => onOpenMetric("sleep")}
              />
            </View>
          </AnimatedCard>

          <Pressable
            onPress={refresh}
            style={({ pressed }) => ({
              opacity: pressed ? 0.75 : 1,
              backgroundColor: colors.text,
              borderRadius: radius.md,
              padding: 15,
              alignItems: "center"
            })}
          >
            <Text selectable style={{ color: colors.surface, fontSize: 15, fontWeight: "800" }}>
              刷新 mock 数据
            </Text>
          </Pressable>
        </>
      )}

      <Text selectable style={{ color: colors.textMuted, fontSize: 12, lineHeight: 18 }}>
        本 App 不提供医疗建议，仅用于个人健康数据可视化
      </Text>
    </Screen>
  );
}
