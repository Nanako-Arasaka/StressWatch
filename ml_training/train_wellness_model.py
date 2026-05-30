import argparse
import json
import warnings
from datetime import datetime, timezone
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.ensemble import GradientBoostingClassifier, RandomForestClassifier
from sklearn.impute import SimpleImputer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix, f1_score
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import LabelEncoder, StandardScaler

RANDOM_STATE = 42
MIN_CONFIDENCE_DEFAULT = 40.0
MIN_EXPERIMENT_SAMPLES = 60

FEATURE_COLUMNS = [
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
    "active_energy",
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

EXCLUDED_LEAKY_COLUMNS = [
    "rule_stress_score",
    "rule_recovery_score",
    "live_stress_estimate",
]

WEAK_LABEL_COLUMN = "weak_label"
USER_LABEL_COLUMN = "user_label"
TARGET_COLUMN = "target_label"
LABEL_SOURCE_COLUMN = "label_source"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Train a personal wellness trend classifier from StressWatch CSV.")
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


def detect_placeholder_csv_path(raw_csv_arg: str) -> bool:
    normalized = raw_csv_arg.replace("/", "\\").strip().lower()
    return "path\\to\\your.csv" in normalized


def value_counts_dict(series: pd.Series) -> dict:
    return {str(k): int(v) for k, v in series.value_counts(dropna=False).items()}


def clean_dataframe(df: pd.DataFrame, min_confidence: float):
    report_lines = []

    df = df.copy()
    df = df.replace(r"^\s*$", np.nan, regex=True)
    df = df.replace(["NA", "N/A", "na", "null", "None"], np.nan)

    if "date" in df.columns:
        df["date"] = pd.to_datetime(df["date"], errors="coerce")

    if WEAK_LABEL_COLUMN not in df.columns:
        raise ValueError(f"Missing required target column: {WEAK_LABEL_COLUMN}")

    before_label_drop = len(df)
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
    report_lines.append(f"Dropped rows with empty target_label: {before_label_drop - len(df)}")

    if "data_confidence" in df.columns:
        df["data_confidence"] = to_numeric_series(df, "data_confidence")
        before_conf_drop = len(df)
        df = df[df["data_confidence"].fillna(-np.inf) >= min_confidence]
        report_lines.append(
            f"Dropped rows below data_confidence < {min_confidence:.1f}: {before_conf_drop - len(df)}"
        )
    else:
        report_lines.append("WARNING: data_confidence column missing; confidence filter skipped.")

    for col in FEATURE_COLUMNS:
        df[col] = to_numeric_series(df, col)

    removed_empty_features = []
    active_feature_columns = []
    for col in FEATURE_COLUMNS:
        # Drop feature columns that are entirely missing after normalization.
        if df[col].notna().sum() == 0:
            removed_empty_features.append(col)
            continue
        active_feature_columns.append(col)

    report_lines.append(f"removed_empty_features: {removed_empty_features if removed_empty_features else '[]'}")

    label_source_distribution = value_counts_dict(df[LABEL_SOURCE_COLUMN])
    target_label_distribution = value_counts_dict(df[TARGET_COLUMN])
    user_label_count = int(label_source_distribution.get("user", 0))
    weak_label_count = int(label_source_distribution.get("weak", 0))

    report_lines.append(f"user_label samples: {user_label_count}")
    report_lines.append(f"weak_label fallback samples: {weak_label_count}")
    report_lines.append(f"label_source distribution: {label_source_distribution}")
    report_lines.append(f"target_label distribution: {target_label_distribution}")
    if user_label_count < 20:
        report_lines.append(
            "WARNING: user_label < 20. 当前仍以 weak_label 为主，模型更接近规则模型蒸馏，不是完全监督模型。"
        )

    class_counts = target_label_distribution
    sparse_classes = {k: v for k, v in class_counts.items() if v < 2}
    if sparse_classes:
        warnings.warn(
            f"Very small class counts detected (<2). Stratified split may fail: {sparse_classes}",
            RuntimeWarning,
        )

    label_summary = {
        "user_label_count": user_label_count,
        "weak_label_count": weak_label_count,
        "label_source_distribution": label_source_distribution,
        "target_label_distribution": target_label_distribution,
    }

    return df, report_lines, class_counts, sparse_classes, active_feature_columns, removed_empty_features, label_summary


def build_models(feature_columns):
    numeric_imputer = SimpleImputer(strategy="median")

    lr_preprocessor = ColumnTransformer(
        transformers=[
            (
                "num",
                Pipeline([
                    ("imputer", numeric_imputer),
                    ("scaler", StandardScaler()),
                ]),
                feature_columns,
            )
        ],
        remainder="drop",
    )

    tree_preprocessor = ColumnTransformer(
        transformers=[("num", numeric_imputer, feature_columns)],
        remainder="drop",
    )

    models = {
        "LogisticRegression": Pipeline(
            [
                ("preprocess", lr_preprocessor),
                (
                    "model",
                    LogisticRegression(
                        random_state=RANDOM_STATE,
                        max_iter=2000,
                        class_weight="balanced",
                    ),
                ),
            ]
        ),
        "RandomForest": Pipeline(
            [
                ("preprocess", tree_preprocessor),
                (
                    "model",
                    RandomForestClassifier(
                        n_estimators=300,
                        random_state=RANDOM_STATE,
                        class_weight="balanced_subsample",
                    ),
                ),
            ]
        ),
        "GradientBoosting": Pipeline(
            [
                ("preprocess", tree_preprocessor),
                ("model", GradientBoostingClassifier(random_state=RANDOM_STATE)),
            ]
        ),
    }
    return models


def evaluate_models(models, X_train, X_test, y_train, y_test, class_names, feature_columns):
    eval_results = {}

    for name, pipeline in models.items():
        pipeline.fit(X_train, y_train)
        y_pred = pipeline.predict(X_test)

        acc = accuracy_score(y_test, y_pred)
        macro_f1 = f1_score(y_test, y_pred, average="macro", zero_division=0)
        report = classification_report(
            y_test,
            y_pred,
            labels=range(len(class_names)),
            target_names=class_names,
            zero_division=0,
        )
        cm = confusion_matrix(y_test, y_pred, labels=range(len(class_names)))

        feature_importance = None
        model_obj = pipeline.named_steps["model"]
        if hasattr(model_obj, "feature_importances_"):
            feature_importance = list(zip(feature_columns, model_obj.feature_importances_.tolist()))
            feature_importance.sort(key=lambda x: x[1], reverse=True)
        elif hasattr(model_obj, "coef_"):
            coef = np.abs(model_obj.coef_)
            importance = coef.mean(axis=0)
            feature_importance = list(zip(feature_columns, importance.tolist()))
            feature_importance.sort(key=lambda x: x[1], reverse=True)

        eval_results[name] = {
            "pipeline": pipeline,
            "accuracy": acc,
            "macro_f1": macro_f1,
            "report": report,
            "confusion_matrix": cm,
            "feature_importance": feature_importance,
        }

    return eval_results


def choose_best_model(eval_results, sample_count):
    rf = eval_results.get("RandomForest")
    gb = eval_results.get("GradientBoosting")

    # If data is very small, favor RandomForest for stability.
    if sample_count < 100 and rf is not None:
        return "RandomForest"

    sorted_models = sorted(
        eval_results.items(), key=lambda kv: (kv[1]["macro_f1"], kv[1]["accuracy"]), reverse=True
    )
    best_name = sorted_models[0][0]

    # If RF and GB are close on macro F1, prefer RF.
    if rf is not None and gb is not None:
        if abs(rf["macro_f1"] - gb["macro_f1"]) <= 0.02:
            return "RandomForest"

    return best_name


def try_export_coreml(best_name, eval_results, output_dir: Path, feature_columns, class_names):
    mlmodel_path = output_dir / "StressWatchWellnessClassifier.mlmodel"
    notes = []

    try:
        import coremltools as ct
    except Exception:
        notes.append("coremltools not installed. To enable Core ML export: pip install coremltools")
        return None, notes

    conversion_order = [best_name, "RandomForest", "LogisticRegression", "GradientBoosting"]
    unique_order = []
    for m in conversion_order:
        if m not in unique_order:
            unique_order.append(m)

    for model_name in unique_order:
        if model_name not in ["RandomForest", "LogisticRegression", "GradientBoosting"]:
            continue
        candidate = eval_results.get(model_name, {}).get("pipeline")
        if candidate is None:
            notes.append(f"Skipping {model_name} for Core ML export because pipeline instance is unavailable.")
            continue

        try:
            input_features = [(col, ct.models.datatypes.Double()) for col in feature_columns]
            class_labels = list(class_names)
            mlmodel = ct.converters.sklearn.convert(
                candidate,
                input_features=input_features,
                class_labels=class_labels,
            )
            mlmodel.short_description = "Personal wellness trend classifier for reference only."
            mlmodel.save(str(mlmodel_path))
            notes.append(f"Core ML export success with {model_name}: {mlmodel_path}")
            return mlmodel_path, notes
        except Exception as e:
            notes.append(f"Core ML export failed with {model_name}: {e}")

    notes.append(
        "Core ML export was not successful for available models. Keep joblib model; consider Create ML or alternative pipeline."
    )
    return None, notes


def write_report(
    report_path: Path,
    csv_path: str,
    clean_notes,
    label_summary,
    class_counts,
    sparse_classes,
    eval_results,
    best_name,
    sample_count,
    split_mode,
    sample_prediction,
    consistency_lines,
    coreml_notes,
):
    lines = []
    lines.append("StressWatch Wellness Trend Training Report")
    lines.append("=" * 52)
    lines.append(f"CSV path: {csv_path}")
    lines.append("")
    lines.append("Data Cleaning")
    lines.append("-" * 20)
    lines.extend(clean_notes)
    lines.append(f"Final sample count: {sample_count}")
    if sample_count < MIN_EXPERIMENT_SAMPLES:
        lines.append(
            "WARNING: Sample size < 60. This model is only suitable for personal experiments/course demo and not for generalization."
        )
    lines.append(f"Split mode: {split_mode}")
    lines.append("")

    lines.append("Label Source")
    lines.append("-" * 20)
    lines.append(f"user_label samples: {label_summary['user_label_count']}")
    lines.append(f"weak_label fallback samples: {label_summary['weak_label_count']}")
    lines.append(f"label_source distribution: {label_summary['label_source_distribution']}")
    lines.append(f"target_label distribution: {label_summary['target_label_distribution']}")
    if label_summary["user_label_count"] < 20:
        lines.append(
            "WARNING: user_label < 20. 当前仍以 weak_label 为主，模型更接近规则模型蒸馏，不是完全监督模型。"
        )
    lines.append("")

    lines.append("Class Distribution")
    lines.append("-" * 20)
    for k, v in class_counts.items():
        lines.append(f"{k}: {v}")
    if sparse_classes:
        lines.append(f"WARNING: very small classes detected: {sparse_classes}")
    lines.append("")

    for model_name, result in eval_results.items():
        lines.append(f"Model: {model_name}")
        lines.append(f"Accuracy: {result['accuracy']:.4f}")
        lines.append(f"Macro F1: {result['macro_f1']:.4f}")
        lines.append("Classification Report:")
        lines.append(result["report"])
        lines.append("Confusion Matrix:")
        lines.append(np.array2string(result["confusion_matrix"]))
        if result["feature_importance"] is not None:
            lines.append("Feature Importance (top 10):")
            for feat, score in result["feature_importance"][:10]:
                lines.append(f"  {feat}: {score:.6f}")
        lines.append("-" * 40)

    lines.append(f"Selected best model: {best_name}")
    lines.append("")
    lines.append("Prediction Example (Most Recent Day)")
    lines.append("-" * 20)
    lines.extend(sample_prediction)
    lines.append("")
    lines.append("Prediction Consistency Check")
    lines.append("-" * 20)
    lines.extend(consistency_lines)
    lines.append("")

    lines.append("Core ML Export")
    lines.append("-" * 20)
    lines.extend(coreml_notes)

    report_path.write_text("\n".join(lines), encoding="utf-8")


def main():
    args = parse_args()
    script_dir = Path(__file__).resolve().parent
    raw_csv_arg = args.csv
    csv_path = Path(args.csv)
    if not csv_path.is_absolute():
        csv_path = script_dir / csv_path

    output_dir = script_dir / "output"
    output_dir.mkdir(parents=True, exist_ok=True)

    if not csv_path.exists():
        if detect_placeholder_csv_path(raw_csv_arg):
            raise FileNotFoundError(
                "请把 path\\to\\your.csv 替换成真实 CSV 路径，或直接运行 python train_wellness_model.py 使用默认路径。"
            )
        raise FileNotFoundError(f"CSV file not found: {csv_path}")

    df = pd.read_csv(csv_path)
    (
        df_clean,
        clean_notes,
        class_counts,
        sparse_classes,
        active_feature_columns,
        removed_empty_features,
        label_summary,
    ) = clean_dataframe(df, args.min_confidence)

    if len(df_clean) < 10:
        raise ValueError("Not enough valid samples after cleaning. Need at least 10 rows.")
    if len(active_feature_columns) == 0:
        raise ValueError("All feature columns are empty after cleaning. Cannot train model.")

    X = df_clean[active_feature_columns].copy()
    y_raw = df_clean[TARGET_COLUMN].astype(str).values

    label_encoder = LabelEncoder()
    y = label_encoder.fit_transform(y_raw)
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
    except ValueError as e:
        split_mode = f"fallback_non_stratified ({e})"
        warnings.warn(f"Stratified split failed. Fallback to non-stratified split. Reason: {e}", RuntimeWarning)
        X_train, X_test, y_train, y_test = train_test_split(
            X,
            y,
            test_size=0.25,
            random_state=RANDOM_STATE,
            stratify=None,
        )

    models = build_models(active_feature_columns)
    eval_results = evaluate_models(models, X_train, X_test, y_train, y_test, class_names, active_feature_columns)
    best_name = choose_best_model(eval_results, sample_count=len(df_clean))
    best_pipeline = eval_results[best_name]["pipeline"]
    best_macro_f1 = eval_results[best_name]["macro_f1"]

    # Save artifacts
    model_path = output_dir / "wellness_model.joblib"
    label_path = output_dir / "label_encoder.joblib"
    features_path = output_dir / "feature_columns.json"
    metadata_path = output_dir / "training_metadata.json"

    joblib.dump(best_pipeline, model_path)
    joblib.dump(label_encoder, label_path)
    features_path.write_text(json.dumps(active_feature_columns, indent=2), encoding="utf-8")

    # Prediction sample from most recent day
    sample_prediction_lines = []
    consistency_lines = []
    most_recent_idx = df_clean["date"].idxmax() if "date" in df_clean.columns else df_clean.index[-1]
    sample_X = df_clean.loc[[most_recent_idx], active_feature_columns]
    pred_encoded = best_pipeline.predict(sample_X)[0]
    pred_label = label_encoder.inverse_transform([pred_encoded])[0]

    sample_prediction_lines.append(f"Predicted wellness state: {pred_label}")
    if hasattr(best_pipeline, "predict_proba"):
        proba = best_pipeline.predict_proba(sample_X)[0]
        top_prob = float(np.max(proba))
        top_idx = int(np.argmax(proba))
        model_classes = best_pipeline.named_steps["model"].classes_
        top_encoded = int(model_classes[top_idx])
        top_prob_label = label_encoder.inverse_transform([top_encoded])[0]

        matched = pred_label == top_prob_label
        consistency_lines.append(f"Predicted class: {pred_label}")
        consistency_lines.append(f"Top probability class: {top_prob_label}")
        consistency_lines.append(f"Whether matched: {matched}")
        if not matched:
            raise AssertionError(
                f"Prediction label mismatch: predict()={pred_label}, argmax(predict_proba)={top_prob_label}"
            )

        sample_prediction_lines.append(f"Confidence (top class probability): {top_prob:.4f}")
        sample_prediction_lines.append("Class probabilities:")
        proba_pairs = sorted(
            [
                (label_encoder.inverse_transform([int(enc)])[0], float(proba[idx]))
                for idx, enc in enumerate(model_classes)
            ],
            key=lambda x: x[0],
        )
        for cls, p in proba_pairs:
            sample_prediction_lines.append(f"  {cls}: {float(p):.4f}")
    else:
        sample_prediction_lines.append("Probability output unavailable for selected model.")
        consistency_lines.append("Predicted class: unavailable")
        consistency_lines.append("Top probability class: unavailable")
        consistency_lines.append("Whether matched: unavailable (predict_proba not supported)")

    sample_prediction_lines.append(
        "Message template: 最近指标相对个人基线出现波动，当前结果仅供个人健康趋势参考，建议关注恢复节奏、睡眠规律与活动平衡。"
    )

    # Core ML export (best effort)
    coreml_path, coreml_notes = try_export_coreml(
        best_name, eval_results, output_dir, active_feature_columns, class_names
    )
    coreml_export_success = coreml_path is not None
    if coreml_path is None:
        coreml_notes.append("joblib model artifacts are saved and can still be used locally.")
        coreml_notes.append(
            "Recommended Core ML export env: Python 3.10/3.11 + scikit-learn==1.5.1 + coremltools."
        )

    training_metadata = {
        "sample_count": int(len(df_clean)),
        "user_label_count": label_summary["user_label_count"],
        "weak_label_count": label_summary["weak_label_count"],
        "label_source_distribution": label_summary["label_source_distribution"],
        "target_label_distribution": label_summary["target_label_distribution"],
        "feature_columns": active_feature_columns,
        "target_column": TARGET_COLUMN,
        "best_model": best_name,
        "best_macro_f1": float(best_macro_f1),
        "created_at": datetime.now(timezone.utc).isoformat(),
        "coreml_export_success": coreml_export_success,
        "coreml_model_path": str(coreml_path) if coreml_path is not None else None,
        "coreml_notes": coreml_notes,
    }
    metadata_path.write_text(json.dumps(training_metadata, ensure_ascii=False, indent=2), encoding="utf-8")

    report_path = output_dir / "evaluation_report.txt"
    write_report(
        report_path=report_path,
        csv_path=str(csv_path),
        clean_notes=clean_notes,
        label_summary=label_summary,
        class_counts=class_counts,
        sparse_classes=sparse_classes,
        eval_results=eval_results,
        best_name=best_name,
        sample_count=len(df_clean),
        split_mode=split_mode,
        sample_prediction=sample_prediction_lines,
        consistency_lines=consistency_lines,
        coreml_notes=coreml_notes,
    )

    print(f"Sample count: {len(df_clean)}")
    print("Class distribution:")
    for cls_name, count in class_counts.items():
        print(f"  {cls_name}: {count}")
    print(f"Removed empty features: {removed_empty_features if removed_empty_features else '[]'}")
    print(f"User label samples: {label_summary['user_label_count']}")
    print(f"Weak label fallback samples: {label_summary['weak_label_count']}")
    print(f"Label source distribution: {label_summary['label_source_distribution']}")
    print(f"Target label distribution: {label_summary['target_label_distribution']}")
    print(f"Best model: {best_name}")
    print(f"Best macro F1: {best_macro_f1:.4f}")
    print(f"Joblib model path: {model_path}")
    print(f"Label encoder path: {label_path}")
    print(f"Feature columns path: {features_path}")
    print(f"Training metadata path: {metadata_path}")
    if coreml_path is not None:
        print(f"Core ML export: success ({coreml_path})")
    else:
        print("Core ML export: failed or skipped")
        print("Reasons:")
        for note in coreml_notes:
            print(f"  - {note}")
        print("Recommended env: Python 3.10/3.11 + scikit-learn==1.5.1 + coremltools")
    print("Prediction Consistency Check:")
    for line in consistency_lines:
        print(f"  {line}")
    print(f"Report: {report_path}")


if __name__ == "__main__":
    main()
