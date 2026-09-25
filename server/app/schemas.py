"""请求/响应契约，对齐 StressWatch Swift 侧 Codable 结构。"""
from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, Field


class InsightFinding(BaseModel):
    title: str
    detail: str
    metric: str | None = None


class PersonalizationInsight(BaseModel):
    """对齐 Swift `PersonalizationInsight`。"""

    summary: str
    findings: list[InsightFinding] = Field(default_factory=list)
    suggestions: list[str] = Field(default_factory=list)
    tone: str = "平稳"
    generatedAt: str | None = None
    windowDays: int = 7
    usedFallback: bool = False


class AnalyzeRequest(BaseModel):
    """
    脱敏后的聚合载荷。接受两种形状之一：
    - kind="structured": StructuredAnalysisResult JSON
    - kind="payload":    AnalysisPayload JSON
    - kind="auto":       自动判断（默认）
    """

    kind: Literal["structured", "payload", "auto"] = "auto"
    windowDays: int = 7
    data: dict[str, Any]


class AnalyzeResponse(BaseModel):
    insight: PersonalizationInsight
    model: str
    validated: bool = True
    violations: list[str] = Field(default_factory=list)
    suspectNumbers: list[str] = Field(default_factory=list)


class HealthResponse(BaseModel):
    status: str
    llm: str
    model: str | None = None
