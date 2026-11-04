#!/bin/bash
# Checks that a live review survives a model turn with no text and no tool calls.
# AI Hub sends such a turn back without its content field, and an OpenAI-compatible server such as
# Ollama rejects the whole request. This runs one live review against tools/strict_openai.py, a stand-in
# that answers the first turn with empty content and rejects that malformed message the way Ollama does.
# No model and no key are needed. The container is recreated in live mode for the check, then put back
# in replay mode if it was running. Prints PASS or FAIL and exits 0 only on PASS.
# Usage: tools/empty_turn_check.sh [port]
set -u
cd "$(dirname "$0")/.." || exit 2
PORT="${1:-18779}"
LOG="$(mktemp -t empty_turn_check)"
COMPOSE="docker compose -f docker-compose.yml -f docker-compose.dev.yml"
API=http://127.0.0.1:52773/blastradius/api

WAS_RUNNING=$(docker inspect -f "{{.State.Running}}" blast-radius-review 2>/dev/null || echo false)
python3 -I tools/strict_openai.py "$PORT" "$LOG" &
SERVER=$!
trap 'kill $SERVER 2>/dev/null' EXIT
sleep 1

docker rm -f blast-radius-review >/dev/null 2>&1
BR_LLM_MODE=live BR_LLM_PROVIDER=openai BR_LLM_MODEL=stand-in BR_LLM_API_KEY=none \
BR_LLM_BASE_URL="http://host.docker.internal:$PORT/v1" BR_LLM_TIMEOUT_S=60 \
  $COMPOSE up -d --force-recreate >/dev/null 2>&1
for i in $(seq 1 60); do curl -s -m 3 "$API/health" | grep -q '"ready":true' && break; sleep 2; done
bash tools/reload.sh

ID=$(curl -s -m 10 -X POST -H 'Content-Type: application/json' -d '{"text":"Empty turn check"}' "$API/change-requests" \
  | python3 -I -c 'import json,sys; print(json.load(sys.stdin).get("id",""))')
for i in $(seq 1 45); do
  CARD=$(curl -s -m 5 "$API/change-requests/$ID")
  echo "$CARD" | grep -q '"status":"IN-REVIEW"' || break
  sleep 2
done
REASONS=$(echo "$CARD" | python3 -I -c 'import json,sys; print(" | ".join(json.load(sys.stdin).get("gate_reasons") or []))')
REQUESTS=$(wc -l < "$LOG" | tr -d ' ')
REJECTED=$(grep -c '"status": 400' "$LOG")
REMINDED=$(grep '"status": 200' "$LOG" | grep -c "You have not called SubmitDecision")

# Leave the container as it was: running in replay mode, or not running at all.
docker rm -f blast-radius-review >/dev/null 2>&1
[ "$WAS_RUNNING" = "true" ] && $COMPOSE up -d >/dev/null 2>&1

echo "review $ID: $REASONS"
echo "requests to the stand-in: $REQUESTS, rejected: $REJECTED, reminders accepted: $REMINDED"
grep "You have not called SubmitDecision" "$LOG" | head -1 | python3 -I -c 'import json,sys; d=json.loads(sys.stdin.read()); print("reminder request, status", d["status"], "roles:", " > ".join(m["role"] + ("(no content)" if "content" not in m else "") for m in d["messages"]))'
if [ "$REMINDED" -ge 1 ] && [ "$REJECTED" = "0" ] && ! echo "$REASONS" | grep -q "The agent failed"; then
  echo "PASS: the reminder after an empty turn was accepted"
  rm -f "$LOG"
  exit 0
fi
echo "FAIL: request log kept in $LOG"
exit 1
