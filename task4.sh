#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Использование: $0 <URL>" >&2
  exit 2
fi

url="$1"

if curl -sSf -o /dev/null --max-time 10 "$url"; then
  echo "OK: $url доступен"
  exit 0
else
  echo "FAIL: $url недоступен" >&2
  exit 1
fi
