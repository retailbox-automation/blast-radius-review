#!/bin/bash
# Installs this folder with IPM into a new namespace of the plain image, in a throwaway container, and runs the first demo step.
# The image must already be loaded and retagged (README steps 1 and 2). Run it from the project folder. Port 52999 stays on this machine.
set -u
IMAGE="${IRIS_IMAGE:-irishealth-community:2027.1.0AI.109.0}"
C=br-ipm-test
API=http://127.0.0.1:52999/blastradius/api
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
docker rm -f "$C" >/dev/null 2>&1
docker run -d --name "$C" -p 127.0.0.1:52999:52773 "$IMAGE" >/dev/null || exit 2
trap 'docker rm -f "$C" >/dev/null 2>&1' EXIT
for i in $(seq 1 60); do
  docker exec "$C" iris qlist 2>/dev/null | grep -q running && break
  sleep 2
done
docker exec "$C" mkdir -p /home/irisowner/pkg
# No macOS metadata: on a Mac, tar otherwise adds a ._ file for every file, and the package loader tries to import them.
COPYFILE_DISABLE=1 tar --no-xattrs -C "$ROOT" -cf - module.xml src ui replay | docker exec -i "$C" tar -C /home/irisowner/pkg -xf -
OUT=$(docker exec -i "$C" iris session IRIS <<'EOS'
zn "%SYS"
set r=##class(%Net.HttpRequest).%New(),r.Server="pm.community.intersystems.com",r.Https=1,r.SSLConfiguration="ISC.FeatureTracker.SSL.Config"
do r.Get("/packages/zpm/latest/installer"),$system.OBJ.LoadStream(r.HttpResponse.Data,"c")
set d="/usr/irissys/mgr/brtest/" do ##class(%File).CreateDirectoryChain(d),##class(SYS.Database).CreateDatabase(d)
set q("Directory")=d do ##class(Config.Databases).Create("BRTEST-DATA",.q)
set p("Globals")="BRTEST-DATA",p("Routines")="BRTEST-DATA" do ##class(Config.Namespaces).Create("BRTEST",.p)
do ##class(%EnsembleMgr).EnableNamespace("BRTEST",1)
zpm "enable -map -globally"
zn "BRTEST"
zpm "load /home/irisowner/pkg"
halt
EOS
)
echo "$OUT" | grep -E 'blast-radius-review.*Activate (SUCCESS|FAILURE)|ERROR' | cut -c1-200
READY=no
for i in $(seq 1 90); do
  if curl -s -m 3 "$API/health" | grep -q '"ready":true'; then READY=yes; break; fi
  sleep 2
done
echo "ready=$READY"
[ "$READY" = yes ] || exit 3
curl -s -m 5 -o /dev/null -w 'ui %{http_code}\n' http://127.0.0.1:52999/blastradius/ui/index.html
ID=$(curl -s -m 30 -X POST -H 'Content-Type: application/json' -d '{"text":"Retire LAB-OLD; everything moved to LAB-NEW last month.","requester":"ipm-test"}' "$API/change-requests" | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])')
for i in $(seq 1 40); do
  CARD=$(curl -s -m 10 "$API/change-requests/$ID")
  if echo "$CARD" | grep -q '"status":"WAITING-OWNERS"'; then break; fi
  sleep 1
done
echo "$CARD" | python3 -c 'import json,sys; c=json.load(sys.stdin); print(c["id"],"verdict",c["verdict"],"status",c["status"],"tasks",len(c["tasks"]))'
