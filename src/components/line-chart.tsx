import { Text, View } from "react-native";
import Svg, { Circle, Line, Path, Text as SvgText } from "react-native-svg";

import { colors } from "@/theme/colors";

type ChartPoint = {
  label: string;
  value: number;
};

type Props = {
  points: ChartPoint[];
  color?: string;
  height?: number;
  min?: number;
  max?: number;
};

export function LineChart({
  points,
  color = colors.blue,
  height = 220,
  min,
  max
}: Props) {
  if (points.length === 0) {
    return (
      <View style={{ height, alignItems: "center", justifyContent: "center" }}>
        <Text selectable style={{ color: colors.textMuted }}>
          暂无图表数据
        </Text>
      </View>
    );
  }

  const width = 320;
  const padding = 28;
  const values = points.map((point) => point.value);
  const yMin = min ?? Math.min(...values);
  const yMax = max ?? Math.max(...values);
  const range = Math.max(yMax - yMin, 1);
  const plotWidth = width - padding * 2;
  const plotHeight = height - padding * 2;

  const coordinates = points.map((point, index) => {
    const x = padding + (plotWidth / Math.max(points.length - 1, 1)) * index;
    const y = padding + plotHeight - ((point.value - yMin) / range) * plotHeight;
    return { ...point, x, y };
  });
  const path = coordinates
    .map((point, index) => `${index === 0 ? "M" : "L"} ${point.x} ${point.y}`)
    .join(" ");

  return (
    <View style={{ width: "100%", alignItems: "center" }}>
      <Svg width="100%" height={height} viewBox={`0 0 ${width} ${height}`}>
        {[0, 1, 2].map((line) => {
          const y = padding + (plotHeight / 2) * line;
          return (
            <Line
              key={line}
              x1={padding}
              y1={y}
              x2={width - padding}
              y2={y}
              stroke={colors.line}
              strokeWidth={1}
            />
          );
        })}
        <Path d={path} fill="none" stroke={color} strokeWidth={4} strokeLinecap="round" />
        {coordinates.map((point) => (
          <Circle
            key={`${point.label}-${point.value}`}
            cx={point.x}
            cy={point.y}
            r={5}
            fill={colors.surface}
            stroke={color}
            strokeWidth={3}
          />
        ))}
        {coordinates.map((point, index) =>
          index % Math.ceil(points.length / 4) === 0 || index === points.length - 1 ? (
            <SvgText
              key={point.label}
              x={point.x}
              y={height - 8}
              fill={colors.textMuted}
              fontSize="10"
              textAnchor="middle"
            >
              {point.label}
            </SvgText>
          ) : null
        )}
      </Svg>
    </View>
  );
}
