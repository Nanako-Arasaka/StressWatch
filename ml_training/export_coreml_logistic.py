import json
from pathlib import Path

MAX_COREML_SKLEARN_VERSION = (1, 5, 1)


def parse_version_tuple(version: str) -> tuple[int, int, int]:
    parts = []
    for part in version.split(".")[:3]:
        digits = "".join(ch for ch in part if ch.isdigit())
        parts.append(int(digits) if digits else 0)
    while len(parts) < 3:
        parts.append(0)
    return tuple(parts)


def main() -> None:
    try:
        import joblib
        import sklearn
    except Exception as error:
        print(f"Core ML export failed: missing Python dependency: {error}")
        print('Install first: pip install "scikit-learn==1.5.1" pandas numpy joblib coremltools')
        return

    script_dir = Path(__file__).resolve().parent
    output_dir = script_dir / "output"

    model_path = output_dir / "coreml_logistic_model.joblib"
    feature_columns_path = output_dir / "coreml_feature_columns.json"
    class_labels_path = output_dir / "coreml_class_labels.json"
    mlmodel_path = output_dir / "StressWatchWellnessClassifier.mlmodel"

    missing = [
        str(path)
        for path in [model_path, feature_columns_path, class_labels_path]
        if not path.exists()
    ]
    if missing:
        print(f"Core ML export failed: missing required artifact(s): {missing}")
        print("Run python train_coreml_model.py first.")
        return

    sklearn_version = parse_version_tuple(sklearn.__version__)
    if sklearn_version > MAX_COREML_SKLEARN_VERSION:
        print(
            f"Core ML export skipped: 当前环境 sklearn 版本 {sklearn.__version__} 不兼容，请使用 sklearn==1.5.1。"
        )
        return

    try:
        import coremltools as ct
    except Exception as error:
        print(f"Core ML export failed: coremltools is unavailable: {error}")
        return

    pipeline = joblib.load(model_path)
    feature_columns = json.loads(feature_columns_path.read_text(encoding="utf-8"))

    try:
        input_features = [(column, ct.models.datatypes.Double()) for column in feature_columns]
        mlmodel = ct.converters.sklearn.convert(
            pipeline,
            input_features=input_features,
        )
        mlmodel.short_description = "Personal wellness trend classifier for reference only."
        mlmodel.save(str(mlmodel_path))
        print(f"Core ML export success: {mlmodel_path}")
        print(f"Class labels retained at: {class_labels_path}")
    except Exception as error:
        print(f"Core ML export failed: {error}")
        print("The LogisticRegression joblib model is unchanged.")


if __name__ == "__main__":
    main()
