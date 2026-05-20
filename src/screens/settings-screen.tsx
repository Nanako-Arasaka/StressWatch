import { Pressable, Switch, Text, View } from "react-native";

import { AnimatedCard } from "@/components/animated-card";
import { Screen } from "@/components/screen";
import { colors, radius } from "@/theme/colors";
import { useSettingsViewModel } from "@/view-models/use-settings-view-model";

const WINDOWS = [7, 14, 30];

export function SettingsScreen() {
  const {
    baselineWindowDays,
    setBaselineWindowDays,
    checkHealthKitAvailability,
    currentDataSource,
    healthKitAvailability,
    isCheckingHealthKit,
    lastError,
    lastSummaryCount,
    requestHealthKitPermissions,
    useAppleHealthSource,
    useDemoDataSource,
    useMockData
  } = useSettingsViewModel();

  return (
    <Screen title="设置" subtitle="当前阶段只启用 mock 数据和本地存储。">
      <AnimatedCard>
        <View
          style={{
            backgroundColor: colors.surface,
            borderRadius: radius.lg,
            padding: 16,
            gap: 16,
            borderWidth: 1,
            borderColor: colors.line
          }}
        >
          <View style={{ flexDirection: "row", alignItems: "center", justifyContent: "space-between" }}>
            <View style={{ gap: 4 }}>
              <Text selectable style={{ color: colors.text, fontSize: 16, fontWeight: "800" }}>
                使用 mock 数据
              </Text>
              <Text selectable style={{ color: colors.textMuted, fontSize: 13 }}>
                Expo Go 预览无需 HealthKit
              </Text>
            </View>
            <Switch value={useMockData} disabled />
          </View>
        </View>
      </AnimatedCard>

      <AnimatedCard delay={80}>
        <View
          style={{
            backgroundColor: colors.surface,
            borderRadius: radius.lg,
            padding: 16,
            gap: 12,
            borderWidth: 1,
            borderColor: colors.line
          }}
        >
          <Text selectable style={{ color: colors.text, fontSize: 16, fontWeight: "800" }}>
            基线窗口
          </Text>
          <View style={{ flexDirection: "row", gap: 8 }}>
            {WINDOWS.map((days) => {
              const selected = days === baselineWindowDays;
              return (
                <Pressable
                  key={days}
                  onPress={() => setBaselineWindowDays(days)}
                  style={{
                    flex: 1,
                    paddingVertical: 12,
                    borderRadius: radius.md,
                    alignItems: "center",
                    backgroundColor: selected ? colors.text : colors.surfaceMuted
                  }}
                >
                  <Text
                    selectable
                    style={{
                      color: selected ? colors.surface : colors.text,
                      fontWeight: "800"
                    }}
                  >
                    {days} 天
                  </Text>
                </Pressable>
              );
            })}
          </View>
        </View>
      </AnimatedCard>

      <AnimatedCard delay={140}>
        <View
          style={{
            backgroundColor: colors.surface,
            borderRadius: radius.lg,
            padding: 16,
            gap: 12,
            borderWidth: 1,
            borderColor: colors.line
          }}
        >
          <Text selectable style={{ color: colors.text, fontSize: 16, fontWeight: "800" }}>
            HealthKit 调试
          </Text>

          <DebugRow label="当前数据源" value={currentDataSource} />
          <DebugRow label="HealthKit availability" value={availabilityLabel(healthKitAvailability)} />
          <DebugRow
            label="最近 7 天样本"
            value={lastSummaryCount === null ? "未读取" : `${lastSummaryCount}`}
          />

          <View style={{ gap: 8 }}>
            <DebugButton
              label={isCheckingHealthKit ? "检查中..." : "检查 HealthKit 可用性"}
              onPress={checkHealthKitAvailability}
              disabled={isCheckingHealthKit}
            />
            <DebugButton
              label="请求 HealthKit 权限"
              onPress={requestHealthKitPermissions}
              disabled={isCheckingHealthKit}
            />
            <DebugButton label="切换到 Apple Health" onPress={useAppleHealthSource} />
            <DebugButton label="回到 Demo Data" onPress={useDemoDataSource} muted />
          </View>

          {lastError ? (
            <Text selectable style={{ color: colors.red, fontSize: 12, lineHeight: 18 }}>
              {lastError}
            </Text>
          ) : null}
        </View>
      </AnimatedCard>

      <Text selectable style={{ color: colors.textMuted, fontSize: 12, lineHeight: 18 }}>
        本 App 不提供医疗建议，仅用于个人健康数据可视化
      </Text>
    </Screen>
  );
}

function DebugRow({ label, value }: { label: string; value: string }) {
  return (
    <View style={{ flexDirection: "row", justifyContent: "space-between", gap: 12 }}>
      <Text selectable style={{ color: colors.textMuted, fontSize: 13 }}>
        {label}
      </Text>
      <Text selectable style={{ color: colors.text, fontSize: 13, fontWeight: "800" }}>
        {value}
      </Text>
    </View>
  );
}

function DebugButton({
  label,
  onPress,
  disabled = false,
  muted = false
}: {
  label: string;
  onPress: () => void;
  disabled?: boolean;
  muted?: boolean;
}) {
  return (
    <Pressable
      disabled={disabled}
      onPress={onPress}
      style={({ pressed }) => ({
        opacity: disabled ? 0.45 : pressed ? 0.72 : 1,
        backgroundColor: muted ? colors.surfaceMuted : colors.text,
        borderRadius: radius.md,
        paddingVertical: 12,
        alignItems: "center"
      })}
    >
      <Text
        selectable
        style={{
          color: muted ? colors.text : colors.surface,
          fontSize: 14,
          fontWeight: "800"
        }}
      >
        {label}
      </Text>
    </Pressable>
  );
}

function availabilityLabel(value: "unchecked" | "available" | "unavailable"): string {
  if (value === "available") {
    return "Available";
  }
  if (value === "unavailable") {
    return "Unavailable";
  }
  return "Unchecked";
}
