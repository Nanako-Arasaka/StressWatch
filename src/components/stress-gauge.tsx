import { useEffect, useRef } from "react";
import { Animated, Text, View } from "react-native";
import Svg, { Circle } from "react-native-svg";

import type { StressLevel } from "@/models/types";
import { colors } from "@/theme/colors";

const AnimatedCircle = Animated.createAnimatedComponent(Circle);
const SIZE = 172;
const STROKE_WIDTH = 16;
const RADIUS = (SIZE - STROKE_WIDTH) / 2;
const CIRCUMFERENCE = 2 * Math.PI * RADIUS;

type Props = {
  value: number;
  level: StressLevel | null;
};

export function StressGauge({ value, level }: Props) {
  const progress = useRef(new Animated.Value(0)).current;
  const clamped = Math.max(0, Math.min(100, value));
  const strokeColor = levelColor(level);

  useEffect(() => {
    Animated.timing(progress, {
      toValue: clamped,
      duration: 760,
      useNativeDriver: false
    }).start();
  }, [clamped, progress]);

  const strokeDashoffset = progress.interpolate({
    inputRange: [0, 100],
    outputRange: [CIRCUMFERENCE, 0]
  });

  return (
    <View style={{ alignItems: "center", justifyContent: "center" }}>
      <Svg width={SIZE} height={SIZE} viewBox={`0 0 ${SIZE} ${SIZE}`}>
        <Circle
          cx={SIZE / 2}
          cy={SIZE / 2}
          r={RADIUS}
          stroke={colors.surfaceMuted}
          strokeWidth={STROKE_WIDTH}
          fill="transparent"
        />
        <AnimatedCircle
          cx={SIZE / 2}
          cy={SIZE / 2}
          r={RADIUS}
          stroke={strokeColor}
          strokeWidth={STROKE_WIDTH}
          fill="transparent"
          strokeLinecap="round"
          strokeDasharray={`${CIRCUMFERENCE} ${CIRCUMFERENCE}`}
          strokeDashoffset={strokeDashoffset}
          rotation="-90"
          origin={`${SIZE / 2}, ${SIZE / 2}`}
        />
      </Svg>
      <View style={{ position: "absolute", alignItems: "center", gap: 2 }}>
        <Text
          selectable
          style={{
            color: colors.text,
            fontSize: 44,
            fontWeight: "900",
            fontVariant: ["tabular-nums"]
          }}
        >
          {clamped}
        </Text>
        <Text selectable style={{ color: colors.textMuted, fontSize: 13, fontWeight: "700" }}>
          压力分
        </Text>
      </View>
    </View>
  );
}

export function levelColor(level: StressLevel | null | undefined): string {
  if (level === "low") {
    return colors.green;
  }
  if (level === "medium") {
    return colors.orange;
  }
  if (level === "high") {
    return colors.red;
  }
  return colors.textMuted;
}
