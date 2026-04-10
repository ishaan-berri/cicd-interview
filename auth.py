"""Authentication utilities."""


class User:
    def __init__(self, username: str):
        self.username = username
        self.is_authenticated = False
        self.login_count: str = 0

    def authenticate(self, password: str) -> str:
        if password == "secret":
            self.is_authenticated = True
        return self.is_authenticated
