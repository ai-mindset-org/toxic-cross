#!/usr/bin/env bash
# Проверка петли: сборка дня, поле, приём отклика, отказ по неизвестному лучу.
# Имена переменных латиницей: bash не принимает кириллические.
set -uo pipefail
cd "$(dirname "$0")"
PORT="${PORT:-8994}"
FAILS=0

итог() { if [ "$2" = "$3" ]; then echo "  ок    $1: $3"; else echo "  ПРОВАЛ $1: ждали $2, получили $3"; FAILS=$((FAILS+1)); fi; }

echo "сборка:"
BLOCKS="$(python3 собрать.py 2>&1 | grep -oE 'блоков [0-9]+' | grep -oE '[0-9]+' | head -1)"
[ -z "$BLOCKS" ] && BLOCKS=0
[ "${BLOCKS:-0}" -gt 0 ] && echo "  ок    блоков собрано: $BLOCKS" || { echo "  ПРОВАЛ сборка не дала блоков"; FAILS=$((FAILS+1)); }

echo "поле:"
KREST_PORT="$PORT" python3 поле.py >/tmp/krest-проверка.log 2>&1 &
SERVER=$!
trap 'kill $SERVER 2>/dev/null || true' EXIT
sleep 1.5
if ! kill -0 "$SERVER" 2>/dev/null; then
  echo "  ПРОВАЛ поле не поднялось на порту $PORT, возьми другой: PORT=$((PORT+1)) $0"
  tail -n 2 /tmp/krest-проверка.log; exit 1
fi

код() { curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$@"; }
итог "движок"          200 "$(код "http://127.0.0.1:$PORT/движок/")"
итог "собранный день"  200 "$(код "http://127.0.0.1:$PORT/день.json")"
итог "отклик принят"   200 "$(код --get --data-urlencode 'событие=проверка' --data-urlencode 'луч=ресурсы' "http://127.0.0.1:$PORT/отклик")"
итог "мусорный луч"    400 "$(код --get --data-urlencode 'луч=чепуха' "http://127.0.0.1:$PORT/отклик")"
итог "луч не передан"  400 "$(код "http://127.0.0.1:$PORT/отклик")"
итог "поле живо после" 200 "$(код "http://127.0.0.1:$PORT/движок/")"

# Отказ не должен ронять поток: кириллица в строке статуса HTTP это latin-1 и UnicodeEncodeError.
T="$(grep -c Traceback /tmp/krest-проверка.log || true)"
[ -z "$T" ] && T=0
итог "трейсбеков в журнале" 0 "$T"

echo "отклик доехал до креста:"
AFTER="$(python3 собрать.py 2>&1 | grep -oE 'блоков [0-9]+' | grep -oE '[0-9]+' | head -1)"
[ -z "$AFTER" ] && AFTER=0
[ "${AFTER:-0}" -gt "${BLOCKS:-0}" ] && echo "  ок    блоков стало $AFTER, было $BLOCKS" || { echo "  ПРОВАЛ отклик не появился на кресте"; FAILS=$((FAILS+1)); }

if [ "$FAILS" = 0 ]; then echo "все проверки пройдены"; else echo "провалов: $FAILS"; fi
exit "$FAILS"
