# Perry-Utkonos: Docker Compose и GitHub Actions

Запуск Fate: React/Vite за Nginx, ASP.NET Core API, PostgreSQL 17 и Redis 7. Исходники скачиваются из отдельных репозиториев на закреплённых commit SHA. Для запуска нужны Git, Python 3, Docker Engine с Compose v2 и Bash.

## Быстрый запуск

На Arch Linux установите инструменты и запустите Docker:

```bash
sudo pacman -Syu --needed docker docker-compose docker-buildx git python
sudo systemctl enable --now docker.service
```

Из терминала с доступом к Docker:

```bash
git clone https://github.com/Perry-Utkonos/Perry-Utkonos-devops.git
cd Perry-Utkonos-devops
bash scripts/prepare_sources.sh
python3 scripts/init_env.py
docker compose config --quiet
docker compose up --build --wait --wait-timeout 180
```

На Linux в зависимости от настроек системы команды Docker могут требовать `sudo`. Откройте <http://127.0.0.1:8080> и зарегистрируйтесь. Для проверки переписки нужны два аккаунта, например в обычном и приватном окне браузера. Готовых пользователей в новой базе нет.

Наружу открыт только web на `127.0.0.1:${WEB_PORT:-8080}`. API, PostgreSQL и Redis доступны внутри Compose. Порт меняется через `WEB_PORT` в `.env`. Для публичного доступа нужен внешний reverse proxy с HTTPS.

## Версии и подготовка

| Репозиторий | Commit |
| --- | --- |
| [Frontend](https://github.com/Perry-Utkonos/Perry-Utkonos-frontend) | `5b5210ea2fce85d8e1cc4315ae1881c23061bb51` |
| [Backend](https://github.com/Perry-Utkonos/Perry-Utkonos-backend) | `bf8010db3b4256915dd0d05de93ea7fa29957e2e` |

`prepare_sources.sh` создаёт игнорируемые каталоги `frontend/` и `backend/`. К backend применяется `frontend/integration/backend.patch` из закреплённой версии frontend: он добавляет совместимый API, JWT-авторизацию, миграции и поддержку чата. Поэтому один исходный backend без этого патча не соответствует текущему frontend. Удалённые репозитории скрипт не меняет.

Файлы Docker/Nginx из frontend сохраняются. Шаблоны из `docker/` используются только при отсутствии соответствующих файлов. Проверяется флаг `Database:ApplyMigrations`, а необязательный `appsettings.json` очищается от строк подключения и JWT-ключа. Рабочие значения API получает через Compose.

Повторный запуск распознаёт уже применённый патч. Если патч несовместим или для смены commit потребовалось бы перезаписать локальные изменения, подготовка останавливается. Созданные файлы сборки и патч считаются локальными изменениями: для перехода со старой версии удобнее подготовить новую копию DevOps в другой папке и перенести существующий `.env` с сохранением его прав доступа. Базу и volumes при этом не удаляют.

Для проверки другой опубликованной пары версий можно задать полные SHA:

```bash
FRONTEND_SHA=<40-символьный-SHA> BACKEND_SHA=<40-символьный-SHA> bash scripts/prepare_sources.sh
```

Оба commit должны существовать на GitHub и быть совместимы с включённым backend-патчем. Обновляйте закреплённые значения в скрипте через pull request: CI проверяет именно их.

`init_env.py` создаёт `.env` со случайными паролем PostgreSQL и JWT-ключом; на Linux права файла — `0600`. Существующий файл он не перезаписывает. При повторном запуске с готовым `.env` пропустите этот шаг. При сохранённой базе сохраняйте и её пароль.

## GitHub Actions

Workflow `.github/workflows/ci.yml` запускается при push, pull request и вручную через **Actions → Compose CI → Run workflow**. Для него не нужны пароли сервера или вручную созданные GitHub secrets.

CI выполняет:

1. Подготовку закреплённых исходников с backend-патчем.
2. Создание временных секретов и проверку Compose.
3. `npm ci` и существующие тесты frontend.
4. Сборку обоих Docker-образов, включая TypeScript/Vite и ASP.NET Core.
5. Запуск PostgreSQL, Redis, API и Nginx в отдельном Compose-проекте.
6. Ожидание готовности web: проверяются главная страница и `/api/health`, включая соединение API с БД.
7. Существующие интеграционные тесты frontend через Nginx: аккаунты, JWT, сохранение данных, лайки и SignalR-чат.

При ошибке CI печатает состояния контейнеров и последние 100 строк журналов. После выполнения удаляются только временные контейнеры и volumes отдельного CI-проекта на GitHub runner. На сервер приложение автоматически не развёртывается.

Nginx пишет путь без query-параметров, чтобы SignalR JWT не попадал в обычный access log. Для маршрута чата отключён подробный upstream error log; в API категория `Hosting.Diagnostics` ограничена уровнем `Warning`.

## Управление и данные

```bash
docker compose ps
docker compose logs --tail=100 api web
docker compose down
```

`web` должен стать `healthy`. Если API не запускается, проверьте его журнал: перед стартом применяются EF Core-миграции. Начальная миграция предназначена для пустой БД; существующую схему нужно сверить с ней отдельно.

`down` сохраняет PostgreSQL в `postgres_data` и Redis в `redis_data`. Не добавляйте `-v`, если данные нужны: этот флаг удаляет volumes. Ранее выданная удалённая БД здесь не используется и не переносится.

После подготовки новых проверенных исходников выполните `docker compose up --build --wait --wait-timeout 180`. Сохраняйте `.env` и volumes между обновлениями. В Git не попадают `.env`, локальные исходники, их история и результаты сборки; `.dockerignore` также исключает `.git` из контекста Docker.
