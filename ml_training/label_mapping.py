#!/usr/bin/env python3
"""
StressWatch 打卡标签 → 训练标签映射。

App 端 DailyWellnessCheckIn.label 是 5 类主观枚举：
    feelingGood / normal / tired / highStress / poorRecovery

而 ml_training 的弱监督/监督训练目标 user_label 是 7 类 wellness 趋势标签：
    attention_stress / high_stress / low_activity / mild_stress
    normal / recovery_good / sleep_debt

本模块把 App 打卡映射到 7 类标签，确保 user_label 与 weak_label、Core ML 类别顺序
（coreml_class_labels.json）对齐，避免训练出第 8 个无意义类别。

映射对照（可按个人语义调整 MAP_APP_CHECKIN_TO_WELLNESS）：
    feelingGood   -> recovery_good    主观“状态很好”≈ 恢复良好
    normal        -> normal           中性
    tired         -> low_activity      “累”多由活动不足/低负荷疲劳导致
    highStress    -> high_stress       直接对应
    poorRecovery  -> sleep_debt        “恢复差”通常与睡眠不足强相关

如果输入已经是 7 类 wellness 标签之一，则原样透传（便于后续扩展或人工校正）。
"""

from __future__ import annotations

# 训练目标使用的 7 类 wellness 标签（顺序必须与
# StressWatch/Resources/ML/coreml_class_labels.json 完全一致）。
WELLNESS_LABELS = [
    "attention_stress",
    "high_stress",
    "low_activity",
    "mild_stress",
    "normal",
    "recovery_good",
    "sleep_debt",
]

# App 端 DailyWellnessLabel 原始值 -> 7 类 wellness 标签。
MAP_APP_CHECKIN_TO_WELLNESS = {
    "feelingGood": "recovery_good",
    "normal": "normal",
    "tired": "low_activity",
    "highStress": "high_stress",
    "poorRecovery": "sleep_debt",
}

# 反向：若需要从 7 类回写/展示时的兜底（本管线不强制使用）。
WELLNESS_TO_APP_CHECKIN = {v: k for k, v in MAP_APP_CHECKIN_TO_WELLNESS.items()}


def is_wellness_label(value: str | None) -> bool:
    return value in WELLNESS_LABELS


def map_user_label(raw: str | None) -> str:
    """把任意来源的标签规整为 7 类 wellness 标签。

    - 已是 7 类之一：原样返回（透传）。
    - 是 App 5 类枚举：按 MAP_APP_CHECKIN_TO_WELLNESS 映射。
    - 其它 / 空：返回空字符串（表示无 user_label，训练时回退 weak_label）。
    """
    if not raw:
        return ""
    raw = str(raw).strip()
    if raw in WELLNESS_LABELS:
        return raw
    mapped = MAP_APP_CHECKIN_TO_WELLNESS.get(raw)
    return mapped if mapped else ""


def count_labeled_days(labels: dict) -> int:
    """统计有效（非空）打卡天数。"""
    return sum(1 for v in labels.values() if v)
