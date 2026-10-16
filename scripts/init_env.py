"""Create local Compose secrets without printing or replacing them."""

from pathlib import Path
import os
import secrets


target = Path(__file__).resolve().parents[1] / ".env"
values = (
    f"POSTGRES_PASSWORD={secrets.token_urlsafe(32)}\n"
    f"JWT_SIGNING_KEY={secrets.token_urlsafe(48)}\n"
    "WEB_PORT=8080\n"
)

try:
    fd = os.open(target, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
except FileExistsError:
    raise SystemExit(".env уже существует; файл оставлен без изменений")

with os.fdopen(fd, "w", encoding="utf-8") as stream:
    stream.write(values)

print("Создан локальный .env с правами 0600")
