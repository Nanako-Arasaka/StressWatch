import { Text, View } from "react-native";

import type { RecoveryLevel, RecoveryScore } from "@/models/types";
import { colors, radius } from "@/theme/colors";
import { recoveryLevelLabel } from "@/utils/format";

type Props = {
  score: RecoveryScore | null;
};

export function RecoveryCard({ score }: Props) {
  const color = recoveryColor(score?.level);

  return (
    <View
      style={{
        backgroundColor: colors.surface,
        borderRadius: radius.lg,
        padding: 18,
        borderWidth: 1,
        borderColor: colors.line,
        flexDirection: "row",
        alignItems: "center",
        justifyContent: "space-between",
        boxShadow: "0 8px 20px rgba(15, 23, 42, 0.06)"
      }}
    >
      <View style={{ gap: 6 }}>
        <Text selectable style={{ color: colors.text, fontSize: 17, fontWeight: "800" }}>
          恢复分
        </Text>
        <Text selectable style={{ color: colors.textMuted, fontSize: 13 }}>
          {recoveryLevelLabel(score?.level)}
        </Text>
      </View>
      <Text
        selectable
        style={{
          color,
          fontSize: 38,
          fontWeight: "900",
          fontVariant: ["tabular-nums"]
        }}
      >
        {score?.value ?? 0}
      </Text>
    </View>
  );
}

function recoveryColor(level: RecoveryLevel | null | undefined): string {
  if (level === "poor") {
    return colors.red;
  }
  if (level === "fair") {
    return colors.orange;
  }
  if (level === "good") {
    return colors.green;
  }
  return colors.textMuted;
}
