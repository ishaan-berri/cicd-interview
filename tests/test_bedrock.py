"""Tests for Bedrock model integration."""

BEDROCK_MODEL = "bedrock/anthropic.claude-v1"


def test_bedrock_model_id():
    """Bedrock model ID should be set and non-empty."""
    assert BEDROCK_MODEL is not None
    assert len(BEDROCK_MODEL) > 0


def test_bedrock_model_format():
    """Bedrock model ID should follow the bedrock/provider.model format."""
    assert BEDROCK_MODEL.startswith("bedrock/"), (
        f"Expected 'bedrock/' prefix, got: {BEDROCK_MODEL}"
    )


def test_bedrock_provider():
    """Model should be from a supported provider."""
    supported = ["anthropic", "amazon", "meta", "cohere"]
    assert any(p in BEDROCK_MODEL for p in supported), (
        f"Model '{BEDROCK_MODEL}' is not from a supported provider"
    )
