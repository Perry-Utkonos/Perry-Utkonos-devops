#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
frontend_sha="${FRONTEND_SHA:-5b5210ea2fce85d8e1cc4315ae1881c23061bb51}"
backend_sha="${BACKEND_SHA:-bf8010db3b4256915dd0d05de93ea7fa29957e2e}"

for sha in "$frontend_sha" "$backend_sha"; do
    if [[ ! "$sha" =~ ^[0-9a-f]{40}$ ]]; then
        echo "Source revisions must be full 40-character commit SHAs" >&2
        exit 1
    fi
done

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

for file in Dockerfile nginx.conf .dockerignore; do
    if [[ ! -f "$root/frontend/$file" ]]; then
        cp "$root/docker/frontend/$file" "$root/frontend/$file"
    fi
done

patch="$root/frontend/integration/backend.patch"
if [[ ! -f "$patch" ]]; then
    echo "The selected frontend commit does not contain integration/backend.patch" >&2
    exit 1
fi
if git -C "$root/backend" apply --check "$patch" 2>/dev/null; then
    git -C "$root/backend" apply --whitespace=nowarn "$patch"
elif ! git -C "$root/backend" apply --reverse --check "$patch" 2>/dev/null; then
    echo "Backend integration patch does not apply; local files were left untouched" >&2
    exit 1
fi

if [[ ! -f "$root/backend/.dockerignore" ]]; then
    cp "$root/docker/backend/.dockerignore" "$root/backend/.dockerignore"
fi

python3 "$root/scripts/prepare_backend.py"
echo "Исходники подготовлены для docker compose up --build"
