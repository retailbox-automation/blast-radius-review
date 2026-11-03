#!/bin/bash
# Runs after IRIS is up: seeds the demo on first start, then starts the production.
iris session IRIS -U BLASTRADIUS <<'EOS'
do ##class(BlastRadius.Install).OnContainerStart()
halt
EOS
