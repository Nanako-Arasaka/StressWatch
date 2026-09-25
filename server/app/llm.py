"""调用本机 llama-server（OpenAI 兼容）。"""
from __future__ import annotations

import json
import os
import re
from typing import Any

import httpx

LLM_BASE_URL = os.environ.get("LLM_BASE_URL", "http://127.0.0.1:8080/v1").rstrip("/")
LLM_MODEL = os.environ.get("LLM_MODEL", "qwen3.8-27b")
LLM_TIMEOUT = float(os.environ.get("LLM_TIMEOUT", "120"))
LLM_API_KEY = os.environ.get("LLM_API_KEY", "")

FENCE_RE = re.compile(r"```(?:json)?\s*(\{.*?\})\s*```", re.S)


def _headers() -> dict[str, str]:
    h = {"Content-Type": "application/json"}
    if LLM_API_KEY:
        h["Authorization"] = f"Bearer {LLM_API_KEY}"
    return h


async def health() -> dict[str, Any]:
    async with httpx.AsyncClient(timeout=5.0) as client:
        r = await client.get(f"{LLM_BASE_URL.rsplit('/v1', 1)[0]}/health")
        r.raise_for_status()
        return r.json()


async def complete(messages: list[dict[str, str]], *, max_tokens: int = 2500) -> str:
    body = {
        "model": LLM_MODEL,
        "messages": messages,
        "temperature": 0.4,
        "top_p": 0.9,
        "max_tokens": max_tokens,
        "stream": False,
        # 限制思考预算，避免 reasoning 吃光 token 导致 content 为空
        "chat_template_kwargs": {"reasoning_budget": 400},
    }
    async with httpx.AsyncClient(timeout=LLM_TIMEOUT) as client:
        r = await client.post(
            f"{LLM_BASE_URL}/chat/completions",
            headers=_headers(),
            json=body,
        )
        r.raise_for_status()
        data = r.json()
    msg = data["choices"][0]["message"] or {}
    content = msg.get("content") or ""
    if content.strip():
        return content
    # 兜底：从 reasoning_content 里抠 JSON
    reasoning = msg.get("reasoning_content") or ""
    return reasoning or content


def extract_json(text: str) -> dict[str, Any]:
    """从模型输出提取 JSON 对象（容忍 markdown 围栏与前后废话）。"""
    text = text.strip()
    if not text:
        raise ValueError("empty LLM response")

    try:
        obj = json.loads(text)
        if isinstance(obj, dict):
            return obj
    except json.JSONDecodeError:
        pass

    m = FENCE_RE.search(text)
    if m:
        return json.loads(m.group(1))

    start = text.find("{")
    end = text.rfind("}")
    if start >= 0 and end > start:
        return json.loads(text[start : end + 1])

    raise ValueError("no JSON object in LLM response")
