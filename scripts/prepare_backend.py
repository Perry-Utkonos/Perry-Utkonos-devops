"""Validate the integrated backend and remove optional checked-in secrets."""

from pathlib import Path
import json


root = Path(__file__).resolve().parents[1]
api = root / "backend" / "src" / "ChatApp.Api"
program = api / "Program.cs"
settings = api / "appsettings.json"

source = program.read_text(encoding="utf-8")
if '"Database:ApplyMigrations"' not in source:
    raise SystemExit("Backend integration patch is required: migration flag is missing")

if settings.exists():
    data = json.loads(settings.read_text(encoding="utf-8"))
    data.setdefault("ConnectionStrings", {}).update(Postgres="", Redis="")
    data.setdefault("Jwt", {})["SigningKey"] = ""
    settings.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

print("Backend: migration flag present; runtime settings come from Compose")
