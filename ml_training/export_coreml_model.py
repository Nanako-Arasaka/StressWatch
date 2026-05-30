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
        print('Install the export environment first: pip install "scikit-learn==1.5.1" pandas numpy joblib coremltools')
        return

    script_dir = Path(__file__).resolve().parent
    output_dir = script_dir / "output"

    model_path = output_dir / "wellness_model.joblib"
    label_encoder_path = output_dir / "label_encoder.joblib"
    feature_columns_path = output_dir / "feature_columns.json"
    class_labels_path = output_dir / "coreml_class_labels.json"
    mlmodel_path = output_dir / "StressWatchWellnessClassifier.mlmodel"

    required_paths = [model_path, label_encoder_path, feature_columns_path]
    missing = [str(path) for path in required_paths if not path.exists()]
    if missing:
        raise FileNotFoundError(f"Missing required artifact(s): {missing}")

    label_encoder = joblib.load(label_encoder_path)
    feature_columns = json.loads(feature_columns_path.read_text(encoding="utf-8"))
    class_labels = [str(label) for label in label_encoder.classes_.tolist()]
    class_labels_path.write_text(json.dumps(class_labels, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Saved class labels: {class_labels_path}")

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
    try:
        input_features = [(column, ct.models.datatypes.Double()) for column in feature_columns]
        mlmodel = ct.converters.sklearn.convert(
            pipeline,
            input_features=input_features,
        )
        mlmodel.short_description = "Personal wellness trend classifier for reference only."
        mlmodel.save(str(mlmodel_path))
        print(f"Core ML export success: {mlmodel_path}")
    except Exception as error:
        print(f"Core ML export failed: {error}")
        print("Joblib artifacts are unchanged. Consider Create ML or exporting from a compatible sklearn pipeline.")


if __name__ == "__main__":
    main()
