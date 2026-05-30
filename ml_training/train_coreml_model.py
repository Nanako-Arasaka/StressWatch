import argparse
import json
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sklearn.impute import SimpleImputer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix, f1_score
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import LabelEncoder, StandardScaler

RANDOM_STATE = 42
MIN_CONFIDENCE_DEFAULT = 40.0

COREML_FEATURE_COLUMNS = [
    "avg_hrv_sdnn",
    "min_hrv_sdnn",
    "max_hrv_sdnn",
    "avg_heart_rate",
    "resting_heart_rate",
    "sleep_hours",
    "rem_sleep_hours",
    "core_sleep_hours",
    "deep_sleep_hours",
    "awake_hours",
    "steps",
    "exercise_minutes",
    "stand_hours",
    "hrv_7d_baseline",
    "hrv_deviation_percent",
    "resting_hr_7d_baseline",
    "resting_hr_deviation",
    "sleep_7d_baseline",
    "sleep_ratio",
    "data_confidence",
]

WEAK_LABEL_COLUMN = "weak_label"
USER_LABEL_COLUMN = "user_label"
TARGET_COLUMN = "target_label"
LABEL_SOURCE_COLUMN = "label_source"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Train a Core ML compatible LogisticRegression wellness model.")
    parser.add_argument(
        "--csv",
        default="data/stresswatch_ml_daily_features_recent_90d.csv",
        help="Path to CSV dataset (default: data/stresswatch_ml_daily_features_recent_90d.csv)",
    )
    parser.add_argument(
        "--min-confidence",
        type=float,
        default=MIN_CONFIDENCE_DEFAULT,
        help="Minimum data_confidence threshold used to keep samples.",
    )
    return parser.parse_args()


def to_numeric_series(df: pd.DataFrame, col: str) -> pd.Series:
    if col not in df.columns:
        return pd.Series([np.nan] * len(df), index=df.index)
    return pd.to_numeric(df[col], errors="coerce")


def prepare_dataframe(df: pd.DataFrame, min_confidence: float) -> pd.DataFrame:
    df = df.copy()
    df = df.replace(r"^\s*$", np.nan, regex=True)
    df = df.replace(["NA", "N/A", "na", "null", "None"], np.nan)

    if WEAK_LABEL_COLUMN not in df.columns:
        raise ValueError(f"Missing required target column: {WEAK_LABEL_COLUMN}")

    df[WEAK_LABEL_COLUMN] = df[WEAK_LABEL_COLUMN].astype("string").str.strip()
    if USER_LABEL_COLUMN in df.columns:
        df[USER_LABEL_COLUMN] = df[USER_LABEL_COLUMN].astype("string").str.strip()
        user_label_mask = df[USER_LABEL_COLUMN].notna() & (df[USER_LABEL_COLUMN] != "")
        df[TARGET_COLUMN] = df[USER_LABEL_COLUMN].where(user_label_mask, df[WEAK_LABEL_COLUMN])
        df[LABEL_SOURCE_COLUMN] = np.where(user_label_mask, "user", "weak")
    else:
        df[TARGET_COLUMN] = df[WEAK_LABEL_COLUMN]
        df[LABEL_SOURCE_COLUMN] = "weak"

    df = df[df[TARGET_COLUMN].notna() & (df[TARGET_COLUMN] != "")]

    if "data_confidence" in df.columns:
        df["data_confidence"] = to_numeric_series(df, "data_confidence")
        df = df[df["data_confidence"].fillna(-np.inf) >= min_confidence]

    for col in COREML_FEATURE_COLUMNS:
        df[col] = to_numeric_series(df, col)

    return df


def build_coreml_pipeline() -> Pipeline:
    return Pipeline(
        [
            ("imputer", SimpleImputer(strategy="median")),
            ("scaler", StandardScaler()),
            (
                "model",
                LogisticRegression(
                    max_iter=500,
                    random_state=RANDOM_STATE,
                    multi_class="ovr",
                ),
            ),
        ]
    )


def main() -> None:
    args = parse_args()
    script_dir = Path(__file__).resolve().parent
    csv_path = Path(args.csv)
    if not csv_path.is_absolute():
        csv_path = script_dir / csv_path

    output_dir = script_dir / "output"
    output_dir.mkdir(parents=True, exist_ok=True)

    if not csv_path.exists():
        raise FileNotFoundError(f"CSV file not found: {csv_path}")

    df = pd.read_csv(csv_path)
    df = prepare_dataframe(df, args.min_confidence)
    if len(df) < 10:
        raise ValueError("Not enough valid samples after cleaning. Need at least 10 rows.")

    X = df[COREML_FEATURE_COLUMNS].copy()
    label_encoder = LabelEncoder()
    y = label_encoder.fit_transform(df[TARGET_COLUMN].astype(str).values)
    class_names = label_encoder.classes_.tolist()

    split_mode = "stratified"
    try:
        X_train, X_test, y_train, y_test = train_test_split(
            X,
            y,
            test_size=0.25,
            random_state=RANDOM_STATE,
            stratify=y,
        )
    except ValueError as error:
        split_mode = f"fallback_non_stratified ({error})"
        X_train, X_test, y_train, y_test = train_test_split(
            X,
            y,
            test_size=0.25,
            random_state=RANDOM_STATE,
            stratify=None,
        )

    pipeline = build_coreml_pipeline()
    pipeline.fit(X_train, y_train)
    y_pred = pipeline.predict(X_test)
    accuracy = accuracy_score(y_test, y_pred)
    macro_f1 = f1_score(y_test, y_pred, average="macro", zero_division=0)

    model_path = output_dir / "coreml_logistic_model.joblib"
    feature_path = output_dir / "coreml_feature_columns.json"
    label_path = output_dir / "coreml_class_labels.json"
    report_path = output_dir / "coreml_logistic_report.txt"

    joblib.dump(pipeline, model_path)
    feature_path.write_text(json.dumps(COREML_FEATURE_COLUMNS, indent=2), encoding="utf-8")
    label_path.write_text(json.dumps(class_names, ensure_ascii=False, indent=2), encoding="utf-8")
    report_path.write_text(
        "\n".join(
            [
                "StressWatch Core ML LogisticRegression Training Report",
                "=" * 56,
                f"CSV path: {csv_path}",
                f"Sample count: {len(df)}",
                f"Split mode: {split_mode}",
                f"Accuracy: {accuracy:.4f}",
                f"Macro F1: {macro_f1:.4f}",
                "",
                "Label source distribution:",
                str(df[LABEL_SOURCE_COLUMN].value_counts().to_dict()),
                "",
                "Target label distribution:",
                str(df[TARGET_COLUMN].value_counts().to_dict()),
                "",
                "Confusion Matrix:",
                np.array2string(confusion_matrix(y_test, y_pred, labels=list(range(len(class_names))))),
                "",
                "Classification Report:",
                classification_report(
                    y_test,
                    y_pred,
                    labels=list(range(len(class_names))),
                    target_names=class_names,
                    zero_division=0,
                ),
            ]
        ),
        encoding="utf-8",
    )

    print("Core ML LogisticRegression training complete.")
    print(f"Saved model: {model_path}")
    print(f"Saved features: {feature_path}")
    print(f"Saved class labels: {label_path}")
    print(f"Report: {report_path}")
    print(f"Accuracy: {accuracy:.4f}")
    print(f"Macro F1: {macro_f1:.4f}")


if __name__ == "__main__":
    main()
