#!/usr/bin/env python3
"""
把 StressWatch App 本地打卡（daily_check_ins.json）回灌到训练用日特征 CSV。

流程定位：
    Apple Health 导出 ──▶ parse_apple_health_to_stresswatch_ml_csv.py ──▶ 日特征 CSV
                                                                          │
    App daily_check_ins.json ──▶ 本脚本（映射+按日期 join） ─────────────┘
                                                                          ▼
                                                              训练用 CSV（含 user_label）
                                                                          │
                                                          train_wellness_model.py

为什么需要它：
    1. 解析 Apple Health 很慢，重新跑一遍只为换打卡标签不划算；本脚本直接复用
       已生成的日特征 CSV，仅叠加/更新 user_label。
    2. App 打卡是 5 类主观枚举，必须映射成 7 类 wellness 标签（label_mapping.py），
       否则 user_label 会变成错误类别、与 weak_label / Core ML 类别错位。

用法：
    # 基于已生成的 90 天日特征 CSV，叠加打卡标签
    python export_app_training_csv.py \
        --features data/stresswatch_ml_daily_features_recent_90d.csv \
        --checkins /path/to/daily_check_ins.json \
        --out data/stresswatch_ml_daily_features_labeled.csv

    # 只查看当前有多少有效监督样本（不改文件）
    python export_app_training_csv.py --features ... --checkins ... --summary-only
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime
from pathlib import Path

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parent))
from label_mapping import WELLNESS_LABELS, map_user_label


def load_checkin_labels(path: str) -> dict[str, str]:
    """读取 App 的 daily_check_ins.json，返回 {YYYY-MM-DD: 7类标签}。"""
    with open(path, "r", encoding="utf-8") as f:
        records = json.load(f)

    labels: dict[str, str] = {}
    for record in records:
        date_value = record.get("date")
        raw_label = record.get("label")
        if not date_value or not raw_label:
            continue
        try:
            day = datetime.fromisoformat(str(date_value).replace("Z", "+00:00")).date().isoformat()
        except Exception:
            day = str(date_value)[:10]
        mapped = map_user_label(raw_label)
        if mapped:
            labels[day] = mapped
    return labels


def join_labels(df: pd.DataFrame, labels: dict[str, str]) -> pd.DataFrame:
    if "date" not in df.columns:
        raise ValueError("Features CSV 缺少 'date' 列，无法按日期 join 打卡标签。")
    df = df.copy()
    df["user_label"] = df["date"].map(labels).fillna("")
    return df


def print_summary(df: pd.DataFrame, labels: dict[str, str]) -> None:
    labeled_days = int((df["user_label"].replace("", np.nan).dropna()).shape[0]) if "user_label" in df.columns else 0
    print("=== 打卡监督样本统计 ===")
    print(f"有效打卡天数（已映射到 7 类）: {labeled_days}")
    print(f"日特征 CSV 总行数           : {len(df)}")
    dist = df["user_label"].replace("", np.nan).dropna().value_counts().to_dict()
    print(f"user_label 分布             : {dist}")
    if labeled_days < 20:
        print(
            "WARNING: user_label < 20。当前仍以 weak_label 为主，模型更接近规则模型蒸馏，"
            "不是完全监督模型；建议持续打卡积累样本后再训练个人模型。"
        )
    else:
        print("OK: 已有 >= 20 条监督样本，可进行以个人打卡为主的训练。")


def main() -> None:
    parser = argparse.ArgumentParser(description="Join StressWatch check-ins into training CSV.")
    parser.add_argument(
        "--features",
        required=True,
        help="日特征 CSV（由 parse_apple_health_to_stresswatch_ml_csv.py 生成）。",
    )
    parser.add_argument(
        "--checkins",
        required=True,
        help="App 导出的 daily_check_ins.json 路径。",
    )
    parser.add_argument(
        "--out",
        default="data/stresswatch_ml_daily_features_labeled.csv",
        help="输出训练 CSV 路径（默认 data/stresswatch_ml_daily_features_labeled.csv）。",
    )
    parser.add_argument(
        "--summary-only",
        action="store_true",
        help="只打印统计信息，不写文件。",
    )
    args = parser.parse_args()

    if not Path(args.features).exists():
        print(f"ERROR: 找不到日特征 CSV: {args.features}")
        sys.exit(1)
    if not Path(args.checkins).exists():
        print(f"ERROR: 找不到打卡文件: {args.checkins}")
        sys.exit(1)

    df = pd.read_csv(args.features)
    labels = load_checkin_labels(args.checkins)
    df = join_labels(df, labels)

    print_summary(df, labels)

    if not args.summary_only:
        out_path = Path(args.out)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        df.to_csv(out_path, index=False, encoding="utf-8-sig")
        print(f"\n已写出训练 CSV: {out_path}")
        print("下一步: python train_wellness_model.py --csv " + str(out_path))


if __name__ == "__main__":
    main()
