#!/bin/bash
# Recompiles everything in the running container and restarts the production so hosts pick up the new code.
set -u
CONTAINER="${BR_CONTAINER:-blast-radius-review}"
docker exec -i "$CONTAINER" iris session IRIS -U BLASTRADIUS <<'EOS' | grep -E -i 'error|fail|^RELOAD|^errs' | grep -v -E 'errs=0|Detected 0' | cut -c1-400
set sc=$system.OBJ.LoadDir("/home/irisowner/dev/src","ck-d",.e,1)
set sc2=$system.OBJ.LoadDir("/home/irisowner/dev/tests","ck-d",.e2,1)
write "RELOAD src=",+sc," tests=",+sc2," errs=",+$get(e)+$get(e2),!
if sc,sc2 { do ##class(Ens.Director).RestartProduction() write "RELOAD production restarted",! }
halt
EOS
