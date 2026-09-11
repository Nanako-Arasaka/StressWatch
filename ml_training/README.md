# StressWatch Wellness Model Training (Local)

本目录用于基于 StressWatch 导出的日级特征 CSV，训练个人化 wellness trend 分类模型（弱监督，`weak_label`）。

## 重要说明

- 该模型仅用于 **personal wellness trend reference**。
- 该模型不是医疗用途，不提供任何疾病诊断或治疗建议。
- 请勿上传个人健康原始数据到公开仓库。

## 1) 安装依赖

```bash
cd ml_training
pip install -r requirements.txt
```

如果你暂时不需要导出 Core ML，可不安装 `coremltools`。

## 2) 放置 CSV

默认读取路径：

`ml_training/data/stresswatch_ml_daily_features_recent_90d.csv`

你也可以通过命令行传入其他路径。

## 3) 运行训练

```bash
cd ml_training
python train_wellness_model.py
```

或指定 CSV：

```bash
python train_wellness_model.py --csv path/to/file.csv
```

可选：设置最低 `data_confidence` 过滤阈值（默认 40）：

```bash
python train_wellness_model.py --min-confidence 40
```

## 4) 默认训练特征

默认使用以下特征：

- avg_hrv_sdnn
- min_hrv_sdnn
- max_hrv_sdnn
- avg_heart_rate
- resting_heart_rate
- sleep_hours
- rem_sleep_hours
- core_sleep_hours
- deep_sleep_hours
- awake_hours
- steps
- active_energy
- exercise_minutes
- stand_hours
- hrv_7d_baseline
- hrv_deviation_percent
- resting_hr_7d_baseline
- resting_hr_deviation
- sleep_7d_baseline
- sleep_ratio
- data_confidence

默认排除以下规则输出字段，避免 label leakage：

- rule_stress_score
- rule_recovery_score
- live_stress_estimate

训练脚本会生成训练用标签列：

- `target_label`：如果 `user_label` 非空，使用 `user_label`；否则回退到 `weak_label`
- `label_source`：`user` 或 `weak`

`weak_label` 不会被覆盖。若 `user_label` 样本数少于 20，报告会提示当前仍以弱监督为主，更接近规则模型蒸馏。

## 5) 输出文件

训练结束后会在 `ml_training/output/` 生成：

- `evaluation_report.txt`：评估结果（accuracy、macro F1、classification report、confusion matrix、类分布、模型选择说明、预测示例）
- `wellness_model.joblib`：最佳模型
- `label_encoder.joblib`：标签编码器
- `feature_columns.json`：特征列顺序
- `training_metadata.json`：训练样本、标签来源、最佳模型、Core ML 导出状态
- `StressWatchWellnessClassifier.mlmodel`（可选）：当 `coremltools` 可用且转换成功

模型职责：

- `RandomForest`：主训练模型，用于评估、课程展示和本地 joblib 分析。
- `LogisticRegression`：Core ML 部署模型，使用更简单的 sklearn Pipeline，避免 `ColumnTransformer` 等 Core ML 不支持的组件。
- Core ML 部署模型使用 `train_coreml_model.py` 内的专用特征列表，不包含 `active_energy`。

当样本数少于 60 条时，报告会明确提示：

> 当前模型仅适合个人实验和课程展示，不适合泛化。

## 6) Core ML 导出

建议先在当前环境训练主模型并保存 joblib：

```bash
python train_wellness_model.py
```

如需 Core ML 部署，单独训练 Core ML 兼容模型：

```bash
python train_coreml_model.py
```

然后在兼容环境中导出：

```bash
python export_coreml_logistic.py
```

主训练脚本不会因为 Core ML 导出失败而报错。若当前 `scikit-learn` 版本高于 1.5.1，导出脚本会提示使用 `scikit-learn==1.5.1`。

推荐单独创建导出环境：

```bash
conda create -n stresswatch-coreml python=3.11 -y
conda activate stresswatch-coreml
pip install "scikit-learn==1.5.1" pandas numpy joblib coremltools
```

说明：

- 当前 Python 环境可以训练 joblib。
- Core ML 导出建议使用 Python 3.10 / 3.11 + scikit-learn 1.5.1 + coremltools。
- `coreml_class_labels.json` 会保存 `label_encoder.classes_`，App 端可用它把模型输出编码或概率列映射为文本标签。
- `coreml_logistic_model.joblib` 是专门给 Core ML 转换使用的模型，不替代 `wellness_model.joblib`。

如全部转换失败，可后续改用：

- Create ML 重新训练
- 或改造为对 Core ML 更友好的独立转换脚本

## 7) 接入 StressWatch 的 CoreMLWellnessAnalyzer（建议流程）

1. 将 `StressWatchWellnessClassifier.mlmodel` 拖入 Xcode 工程（勾选主 target）。
2. 同步保留 `coreml_class_labels.json` 中的类别顺序，用于 App 端把模型输出映射成文本标签。
3. 在 `CoreMLWellnessAnalyzer` 中：
   - 构建 `MLFeatureProvider` 输入（21 个数值特征）
   - 调用模型预测类别编码或概率
   - 将结果展示为“趋势参考”文案（避免医疗表述）
4. 若模型缺失、加载失败、预测失败或输入特征不完整，App 会自动使用规则模型 fallback。
5. 若当前仅有 `.joblib`：先在 Python 侧验证效果，再根据报告选择可转模型继续导出，或后续使用 Create ML / 单独转换脚本。

## 8) 打卡标签的 5 类 → 7 类映射（重要）

App 端 `DailyWellnessCheckIn.label` 是 5 类主观枚举，而训练目标 `user_label` 必须是 7 类
wellness 标签（与 `weak_label`、Core ML 类别顺序一致）。两者通过 `label_mapping.py` 自动映射：

| App 打卡（DailyWellnessLabel） | 7 类 wellness 标签 |
| --- | --- |
| `feelingGood`   | `recovery_good` |
| `normal`        | `normal`        |
| `tired`         | `low_activity`  |
| `highStress`    | `high_stress`   |
| `poorRecovery`  | `sleep_debt`    |

- 若输入已经是 7 类之一，则原样透传（便于后续扩展或人工校正）。
- 其它 / 空值视为“无 user_label”，训练时回退 `weak_label`。
- 映射表 `MAP_APP_CHECKIN_TO_WELLNESS` 在 `label_mapping.py` 中，可按个人语义调整。
- 该映射同时被 `data/parse_apple_health_to_stresswatch_ml_csv.py`（`--user-labels`）和
  `export_app_training_csv.py` 复用，保证两端一致。

## 9) 从 App 打卡回灌训练数据（端到端）

完整闭环分三步，产出“带个人监督标签”的训练 CSV：

```bash
# 1) Apple Health 导出 -> 日特征 CSV（含 weak_label，user_label 暂空）
python data/parse_apple_health_to_stresswatch_ml_csv.py export.zip \
    --out ./stresswatch_ml_export \
    --user-labels /path/to/daily_check_ins.json   # 可选：直接在此叠加打卡映射

# 2)（推荐）若已生成过日特征 CSV，仅用本脚本把最新打卡叠加/更新到 user_label，
#    避免重新解析耗时的 Apple Health 压缩包
python export_app_training_csv.py \
    --features data/stresswatch_ml_daily_features_recent_90d.csv \
    --checkins /path/to/daily_check_ins.json \
    --out data/stresswatch_ml_daily_features_labeled.csv

# 3) 训练（user_label 样本 >=20 时以个人打卡为主；否则回退弱监督）
python train_wellness_model.py --csv data/stresswatch_ml_daily_features_labeled.csv
```

`export_app_training_csv.py` 额外支持 `--summary-only`：只打印有效打卡天数与分布，
并在 `user_label < 20` 时给出“仍以弱监督为主”的提示，方便你判断何时适合训练个人模型。

### 个人模型落地到 App（Core ML）

```bash
# A. 训练 Core ML 兼容的 LogisticRegression 模型 + 类别顺序
python train_coreml_model.py

# B. 在 sklearn==1.5.1 环境转换为 .mlmodel
conda create -n stresswatch-coreml python=3.11 -y
conda activate stresswatch-coreml
pip install "scikit-learn==1.5.1" pandas numpy joblib coremltools
python export_coreml_logistic.py
```

导出成功后，把以下文件同步到 App 工程（类别顺序必须与 App 端 `coreml_class_labels.json` 一致）：

- `ml_training/output/StressWatchWellnessClassifier.mlmodel`
  → `StressWatch/StressWatch/Resources/ML/StressWatchWellnessClassifier.mlmodel`
- `ml_training/output/coreml_class_labels.json`
  → `StressWatch/StressWatch/Resources/ML/coreml_class_labels.json`

Xcode 构建时会把 `.mlmodel` 编译为 `.mlmodelc`，`CoreMLWellnessAnalyzer` 随后自动加载；
任何加载/预测失败都会回退到规则模型，不会中断 App。
