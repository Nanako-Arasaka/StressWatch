import { Text, View } from "react-native";

import { StressGauge, levelColor } from "@/components/stress-gauge";
import type { StressScore } from "@/models/types";
import { colors, radius } from "@/theme/colors";
import { stressLevelLabel } from "@/utils/format";

type Props = {
  score: StressScore | null;
};

export function StressCard({ score }: Props) {
  const value = score?.value ?? 0;
  const color = levelColor(score?.level);

  return (
    <View
      style={{
        backgroundColor: colors.surface,
        borderRadius: radius.xl,
        padding: 20,
        gap: 16,
        borderWidth: 1,
        borderColor: colors.line,
        boxShadow: "0 12px 28px rgba(15, 23, 42, 0.08)"
      }}
    >
      <View style={{ flexDirection: "row", justifyContent: "space-between", alignItems: "center" }}>
        <Text selectable style={{ color: colors.text, fontSize: 18, fontWeight: "800" }}>
          压力分
        </Text>
        <Text selectable style={{ color, fontSize: 15, fontWeight: "800" }}>
          {stressLevelLabel(score?.level)}
        </Text>
      </View>

      <StressGauge value={value} level={score?.level ?? null} />

      {score ? (
        <View style={{ gap: 10 }}>
          <Factor label="HR 偏差" value={score.components.hrDeviationFactor} color={color} />
          <Factor label="HRV 波动" value={score.components.inverseHRVFactor} color={color} />
          <Factor label="活动负荷" value={score.components.activityLoadFactor} color={color} />
          <Factor label="睡眠负债" value={score.components.sleepDebtFactor} color={color} />
        </View>
      ) : null}
    </View>
  );
}

function Factor({ label, value, color }: { label: string; value: number; color: string }) {
  const width = `${Math.max(4, Math.min(100, (value / 25) * 100))}%`;

  return (
    <View style={{ gap: 6 }}>
      <View style={{ flexDirection: "row", justifyContent: "space-between" }}>
        <Text selectable style={{ color: colors.textMuted, fontSize: 12, fontWeight: "700" }}>
          {label}
        </Text>
        <Text
          selectable
          style={{ color: colors.text, fontSize: 12, fontWeight: "800", fontVariant: ["tabular-nums"] }}
        >
          {Math.round(value)}
        </Text>
      </View>
      <View style={{ height: 8, backgroundColor: colors.surfaceMuted, borderRadius: 999 }}>
        <View style={{ height: 8, width, backgroundColor: color, borderRadius: 999 }} />
      </View>
    </View>
  );
}
