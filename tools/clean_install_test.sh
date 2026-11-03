#!/bin/bash
# Follows the README quick start from a fresh clone, on whatever machine this runs on, and reports what a judge would see.
# Usage: clean_install_test.sh <git url or path> [workdir]. The image must already be loaded and retagged (README steps 1 and 2).
set -u
SRC="$1"
WORK="${2:-$(mktemp -d)}"
echo "start $(date -u +%TZ) workdir=$WORK"
git clone -q "$SRC" "$WORK/repo" || exit 2
cd "$WORK/repo" || exit 2
git rev-parse --short HEAD
docker rm -f blast-radius-review >/dev/null 2>&1
T0=$(date +%s)
docker compose build > "$WORK/build.log" 2>&1
RC=$?
echo "build rc=$RC secs=$(( $(date +%s)-T0 ))"
if [ "$RC" != "0" ]; then tail -20 "$WORK/build.log"; exit 3; fi
T1=$(date +%s)
docker compose up -d 2>&1 | tail -1
READY=no
for i in $(seq 1 120); do
  if curl -s -m 3 http://127.0.0.1:52773/blastradius/api/health | grep -q '"ready":true'; then READY=yes; break; fi
  sleep 2
done
echo "ready=$READY secs_after_up=$(( $(date +%s)-T1 ))"
curl -s -m 5 http://127.0.0.1:52773/blastradius/api/health; echo
docker logs blast-radius-review 2>&1 | grep -E 'Seeding|seeded|ready:|Startup failed' | cut -c1-160
curl -s -m 5 -o /dev/null -w 'ui %{http_code}\n' http://127.0.0.1:52773/blastradius/ui/index.html
ID=$(curl -s -m 20 -X POST -H 'Content-Type: application/json' -d '{"text":"Retire LAB-OLD; everything moved to LAB-NEW last month.","requester":"clean-install"}' http://127.0.0.1:52773/blastradius/api/change-requests | sed -E 's/.*"id":"([^"]+)".*/\1/')
echo "submitted $ID"
for i in $(seq 1 30); do
  CARD=$(curl -s -m 5 "http://127.0.0.1:52773/blastradius/api/change-requests/$ID")
  if echo "$CARD" | grep -q '"status":"WAITING-OWNERS"'; then break; fi
  sleep 1
done
echo "$CARD" | python3 -c "import json,sys; c=json.load(sys.stdin); print('verdict',c['verdict'],'status',c['status'],'model',c['model'],'mode',c['mode']); [print(' gate:',r) for r in c['gate_reasons']]; print(' tasks:',[t['subject'] for t in c['tasks']])"
tests/run.sh
echo "tests rc=$?"
echo "end $(date -u +%TZ)"
