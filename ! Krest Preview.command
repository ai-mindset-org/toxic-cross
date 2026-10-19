#!/bin/bash
# Human-run preview of the public fictional workspace. No private API or data.
set -eu
cd "$(dirname "$0")"
preview_port=8786
preview_reuse=0
while lsof -nP -iTCP:"$preview_port" -sTCP:LISTEN >/dev/null 2>&1; do
  if curl -fsS --connect-timeout 1 --max-time 2 "http://localhost:$preview_port/demo.html" 2>/dev/null | cmp -s site/demo.html -; then
    preview_reuse=1
    break
  fi
  preview_port=$((preview_port + 1))
  if [ "$preview_port" -gt 8796 ]; then
    echo 'Preview ports 8786–8796 are busy. Choose a free port manually.'
    exit 1
  fi
done
preview_ip=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)
preview_desktop="http://localhost:$preview_port/demo.html#research"
echo "Desktop: $preview_desktop"
if [ -n "$preview_ip" ]; then echo "Phone: http://$preview_ip:$preview_port/demo.html#research"; fi
echo 'Fictional data only. Press Control-C here to stop this preview.'
if [ "$preview_reuse" -eq 1 ]; then
  echo 'Reusing the existing Krest preview.'
  /usr/bin/open "$preview_desktop"
  exit 0
fi
# Opening the browser is deliberate when this command is double-clicked.
(sleep 1; /usr/bin/open "$preview_desktop") &
python3 -m http.server "$preview_port" --bind 0.0.0.0 --directory site
