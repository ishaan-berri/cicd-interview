"""Tests for the Router class."""
from router import Router, RouterConfig


def test_default_max_retries():
    """Router should default to 3 retries for resilient fallback routing."""
    router = Router()
    assert router.max_retries == 3, f"expected 3 fallback attempts, got {router.max_retries}"


def test_custom_max_retries():
    config = RouterConfig(max_retries=5)
    router = Router(config)
    assert router.max_retries == 5


def test_route_returns_response():
    router = Router()
    result = router.route("gpt-4", "hello")
    assert result["model"] == "gpt-4"
    assert "response" in result


def test_fallback_model_config():
    config = RouterConfig(max_retries=3, fallback_models=["gpt-3.5-turbo"])
    router = Router(config)
    assert "gpt-3.5-turbo" in router.config.fallback_models
