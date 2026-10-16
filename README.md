# Perry-Utkonos: запуск на Arch Linux

Этот репозиторий содержит Docker Compose и файлы сборки для локального запуска проекта на **Arch Linux**. Поддержка других дистрибутивов здесь пока не описана.

Состав: React/Vite frontend за Nginx, ASP.NET Core API, PostgreSQL 17 и Redis 7. Исходники frontend и backend остаются в отдельных репозиториях; `scripts/prepare_sources.sh` скачивает зафиксированные версии в локальные игнорируемые каталоги `frontend/` и `backend/`.

## Быстрый запуск на Arch Linux

На машине нужны интернет, `systemd` и доступ к официальным репозиториям Arch. Установите Docker Engine, Compose, Buildx, Git и Python:

```bash
sudo pacman -Syu --needed docker docker-compose docker-buildx git python
sudo systemctl enable --now docker.service
```

Затем:

```bash
git clone https://github.com/Perry-Utkonos/Perry-Utkonos-devops.git
cd Perry-Utkonos-devops
bash scripts/prepare_sources.sh
python3 scripts/init_env.py
sudo docker compose config --quiet
sudo docker compose up --build -d
sudo docker compose ps
```

Откройте <http://127.0.0.1:8080>. Порт можно изменить через `WEB_PORT` в локальном `.env` перед запуском. По умолчанию он доступен **только на этой машине**.

`prepare_sources.sh` скачивает следующие снимки и добавляет в них файлы сборки из этого репозитория:

| Репозиторий | Зафиксированный commit |
|---|---|
| [Perry-Utkonos-frontend](https://github.com/Perry-Utkonos/Perry-Utkonos-frontend) | `e45b40db90fadb7426a2680891d535a9b7dd2106` |
| [Perry-Utkonos-backend](https://github.com/Perry-Utkonos/Perry-Utkonos-backend) | `3be60400ea903ea9af59920c0aa941283775732d` |

Скрипт не изменяет удалённые репозитории. Его можно запускать повторно: checkout остаётся на той же версии, локальные файлы сборки обновляются. Если локальные исходники переведены на другой commit и содержат изменения, скрипт остановится вместо автоматического сброса правок. При повторном запуске он перезаписывает подготовленные им Dockerfile, конфиги Nginx и `.dockerignore`.

## Что делает подготовка

1. Скачивает и закрепляет версии обоих репозиториев.
2. Кладёт `Dockerfile`, `nginx.conf` и `.dockerignore` в локальную копию frontend.
3. Добавляет `.dockerignore` в локальную копию backend.
4. В локальном `Program.cs` разрешает применение EF Core-миграций по `Database__ApplyMigrations=true` в режиме Production.
5. Удаляет строку подключения и JWT signing key из **локальной копии** `backend/src/ChatApp.Api/appsettings.json`. Значения для контейнера поступают через Compose.
6. `init_env.py` создаёт `.env` с отдельными случайными секретами и правами `0600`. Существующий файл он не перезаписывает.

Файл `.env`, локальные копии исходников и Git-история исходников не попадают в коммит DevOps-репозитория. `backend/.dockerignore` и `frontend/.dockerignore` исключают `.git` из контекста сборки.

## Как устроен запуск

`compose.yaml` создаёт новую локальную БД `fate` в volume `postgres_data` и Redis в `redis_data`. Контейнер API ждёт проверки готовности обоих сервисов и применяет существующие EF Core-миграции. Nginx отдаёт собранный frontend, проксирует `/api/` в API и поддерживает WebSocket для `/hubs/chat`. Наружу открыт только `127.0.0.1:8080` (или ваш `WEB_PORT`); PostgreSQL, Redis и API доступны внутри сети Compose.

Исходный удалённый PostgreSQL и его данные здесь **не используются и не переносятся**. Пароль, ранее опубликованный в исходном backend-репозитории, следует сменить отдельно; этот набор файлов его не содержит и не использует.

## Управление и диагностика

```bash
sudo docker compose ps
sudo docker compose logs --tail=100 api
sudo docker compose logs --tail=100 web
sudo docker compose down
```

`down` сохраняет данные в volumes. Команда `down -v` удалит volumes вместе с локальной базой данных; применяйте её только когда эти данные больше не нужны.

Если API не запускается, начните с `sudo docker compose logs api`: наиболее вероятные причины на первом старте — миграции PostgreSQL или подключение Redis. Для обновления приложения сначала закрепите и проверьте новые commit SHA в `scripts/prepare_sources.sh`, затем пересоздайте локальные каталоги исходников и выполните `sudo docker compose up --build -d`.



I use arch btw
