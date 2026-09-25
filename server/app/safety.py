"""LLM 输出后置校验，对齐 InsightSafetyValidator.swift。"""
from __future__ import annotations

import re
from typing import Any

from .schemas import PersonalizationInsight

MEDICAL_TERMS = [
    "诊断", "治疗", "治愈", "处方", "临床", "病理", "疾病",
    "diagnose", "treat", "cure", "prescribe", "clinical", "pathological",
]
JARGON_TERMS = [
    "SDNN", "RMSSD", "coefficient", "z-score", "p-value", "regression analysis",
    "标准差", "方差", "相关系数", "回归分析",
]
AI_SLOP_TERMS = [
    "crushing it", "on fire", "killing it", "smashing it", "rock solid",
    "太棒了", "棒极了", "无敌", "碾压",
]
ANTHROPOMORPH_TERMS = [
    "你的心脏在说", "你的身体在请求", "你的心脏喜欢",
    "your heart loves", "your body is asking", "your heart is telling you",
]
CAUSAL_TERMS = [
    "导致", "因为", "证明", "引起", "造成", "说明你",
    "causes", "because", "proves", "leads to", "results in",
]

NUMBER_RE = re.compile(r"-?\d+(?:\.\d+)?")


def _texts(insight: PersonalizationInsight) -> list[str]:
    out = [insight.summary]
    out += [f"{f.title} {f.detail}" for f in insight.findings]
    out += list(insight.suggestions)
    return out


def _source_numbers(payload: dict[str, Any]) -> set[str]:
    found: set[str] = set()

    def walk(node: Any) -> None:
        if isinstance(node, dict):
            for v in node.values():
                walk(v)
        elif isinstance(node, list):
            for v in node:
                walk(v)
        elif isinstance(node, (int, float)) and not isinstance(node, bool):
            found.add(str(int(node)) if float(node).is_integer() else str(round(float(node), 4)))
            found.add(str(round(float(node), 1)))
            found.add(str(round(float(node), 2)))

    walk(payload)
    return found


def validate(insight: PersonalizationInsight, payload: dict[str, Any]) -> tuple[list[str], list[str]]:
    violations: list[str] = []
    suspect: list[str] = []
    source = _source_numbers(payload)

    for text in _texts(insight):
        for term in MEDICAL_TERMS:
            if term in text:
                violations.append(f"医疗术语: {term}")
        for term in JARGON_TERMS:
            if term in text:
                violations.append(f"专业术语: {term}")
        for term in AI_SLOP_TERMS:
            if term.lower() in text.lower():
                violations.append(f"AI 腔: {term}")
        for term in ANTHROPOMORPH_TERMS:
            if term.lower() in text.lower():
                violations.append(f"拟人化: {term}")
        for term in CAUSAL_TERMS:
            if term in text:
                violations.append(f"因果动词: {term}")

        for num in NUMBER_RE.findall(text):
            if num in {"2", "3", "4", "1", "0"}:
                continue
            if num not in source:
                suspect.append(num)

    return violations, sorted(set(suspect))
