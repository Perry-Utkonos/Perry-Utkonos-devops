"""Apply the deployment-only backend changes to the ignored local checkout."""

from pathlib import Path
import json


root = Path(__file__).resolve().parents[1]
api = root / "backend" / "src" / "ChatApp.Api"
program = api / "Program.cs"
settings = api / "appsettings.json"

old = "    if (app.Environment.IsDevelopment())\n        await db.Database.MigrateAsync();"
new = (
    "    if (app.Environment.IsDevelopment() || "
    'app.Configuration.GetValue<bool>("Database:ApplyMigrations"))\n'
    "        await db.Database.MigrateAsync();"
)

source = program.read_text(encoding="utf-8")
if old in source:
    program.write_text(source.replace(old, new, 1), encoding="utf-8")
elif new not in source:
    raise SystemExit("Неизвестная версия Program.cs; миграции не изменены")

data = json.loads(settings.read_text(encoding="utf-8"))
data["ConnectionStrings"]["Postgres"] = ""
data["ConnectionStrings"]["Redis"] = ""
data["Jwt"]["SigningKey"] = ""
settings.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

print("Backend: включён флаг миграций и очищен appsettings.json")
