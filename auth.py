"""Authentication utilities."""


class User:
    def __init__(self, username: str):
        self.username = username
        self.is_authenticated = False

    def authenticate(self, password: str) -> bool:
        if password == "secret":
            self.is_authenticated = True
        return self.is_authenticated
