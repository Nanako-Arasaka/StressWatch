import type { MetricType, RecoveryLevel, StressLevel } from "@/models/types";

export function stressLevelLabel(level: StressLevel | null | undefined): string {
  if (level === "low") {
    return "低";
  }
  if (level === "medium") {
    return "中";
  }
  if (level === "high") {
    return "高";
  }
  return "暂无";
}

export function recoveryLevelLabel(level: RecoveryLevel | null | undefined): string {
  if (level === "poor") {
    return "恢复较弱";
  }
  if (level === "fair") {
    return "恢复一般";
  }
  if (level === "good") {
    return "恢复良好";
  }
  return "暂无数据";
}

export function metricLabel(type: MetricType): string {
  switch (type) {
    case "heartRate":
      return "HR";
    case "hrv":
      return "HRV";
    case "restingHeartRate":
      return "静息 HR";
    case "steps":
      return "步数";
    case "sleep":
      return "睡眠";
  }
}

export function metricUnit(type: MetricType): string {
  switch (type) {
    case "heartRate":
    case "restingHeartRate":
      return "bpm";
    case "hrv":
      return "ms";
    case "steps":
      return "steps";
    case "sleep":
      return "h";
  }
}
