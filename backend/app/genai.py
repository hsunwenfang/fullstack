from __future__ import annotations

import httpx
from typing import List, Dict, Any

from .config import settings


class GenAIClient:
    def __init__(self):
        self.api_key = settings.openai_api_key
        self.base_url = settings.openai_base_url or "https://api.openai.com/v1"
        self.model = settings.openai_model

    def chat(self, messages: List[Dict[str, str]], temperature: float = 0.2, max_tokens: int | None = None) -> str:
        if not self.api_key:
            # Fallback stub if no key is provided
            return "[stubbed] Hello! Provide OPENAI_API_KEY to get real responses."

        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }
        payload: Dict[str, Any] = {
            "model": self.model,
            "messages": messages,
            "temperature": temperature,
        }
        if max_tokens is not None:
            payload["max_tokens"] = max_tokens

        with httpx.Client(base_url=self.base_url, timeout=60) as client:
            resp = client.post("/chat/completions", headers=headers, json=payload)
            resp.raise_for_status()
            data = resp.json()
            return data["choices"][0]["message"]["content"]


genai_client = GenAIClient()
