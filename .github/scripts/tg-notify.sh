#!/usr/bin/env bash
# Posts a Markdown message to Telegram.
# Reads TG_TOKEN + TG_CHAT from the environment; message from $1 or stdin.
# No-ops (exit 0) when either credential is empty, so callers can run unconditionally.
set -u

TOKEN="${TG_TOKEN:-}"
CHAT="${TG_CHAT:-}"
if [ -z "$TOKEN" ] || [ -z "$CHAT" ]; then
	echo "TG_TOKEN/TG_CHAT not set; skipping Telegram notification" >&2
	exit 0
fi

MSG="${1:-$(cat)}"
MSG=${MSG:0:9450}

curl -sS -X POST \
	--data-urlencode "parse_mode=Markdown" \
	--data-urlencode "disable_web_page_preview=true" \
	--data-urlencode "text=${MSG}" \
	--data-urlencode "chat_id=${CHAT}" \
	"https://api.telegram.org/bot${TOKEN}/sendMessage"
