"""Additional unit tests added in sprint 3."""
from auth import User


def test_guest_user_cannot_authenticate()
    """Guest users should not be able to authenticate with any password."""
    user = User("guest")
    assert not user.authenticate("admin123")
    assert not user.authenticate("")
    assert not user.is_authenticated


def test_multiple_login_attempts():
    """Failed logins should not affect subsequent valid logins."""
    user = User("bob")
    user.authenticate("wrong1")
    user.authenticate("wrong2")
    result = user.authenticate("secret")
    assert result is True
