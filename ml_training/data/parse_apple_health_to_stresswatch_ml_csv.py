#!/usr/bin/env python3
"""
Parse Apple Health export.zip into StressWatch daily ML feature CSV.

Usage:
    python parse_apple_health_to_stresswatch_ml_csv.py /path/to/export.zip --out ./stresswatch_ml_export

Notes:
- Uses Apple Health HRV SDNN.
- Assigns sleep records to the wake-up/end date.
- Generates rule-based weak labels for personal wellness trend experiments only.
- Optionally joins local Daily Check-in labels into user_label without replacing weak_label.
"""

import argparse
import collections
import csv
import json
import math
import os
import tempfile
import zipfile
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta

import numpy as np
import pandas as pd


def parse_dt(s):
    return datetime.strptime(s, "%Y-%m-%d %H:%M:%S %z")


def fval(s):
    try:
        return float(s)
    except Exception:
        return None


def to_kcal(value, unit):
    if value is None:
        return None
    if unit == "kJ":
        return value / 4.184
    return value


def mean(vals):
    vals = [v for v in vals if v is not None and not math.isnan(v)]
    return float(np.mean(vals)) if vals else np.nan


def minv(vals):
    vals = [v for v in vals if v is not None and not math.isnan(v)]
    return float(np.min(vals)) if vals else np.nan


def maxv(vals):
    vals = [v for v in vals if v is not None and not math.isnan(v)]
    return float(np.max(vals)) if vals else np.nan


def clamp(x, lo, hi):
    if pd.isna(x):
        return np.nan
    return max(lo, min(hi, x))


def load_user_labels(path):
    if not path:
        return {}

    with open(path, "r", encoding="utf-8") as f:
        records = json.load(f)

    labels = {}
    for record in records:
        date_value = record.get("date")
        label = record.get("label")
        if not date_value or not label:
            continue

        try:
            day = datetime.fromisoformat(date_value.replace("Z", "+00:00")).date().isoformat()
        except Exception:
            day = str(date_value)[:10]

        labels[day] = label

    return labels


def build_dataset(zip_path, out_dir, user_labels_path=None):
    os.makedirs(out_dir, exist_ok=True)
    user_labels = load_user_labels(user_labels_path)

    with zipfile.ZipFile(zip_path) as z:
        xml_candidates = [n for n in z.namelist() if n.lower().endswith(".xml") and "cda" not in n.lower()]
        if not xml_candidates:
            raise RuntimeError("No Apple Health export XML found in zip.")
        xml_name = xml_candidates[0]
        tmp_dir = tempfile.mkdtemp(prefix="apple_health_export_")
        z.extract(xml_name, tmp_dir)
        xml_path = os.path.join(tmp_dir, xml_name)

    daily = collections.defaultdict(lambda: {
        "hrv": [], "heart_rate": [], "resting_hr": [],
        "steps": 0.0, "active_energy_kcal": 0.0, "exercise_minutes": 0.0, "stand_minutes": 0.0,
        "sleep_rem_hours": 0.0, "sleep_core_hours": 0.0, "sleep_deep_hours": 0.0,
        "sleep_awake_hours": 0.0, "sleep_inbed_hours": 0.0, "sleep_unspecified_hours": 0.0,
        "record_count": 0,
    })

    relevant_types = {
        "HKQuantityTypeIdentifierHeartRate",
        "HKQuantityTypeIdentifierHeartRateVariabilitySDNN",
        "HKQuantityTypeIdentifierRestingHeartRate",
        "HKQuantityTypeIdentifierStepCount",
        "HKQuantityTypeIdentifierActiveEnergyBurned",
        "HKQuantityTypeIdentifierAppleExerciseTime",
        "HKQuantityTypeIdentifierAppleStandTime",
        "HKCategoryTypeIdentifierSleepAnalysis",
    }

    counts = collections.Counter()
    for event, elem in ET.iterparse(xml_path, events=("end",)):
        if elem.tag == "Record":
            typ = elem.attrib.get("type")
            if typ in relevant_types:
                counts[typ] += 1
                start = elem.attrib.get("startDate")
                end = elem.attrib.get("endDate")
                val = fval(elem.attrib.get("value"))
                unit = elem.attrib.get("unit", "")
                try:
                    start_dt = parse_dt(start) if start else None
                    end_dt = parse_dt(end) if end else start_dt
                except Exception:
                    elem.clear()
                    continue

                if typ == "HKCategoryTypeIdentifierSleepAnalysis":
                    day = end_dt.date().isoformat() if end_dt else start_dt.date().isoformat()
                    hours = (end_dt - start_dt).total_seconds() / 3600.0 if (start_dt and end_dt) else 0
                    sleep_value = elem.attrib.get("value")
                    if sleep_value == "HKCategoryValueSleepAnalysisAsleepREM":
                        daily[day]["sleep_rem_hours"] += hours
                    elif sleep_value == "HKCategoryValueSleepAnalysisAsleepCore":
                        daily[day]["sleep_core_hours"] += hours
                    elif sleep_value == "HKCategoryValueSleepAnalysisAsleepDeep":
                        daily[day]["sleep_deep_hours"] += hours
                    elif sleep_value == "HKCategoryValueSleepAnalysisAwake":
                        daily[day]["sleep_awake_hours"] += hours
                    elif sleep_value == "HKCategoryValueSleepAnalysisInBed":
                        daily[day]["sleep_inbed_hours"] += hours
                    elif sleep_value == "HKCategoryValueSleepAnalysisAsleepUnspecified":
                        daily[day]["sleep_unspecified_hours"] += hours
                    daily[day]["record_count"] += 1
                else:
                    day = start_dt.date().isoformat()
                    daily[day]["record_count"] += 1
                    if typ == "HKQuantityTypeIdentifierHeartRate" and val is not None:
                        daily[day]["heart_rate"].append(val)
                    elif typ == "HKQuantityTypeIdentifierHeartRateVariabilitySDNN" and val is not None:
                        daily[day]["hrv"].append(val)
                    elif typ == "HKQuantityTypeIdentifierRestingHeartRate" and val is not None:
                        daily[day]["resting_hr"].append(val)
                    elif typ == "HKQuantityTypeIdentifierStepCount" and val is not None:
                        daily[day]["steps"] += val
                    elif typ == "HKQuantityTypeIdentifierActiveEnergyBurned" and val is not None:
                        daily[day]["active_energy_kcal"] += to_kcal(val, unit)
                    elif typ == "HKQuantityTypeIdentifierAppleExerciseTime" and val is not None:
                        daily[day]["exercise_minutes"] += val
                    elif typ == "HKQuantityTypeIdentifierAppleStandTime" and val is not None:
                        daily[day]["stand_minutes"] += val
        elem.clear()

    hrv_dates = sorted([datetime.fromisoformat(d).date() for d, v in daily.items() if v["hrv"]])
    if not hrv_dates:
        raise RuntimeError("No HRV SDNN records found.")
    start_date = hrv_dates[0]
    end_date = max(datetime.fromisoformat(d).date() for d in daily.keys())

    rows = []
    d = start_date
    while d <= end_date:
        key = d.isoformat()
        ag = daily.get(key, {})
        hrv = ag.get("hrv", [])
        hr = ag.get("heart_rate", [])
        rhr = ag.get("resting_hr", [])
        sleep_hours = sum([
            ag.get("sleep_rem_hours", 0),
            ag.get("sleep_core_hours", 0),
            ag.get("sleep_deep_hours", 0),
            ag.get("sleep_unspecified_hours", 0),
        ])
        rows.append({
            "date": key,
            "avg_hrv_sdnn": mean(hrv),
            "min_hrv_sdnn": minv(hrv),
            "max_hrv_sdnn": maxv(hrv),
            "hrv_count": len(hrv),
            "avg_heart_rate": mean(hr),
            "min_heart_rate": minv(hr),
            "max_heart_rate": maxv(hr),
            "heart_rate_count": len(hr),
            "resting_heart_rate": mean(rhr),
            "sleep_hours": sleep_hours if sleep_hours else np.nan,
            "rem_sleep_hours": ag.get("sleep_rem_hours", np.nan) if ag.get("sleep_rem_hours", 0) > 0 else np.nan,
            "core_sleep_hours": ag.get("sleep_core_hours", np.nan) if ag.get("sleep_core_hours", 0) > 0 else np.nan,
            "deep_sleep_hours": ag.get("sleep_deep_hours", np.nan) if ag.get("sleep_deep_hours", 0) > 0 else np.nan,
            "awake_hours": ag.get("sleep_awake_hours", np.nan) if ag.get("sleep_awake_hours", 0) > 0 else np.nan,
            "unspecified_sleep_hours": ag.get("sleep_unspecified_hours", np.nan) if ag.get("sleep_unspecified_hours", 0) > 0 else np.nan,
            "in_bed_hours": ag.get("sleep_inbed_hours", np.nan) if ag.get("sleep_inbed_hours", 0) > 0 else np.nan,
            "steps": ag.get("steps", np.nan) if ag.get("steps", 0) > 0 else np.nan,
            "active_energy_kcal": ag.get("active_energy_kcal", np.nan) if ag.get("active_energy_kcal", 0) > 0 else np.nan,
            "exercise_minutes": ag.get("exercise_minutes", np.nan) if ag.get("exercise_minutes", 0) > 0 else np.nan,
            "stand_hours": (ag.get("stand_minutes", 0) / 60.0) if ag.get("stand_minutes", 0) > 0 else np.nan,
            "record_count": ag.get("record_count", 0),
        })
        d += timedelta(days=1)

    df = pd.DataFrame(rows)
    for col, basecol in [
        ("avg_hrv_sdnn", "hrv_7d_baseline"),
        ("resting_heart_rate", "resting_hr_7d_baseline"),
        ("sleep_hours", "sleep_7d_baseline"),
    ]:
        df[basecol] = df[col].shift(1).rolling(window=7, min_periods=3).mean()

    df["hrv_deviation_percent"] = (df["avg_hrv_sdnn"] - df["hrv_7d_baseline"]) / df["hrv_7d_baseline"] * 100
    df["resting_hr_deviation"] = df["resting_heart_rate"] - df["resting_hr_7d_baseline"]
    df["sleep_ratio"] = df["sleep_hours"] / df["sleep_7d_baseline"]

    def rule_stress(row):
        if pd.isna(row["avg_hrv_sdnn"]) or pd.isna(row["hrv_7d_baseline"]) or row["hrv_7d_baseline"] <= 0:
            return np.nan
        dev = (row["avg_hrv_sdnn"] - row["hrv_7d_baseline"]) / row["hrv_7d_baseline"]
        if dev >= 0.10:
            score = 20
        elif dev >= -0.10:
            score = 40
        elif dev >= -0.20:
            score = 60
        elif dev >= -0.30:
            score = 78
        else:
            score = 90

        if not pd.isna(row["resting_hr_deviation"]):
            if row["resting_hr_deviation"] > 10:
                score += 15
            elif row["resting_hr_deviation"] > 5:
                score += 8

        if not pd.isna(row["sleep_ratio"]):
            if row["sleep_ratio"] < 0.70:
                score += 15
            elif row["sleep_ratio"] < 0.85:
                score += 8

        return clamp(score, 0, 100)

    def rule_recovery(row):
        if pd.isna(row["avg_hrv_sdnn"]) or pd.isna(row["hrv_7d_baseline"]) or row["hrv_7d_baseline"] <= 0:
            return np.nan
        dev = (row["avg_hrv_sdnn"] - row["hrv_7d_baseline"]) / row["hrv_7d_baseline"]
        score = 60 + dev * 100
        if not pd.isna(row["resting_hr_deviation"]):
            score -= row["resting_hr_deviation"] * 2
        if not pd.isna(row["sleep_ratio"]):
            score += (row["sleep_ratio"] - 1) * 30
        return clamp(score, 0, 100)

    def weak_label(row):
        s = row["rule_stress_score"]
        if pd.isna(s):
            return "data_insufficient"
        if not pd.isna(row["sleep_ratio"]) and row["sleep_ratio"] < 0.75:
            return "sleep_debt"
        if not pd.isna(row["steps"]) and row["steps"] < 3000 and s < 70:
            return "low_activity"
        if s <= 25:
            return "recovery_good"
        if s <= 50:
            return "normal"
        if s <= 70:
            return "mild_stress"
        if s <= 85:
            return "attention_stress"
        return "high_stress"

    def confidence(row):
        c = 0
        if not pd.isna(row["avg_hrv_sdnn"]) and not pd.isna(row["hrv_7d_baseline"]):
            c += 60
        if not pd.isna(row["resting_heart_rate"]) and not pd.isna(row["resting_hr_7d_baseline"]):
            c += 15
        if not pd.isna(row["sleep_hours"]) and not pd.isna(row["sleep_7d_baseline"]):
            c += 15
        if not pd.isna(row["steps"]) or not pd.isna(row["active_energy_kcal"]):
            c += 10
        return min(c, 100)

    df["rule_stress_score"] = df.apply(rule_stress, axis=1)
    df["rule_recovery_score"] = df.apply(rule_recovery, axis=1)
    df["live_stress_estimate"] = df["rule_stress_score"]
    df["weak_label"] = df.apply(weak_label, axis=1)
    df["data_confidence"] = df.apply(confidence, axis=1)
    df["user_label"] = df["date"].map(user_labels).fillna("")

    for col in df.columns:
        if col != "date" and pd.api.types.is_numeric_dtype(df[col]):
            df[col] = df[col].round(3)

    full_csv = os.path.join(out_dir, "stresswatch_ml_daily_features_full_hrv_period.csv")
    df.to_csv(full_csv, index=False, encoding="utf-8-sig")

    recent_start = end_date - timedelta(days=89)
    recent = df[pd.to_datetime(df["date"]).dt.date >= recent_start].copy()
    recent_csv = os.path.join(out_dir, "stresswatch_ml_daily_features_recent_90d.csv")
    recent.to_csv(recent_csv, index=False, encoding="utf-8-sig")

    summary = {
        "date_range_full_hrv_period": [str(start_date), str(end_date)],
        "rows_full_hrv_period": int(len(df)),
        "date_range_recent_90d": [str(recent_start), str(end_date)],
        "rows_recent_90d": int(len(recent)),
        "records_parsed": dict(counts),
        "weak_label_counts_full": df["weak_label"].value_counts().to_dict(),
        "weak_label_counts_recent_90d": recent["weak_label"].value_counts().to_dict(),
        "user_label_counts_full": df["user_label"].replace("", np.nan).dropna().value_counts().to_dict(),
        "user_label_counts_recent_90d": recent["user_label"].replace("", np.nan).dropna().value_counts().to_dict(),
    }
    with open(os.path.join(out_dir, "dataset_summary.json"), "w", encoding="utf-8") as f:
        json.dump(summary, f, ensure_ascii=False, indent=2)

    return summary


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("zip_path")
    parser.add_argument("--out", default="./stresswatch_ml_export")
    parser.add_argument(
        "--user-labels",
        default=None,
        help="Optional path to StressWatch daily_check_ins.json; adds user_label without replacing weak_label.",
    )
    args = parser.parse_args()

    summary = build_dataset(args.zip_path, args.out, args.user_labels)
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
