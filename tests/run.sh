#!/bin/bash
# Runs the whole suite inside the running container. Exit code 0 means every assertion passed.
# Usage: tests/run.sh [comma-separated test classes]
set -u
CLASSES="${1:-GateTest,PolicyTest,EvidenceTest,EndToEndTest}"
CONTAINER="${BR_CONTAINER:-blast-radius-review}"
OUT=$(docker exec -i "$CONTAINER" iris session IRIS -U BLASTRADIUS <<EOS
do ##class(BlastRadiusTests.Runner).Go("$CLASSES")
halt
EOS
)
echo "$OUT" | grep -E '^(FAILED|RESULT|Could not)'
echo "$OUT" | grep -q '^RESULT passed=[1-9][0-9]* failed=0$'
