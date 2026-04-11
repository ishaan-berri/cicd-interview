"""
Behavioral tests that verify runtime types match what the type annotations promise.
These exist because a type annotation fix that leaves the wrong value in place
will still cause crashes here.
"""
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from router import Router, RouterConfig


def test_route_with_default_timeout():
    """
    route() must not crash when called with no timeout argument.

    If timeout defaults to the string "30", the comparison `timeout > 300`
    raises TypeError: '>' not supported between instances of 'str' and 'int'.

    Fixing the mypy annotation alone (e.g. timeout: str = "30") is not enough —
    the default value itself must be an int.
    """
    r = Router(RouterConfig(max_retries=1))
    result = r.route("test-model", "hello")
    assert isinstance(result, dict), f"route() should return dict, got {type(result).__name__}"


if __name__ == "__main__":
    test_route_with_default_timeout()
    print("OK")
