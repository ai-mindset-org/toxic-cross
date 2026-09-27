#!/usr/bin/env bash
# Поднимает поле локально и открывает его в браузере.
#   ./запустить.sh            поле на собранном дне
#   PORT=8899 ./запустить.sh  другой порт
# Поднимает поле.py: статика плюс маршрут /отклик для кнопок ритуала.
# Сервер слушает только 127.0.0.1: наружу ничего не выходит.
# Имена переменных латиницей: bash не принимает кириллические.
set -euo pipefail
cd "$(dirname "$0")"

PORT="${PORT:-8777}"
ADDR="http://127.0.0.1:${PORT}/движок/"

# Занятый порт раньше проходил молча: сервер падал, а браузер открывался на чужом.
LOG="$(mktemp -t krest)"
KREST_PORT="$PORT" python3 поле.py >"$LOG" 2>&1 &
SERVER=$!
trap 'kill $SERVER 2>/dev/null || true; rm -f "$LOG"' EXIT
sleep 1

if ! kill -0 "$SERVER" 2>/dev/null; then
  echo "порт $PORT занят или сервер не поднялся:" >&2
  tail -n 2 "$LOG" >&2
  echo "возьми другой порт:  PORT=$((PORT+1)) $0" >&2
  exit 1
fi

echo "поле: $ADDR"
echo "остановить: Ctrl+C"
case "$(uname -s)" in
  Darwin) open "$ADDR" ;;
  Linux)  command -v xdg-open >/dev/null && xdg-open "$ADDR" || true ;;
esac
wait $SERVER
