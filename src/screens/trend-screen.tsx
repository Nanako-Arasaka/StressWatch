import { useMemo } from "react";
import { ActivityIndicator, Text, View } from "react-native";

import { AnimatedCard } from "@/components/animated-card";
import { LineChart } from "@/components/line-chart";
import { Screen } from "@/components/screen";
import { colors, radius } from "@/theme/colors";
import { formatShortDate } from "@/utils/date";
import { stressLevelLabel } from "@/utils/format";
import { useTrendViewModel } from "@/view-models/use-trend-view-model";

export function TrendScreen() {
  const { stressHistory, isLoading } = useTrendViewModel(7);
  const points = useMemo(
    () =>
      stressHistory.map((score) => ({
        label: formatShortDate(score.date),
        value: score.value
      })),
    [stressHistory]
  );

  return (
    <Screen title="趋势" subtitle="7 天压力分变化，数据来自本地 AsyncStorage。">
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
          <Text selectable style={{ color: colors.text, fontSize: 18, fontWeight: "800" }}>
            7 天压力趋势
          </Text>
          {isLoading ? (
            <View style={{ height: 240, alignItems: "center", justifyContent: "center" }}>
              <ActivityIndicator color={colors.indigo} />
            </View>
          ) : (
            <LineChart points={points} color={colors.orange} height={240} min={0} max={100} />
          )}
        </View>
      </AnimatedCard>

      <AnimatedCard delay={90}>
        <View
          style={{
            backgroundColor: colors.surface,
            borderRadius: radius.lg,
            padding: 16,
            gap: 10,
            borderWidth: 1,
            borderColor: colors.line
          }}
        >
          <Text selectable style={{ color: colors.text, fontSize: 17, fontWeight: "800" }}>
            每日记录
          </Text>
          {stressHistory.map((score) => (
            <View
              key={score.id}
              style={{
                flexDirection: "row",
                justifyContent: "space-between",
                paddingVertical: 8,
                borderTopWidth: 1,
                borderTopColor: colors.line
              }}
            >
              <Text selectable style={{ color: colors.textMuted, fontSize: 14 }}>
                {formatShortDate(score.date)}
              </Text>
              <Text
                selectable
                style={{ color: colors.text, fontSize: 14, fontWeight: "800" }}
              >
                {score.value} / {stressLevelLabel(score.level)}
              </Text>
            </View>
          ))}
        </View>
      </AnimatedCard>
    </Screen>
  );
}
