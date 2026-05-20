import { Pressable, Text, View } from "react-native";

import type { MetricType } from "@/models/types";
import { colors, radius } from "@/theme/colors";
import { metricLabel, metricUnit } from "@/utils/format";

type Props = {
  type: MetricType;
  value: number;
  onPress: () => void;
};

export function MetricRow({ type, value, onPress }: Props) {
  return (
    <Pressable
      onPress={onPress}
      style={({ pressed }) => ({
        opacity: pressed ? 0.72 : 1,
        backgroundColor: colors.surface,
        borderRadius: radius.md,
        padding: 14,
        borderWidth: 1,
        borderColor: colors.line,
        flexDirection: "row",
        alignItems: "center",
        justifyContent: "space-between"
      })}
    >
      <View style={{ gap: 3 }}>
        <Text selectable style={{ color: colors.text, fontSize: 15, fontWeight: "700" }}>
          {metricLabel(type)}
        </Text>
        <Text selectable style={{ color: colors.textMuted, fontSize: 12 }}>
          查看指标详情
        </Text>
      </View>
      <Text
        selectable
        style={{
          color: colors.text,
          fontSize: 20,
          fontWeight: "800",
          fontVariant: ["tabular-nums"]
        }}
      >
        {Math.round(value)}
        <Text style={{ color: colors.textMuted, fontSize: 12 }}> {metricUnit(type)}</Text>
      </Text>
    </Pressable>
  );
}
