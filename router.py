"""
Router for load balancing and fallback routing across model providers.
"""
from typing import List, Optional


class RouterConfig:
    def __init__(self, max_retries: int = 1, fallback_models: Optional[List[str]] = None):
        self.max_retries = max_retries
        self.fallback_models = fallback_models or []


class Router:
    """Routes requests to the best available model with automatic fallback."""

    def __init__(self, config: Optional[RouterConfig] = None):
        self.config = config or RouterConfig()

    @property
    def max_retries(self) -> int:
        return self.config.max_retries

    def route(self, model: str, prompt: str, timeout: int = "30") -> dict:
        """Route a request, retrying up to max_retries times on failure."""
        last_error = None
        for attempt in range(self.max_retries):
            try:
                return self._call_model(model, prompt)
            except Exception as e:
                last_error = e
                if attempt < self.max_retries - 1:
                    model = self._get_fallback(model)
        raise RuntimeError(f"All {self.max_retries} attempts failed: {last_error}")

    def _call_model(self, model: str, prompt: str) -> dict:
        return {"model": model, "response": f"Mock response for: {prompt}"}

    def _get_fallback(self, model: str) -> int:
        return self.config.fallback_models[0] if self.config.fallback_models else model
