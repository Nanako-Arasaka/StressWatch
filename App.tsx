import { useState } from "react";
import { Pressable, StatusBar, Text, View } from "react-native";

import { DashboardScreen } from "@/screens/dashboard-screen";
import { MetricDetailScreen } from "@/screens/metric-detail-screen";
import { SettingsScreen } from "@/screens/settings-screen";
import { TrendScreen } from "@/screens/trend-screen";
import { colors } from "@/theme/colors";
import type { MetricType } from "@/models/types";

type Tab = "dashboard" | "trend" | "settings";

export default function App() {
  const [tab, setTab] = useState<Tab>("dashboard");
  const [selectedMetric, setSelectedMetric] = useState<MetricType | null>(null);

  if (selectedMetric) {
    return (
      <View style={{ flex: 1, backgroundColor: colors.background }}>
        <StatusBar barStyle="dark-content" />
        <MetricDetailScreen metricType={selectedMetric} />
        <BottomAction label="返回" onPress={() => setSelectedMetric(null)} />
      </View>
    );
  }

  return (
    <View style={{ flex: 1, backgroundColor: colors.background }}>
      <StatusBar barStyle="dark-content" />
      {tab === "dashboard" ? <DashboardScreen onOpenMetric={setSelectedMetric} /> : null}
      {tab === "trend" ? <TrendScreen /> : null}
      {tab === "settings" ? <SettingsScreen /> : null}
      <TabBar value={tab} onChange={setTab} />
    </View>
  );
}

function TabBar({ value, onChange }: { value: Tab; onChange: (tab: Tab) => void }) {
  return (
    <View
      style={{
        position: "absolute",
        left: 16,
        right: 16,
        bottom: 22,
        backgroundColor: "rgba(255,255,255,0.96)",
        borderRadius: 24,
        padding: 8,
        flexDirection: "row",
        gap: 6,
        borderWidth: 1,
        borderColor: colors.line,
        boxShadow: "0 14px 34px rgba(15, 23, 42, 0.18)"
      }}
    >
      <TabButton label="今日" selected={value === "dashboard"} onPress={() => onChange("dashboard")} />
      <TabButton label="趋势" selected={value === "trend"} onPress={() => onChange("trend")} />
      <TabButton label="设置" selected={value === "settings"} onPress={() => onChange("settings")} />
    </View>
  );
}

function TabButton({
  label,
  selected,
  onPress
}: {
  label: string;
  selected: boolean;
  onPress: () => void;
}) {
  return (
    <Pressable
      onPress={onPress}
      style={({ pressed }) => ({
        flex: 1,
        opacity: pressed ? 0.75 : 1,
        paddingVertical: 12,
        borderRadius: 18,
        alignItems: "center",
        backgroundColor: selected ? colors.text : "transparent"
      })}
    >
      <Text selectable style={{ color: selected ? colors.surface : colors.textMuted, fontWeight: "800" }}>
        {label}
      </Text>
    </Pressable>
  );
}

function BottomAction({ label, onPress }: { label: string; onPress: () => void }) {
  return (
    <Pressable
      onPress={onPress}
      style={({ pressed }) => ({
        position: "absolute",
        left: 20,
        right: 20,
        bottom: 22,
        opacity: pressed ? 0.75 : 1,
        backgroundColor: colors.text,
        borderRadius: 18,
        padding: 15,
        alignItems: "center"
      })}
    >
      <Text selectable style={{ color: colors.surface, fontSize: 15, fontWeight: "800" }}>
        {label}
      </Text>
    </Pressable>
  );
}
