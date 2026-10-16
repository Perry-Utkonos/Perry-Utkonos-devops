#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
frontend_sha=e45b40db90fadb7426a2680891d535a9b7dd2106
backend_sha=3be60400ea903ea9af59920c0aa941283775732d

fetch_source() {
    local name="$1" repo="$2" sha="$3" path="$root/$1"
    if [[ ! -e "$path" ]]; then
        git clone --filter=blob:none --no-checkout "$repo" "$path"
        git -C "$path" fetch --depth 1 origin "$sha"
        git -C "$path" checkout --detach "$sha"
    fi
    if [[ ! -d "$path/.git" ]]; then
        echo "$path существует, но не является Git-клоном; остановка" >&2
        exit 1
    fi
    if [[ "$(git -C "$path" rev-parse HEAD 2>/dev/null || true)" != "$sha" ]]; then
        if [[ -n "$(git -C "$path" status --porcelain)" ]]; then
            echo "$path содержит локальные изменения; остановка" >&2
            exit 1
        fi
        git -C "$path" fetch --depth 1 origin "$sha"
        git -C "$path" checkout --detach "$sha"
    fi
    echo "$name: $(git -C "$path" rev-parse --short HEAD)"
}

fetch_source frontend https://github.com/Perry-Utkonos/Perry-Utkonos-frontend.git "$frontend_sha"
fetch_source backend https://github.com/Perry-Utkonos/Perry-Utkonos-backend.git "$backend_sha"

cp "$root/docker/frontend/Dockerfile" "$root/frontend/Dockerfile"
cp "$root/docker/frontend/nginx.conf" "$root/frontend/nginx.conf"
cp "$root/docker/frontend/.dockerignore" "$root/frontend/.dockerignore"
cp "$root/docker/backend/.dockerignore" "$root/backend/.dockerignore"

python3 "$root/scripts/prepare_backend.py"
echo "Исходники подготовлены для docker compose up --build"
