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

当样本数少于 60 条时，报告会明确提示：

> 当前模型仅适合个人实验和课程展示，不适合泛化。

## 6) Core ML 导出

脚本会自动尝试导出 Core ML：

- 若未安装 `coremltools`：不会中断训练，并提示 `pip install coremltools`
- 若 RandomForest 无法转换：会尝试 LogisticRegression
- 若仍失败：会记录失败原因并保留 `.joblib` 产物
- 当前训练环境可以正常训练并保存 `.joblib`，但 Core ML 导出建议使用兼容环境。

推荐单独创建导出环境：

```bash
conda create -n stresswatch-coreml python=3.11 -y
conda activate stresswatch-coreml
pip install "scikit-learn==1.5.1" pandas numpy joblib coremltools
```

说明：

- 当前 Python 环境可以训练 joblib。
- Core ML 导出建议使用 Python 3.10 / 3.11 + scikit-learn 1.5.1 + coremltools。

如全部转换失败，可后续改用：

- Create ML 重新训练
- 或改造为对 Core ML 更友好的导出路径

## 7) 接入 StressWatch 的 CoreMLWellnessAnalyzer（建议流程）

1. 将 `StressWatchWellnessClassifier.mlmodel` 拖入 Xcode 工程（勾选主 target）。
2. 确认推理输入特征顺序与 `feature_columns.json` 一致。
3. 在 `CoreMLWellnessAnalyzer` 中：
   - 构建 `MLFeatureProvider` 输入（21 个数值特征）
   - 调用模型预测类别与概率
   - 将结果展示为“趋势参考”文案（避免医疗表述）
4. 若模型缺失、加载失败、预测失败或输入特征不完整，App 会自动使用规则模型 fallback。
5. 若当前仅有 `.joblib`：先在 Python 侧验证效果，再根据报告选择可转模型继续导出，或后续使用 Create ML / 单独转换脚本。
