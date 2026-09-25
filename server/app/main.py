"""StressWatch 分析代理：脱敏聚合 payload → 本地 Qwen → 结构化洞察。"""
from __future__ import annotations

import os
from datetime import datetime, timezone

from fastapi import FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from . import llm, safety
from .prompt import build_messages, detect_kind
from .schemas import (
    AnalyzeRequest,
    AnalyzeResponse,
    HealthResponse,
    InsightFinding,
    PersonalizationInsight,
)

API_TOKEN = os.environ.get("API_TOKEN", "")
ALLOWED_ORIGINS = os.environ.get("ALLOWED_ORIGINS", "*")

app = FastAPI(
    title="StressWatch Analysis Proxy",
    version="0.1.0",
    description="Optional deep-insight proxy. On-device stays primary; this only interprets aggregated payloads.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[o.strip() for o in ALLOWED_ORIGINS.split(",") if o.strip()],
    allow_methods=["*"],
    allow_headers=["*"],
)


def _check_token(authorization: str | None) -> None:
    if not API_TOKEN:
        return
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="missing bearer token")
    if authorization.removeprefix("Bearer ").strip() != API_TOKEN:
        raise HTTPException(status_code=401, detail="invalid token")


@app.get("/health", response_model=HealthResponse)
async def health() -> HealthResponse:
    try:
        h = await llm.health()
        status = h.get("status", "unknown")
    except Exception as exc:  # noqa: BLE001 — health 要给出可读状态
        return HealthResponse(status="degraded", llm=f"down: {exc}")
    return HealthResponse(status="ok", llm=status, model=llm.LLM_MODEL)


@app.post("/v1/analyze", response_model=AnalyzeResponse)
async def analyze(
    req: AnalyzeRequest,
    authorization: str | None = Header(default=None),
) -> AnalyzeResponse:
    _check_token(authorization)

    kind = req.kind if req.kind != "auto" else detect_kind(req.data)
    messages = build_messages(kind, req.data)

    try:
        raw = await llm.complete(messages)
        obj = llm.extract_json(raw)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=502, detail=f"LLM failed: {exc}") from exc

    try:
        insight = PersonalizationInsight.model_validate(
            {
                "summary": obj.get("summary", ""),
                "findings": obj.get("findings") or [],
                "suggestions": obj.get("suggestions") or [],
                "tone": obj.get("tone", "平稳"),
                "generatedAt": datetime.now(timezone.utc).isoformat(),
                "windowDays": req.windowDays,
                "usedFallback": False,
            }
        )
    except Exception as exc:  # noqa: BLE001
        insight = PersonalizationInsight(
            summary=(obj.get("summary") if isinstance(obj, dict) else None) or raw[:500],
            findings=[],
            suggestions=[],
            tone="平稳",
            generatedAt=datetime.now(timezone.utc).isoformat(),
            windowDays=req.windowDays,
            usedFallback=True,
        )
        _ = exc

    violations, suspect = safety.validate(insight, req.data)
    if violations:
        # 轻度净化：命中黑名单时标记，但保留内容供端上二次裁剪
        pass

    return AnalyzeResponse(
        insight=insight,
        model=llm.LLM_MODEL,
        validated=not violations,
        violations=violations,
        suspectNumbers=suspect,
    )


@app.get("/")
async def root() -> dict[str, str]:
    return {
        "service": "stresswatch-analysis-proxy",
        "health": "/health",
        "analyze": "POST /v1/analyze",
    }
