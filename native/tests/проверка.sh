#!/usr/bin/env bash
# Проверка контракта данных: приложение читает эти поля и без них замолчит.
# Имена переменных латиницей: bash не принимает кириллические.
set -uo pipefail
cd "$(dirname "$0")/.."
FAILS=0

check() {
  python3 - "$2" "$1" <<'PY'
import json, sys
путь, имя = sys.argv[1], sys.argv[2]
try:
    d = json.load(open(путь, encoding="utf-8"))
except Exception as e:
    print(f"  {имя}: не читается · {e}"); sys.exit(1)
беды = []
for k in ("дата", "лучи", "баланс"):
    if k not in d: беды.append(f"нет ключа {k}")
for луч in ("обязательства", "ресурсы", "будущее", "прошлое"):
    l = d.get("лучи", {}).get(луч)
    if l is None: беды.append(f"нет луча {луч}"); continue
    if "сумма" not in l: беды.append(f"{луч}: нет суммы")
    if "элементы" not in l: беды.append(f"{луч}: нет элементов")
for k in ("x", "y"):
    if k not in d.get("баланс", {}): беды.append(f"баланс: нет {k}")
if беды:
    print(f"  {имя}: " + "; ".join(беды)); sys.exit(1)
блоков = sum(len(v.get("элементы", [])) for v in d["лучи"].values())
print(f"  {имя}: ок · блоков {блоков} · баланс x={d['баланс']['x']} y={d['баланс']['y']}")
PY
}

echo "встроенный образец:"
check "демо.json" "assets/демо.json" || FAILS=$((FAILS+1))

echo "живой борт:"
# Адрес берётся из окружения или из настройки приложения: в тесте его не зашиваем.
ADDR="${KREST_URL:-$(defaults read org.aimindset.krest.bar KrestURL 2>/dev/null || true)}"
TMP="$(mktemp)"
if [ -n "$ADDR" ] && curl -sSf --max-time 10 "$ADDR/контекст.json" -o "$TMP" && [ -s "$TMP" ]; then
  check "борт" "$TMP" || FAILS=$((FAILS+1))
else
  if [ -z "$ADDR" ]; then
    echo "  адрес борта не задан: приложение живёт на встроенном образце, это штатно"
  else
    echo "  борт недоступен: приложение покажет ошибку и сохранит последний снимок"
  fi
fi
rm -f "$TMP"

echo "бандл:"
for f in Contents/MacOS/Krest Contents/Info.plist Contents/Resources/демо.json; do
  if [ -f "build/Krest.app/$f" ]; then echo "  есть $f"; else echo "  НЕТ $f"; FAILS=$((FAILS+1)); fi
done

if [ "$FAILS" = 0 ]; then echo "все проверки пройдены"; else echo "провалов: $FAILS"; fi
exit "$FAILS"
