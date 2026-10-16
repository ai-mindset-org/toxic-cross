#!/bin/bash
# Reversible installation of this app only; no changes to other processes or schedulers.
set -euo pipefail
umask 077
cd "$(dirname "$0")"
label=org.aimindset.krest.bar
domain="gui/$(id -u)"
target="$HOME/Applications/krest.app"
agent="$HOME/Library/LaunchAgents/$label.plist"
backup="$HOME/Library/Application Support/Krest/Backups/$(date +%Y%m%d-%H%M%S)"
staged="$HOME/Applications/.krest-install-$$.app"
mkdir -p "$backup" "$HOME/Applications" "$(dirname "$agent")"
codesign --verify --deep --strict build/Krest.app
if [ -d "$target" ]; then ditto "$target" "$backup/krest.app"; fi
if [ -f "$agent" ]; then cp "$agent" "$backup/LaunchAgent.plist"; fi
if [ -f "$HOME/Library/Application Support/Krest/history-v1.json" ]; then cp "$HOME/Library/Application Support/Krest/history-v1.json" "$backup/history-v1.json"; fi
if [ -f "$HOME/Library/Application Support/Krest/check-ins-v1.json" ]; then cp "$HOME/Library/Application Support/Krest/check-ins-v1.json" "$backup/check-ins-v1.json"; fi
defaults export "$label" "$backup/preferences.plist" >/dev/null 2>&1 || true
ditto build/Krest.app "$staged"
codesign --verify --deep --strict "$staged"
rollback() {
  echo "Установка не завершена; возвращаем резервную копию: $backup" >&2
  launchctl bootout "$domain/$label" >/dev/null 2>&1 || true
  if [ -d "$target" ]; then mv "$target" "$backup/failed.app"; fi
  if [ -d "$backup/krest.app" ]; then ditto "$backup/krest.app" "$target"; fi
  if [ -f "$backup/LaunchAgent.plist" ]; then
    cp "$backup/LaunchAgent.plist" "$agent"
    launchctl bootstrap "$domain" "$agent" || true
  fi
}
trap rollback ERR
launchctl bootout "$domain/$label" >/dev/null 2>&1 || true
# Refuse to replace a remaining manually launched instance. Never kill unrelated names.
for attempt in 1 2 3 4 5; do
  if ! pgrep -f "^$target/Contents/MacOS/Krest$" >/dev/null; then break; fi
  sleep 1
done
if pgrep -f "^$target/Contents/MacOS/Krest$" >/dev/null; then
  echo "Экземпляр приложения ещё работает" >&2; false
fi
if [ -d "$target" ]; then mv "$target" "$backup/replaced.app"; fi
mv "$staged" "$target"
sed "s|@BIN@|$target/Contents/MacOS/Krest|" LaunchAgent.plist.in > "$agent"
plutil -lint "$agent"
launchctl bootstrap "$domain" "$agent"
sleep 2
pgrep -f "^$target/Contents/MacOS/Krest$" >/dev/null
codesign --verify --deep --strict "$target"
trap - ERR
printf 'Установлено: %s\nРезервная копия: %s\n' "$target" "$backup"
