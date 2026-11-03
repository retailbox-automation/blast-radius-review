#!/usr/bin/env python3
"""Waits for a change request to settle and prints its card. Usage: show.py CR-0142 [wait_seconds]"""
import json
import sys
import time
import urllib.request

cr = sys.argv[1]
wait = int(sys.argv[2]) if len(sys.argv) > 2 else 0
base = "http://127.0.0.1:52773/blastradius/api"
deadline = time.time() + wait
while True:
    card = json.load(urllib.request.urlopen(f"{base}/change-requests/{cr}", timeout=20))
    if card["status"] != "IN-REVIEW" or time.time() > deadline:
        break
    time.sleep(3)

print(f"{card['id']}  status={card['status']}  verdict={card['verdict']}  agent={card['agent_verdict']}  round={card['round']}")
print(f"mode={card['mode']} model={card['model']} tokens={card['prompt_tokens']}+{card['completion_tokens']} tools={card['tool_calls']} ms={card['duration_ms']} cost={card.get('cost_usd')}")
print("summary:", card["summary"])
for reason in card["gate_reasons"]:
    print("  gate:", reason)
for task in card["tasks"]:
    print(f"  task {task['id']} [{task['role']}] complete={task['complete']} action={task['action']}: {task['subject']} / {task['message']}")
for event in card["audit"]:
    print(f"  r{event['round']} {event['outcome']:8} {event['tool']} {event['arguments'][:110]}")
for rnd in card["rounds"]:
    print(f"  round {rnd['round']}: agent={rnd['agent_verdict']} final={rnd['final_verdict']} tools={rnd['tool_calls']} tokens={rnd['prompt_tokens']}+{rnd['completion_tokens']}")
