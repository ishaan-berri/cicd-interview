"""Tests for the authentication module."""
from auth import User


def test_user_creation():
    user = User("alice")
    assert user.username == "alice"
    assert not user.is_authenticated


def test_authentication_success():
    user = User("alice")
    result = user.authenticate("secret")
    assert result is True
    assert user.is_authenticated


def test_authentication_failure():
    user = User("alice")
    result = user.authenticate("wrong-password")
    assert result is False
    assert not user.is_authenticated


def test_independent_user_sessions():
    user_a = User("alice")
    user_b = User("bob")
    user_a.authenticate("secret")
    assert user_a.is_authenticated
    assert not user_b.is_authenticated
