#!/usr/bin/env python3
"""Runs the demo requests against a live model and leaves recordings in replay/.
Needs the container running with BR_LLM_MODE=live and BR_RECORD=1. Usage: record.py [preset ...]"""
import json
import re
import sys
import time
import urllib.request

BASE = "http://127.0.0.1:52773/blastradius/api"
ANSWERS = {
    "sender:annex-7": {"Confirm": "We will move the Tuesday batch to LAB-NEW.Router before its next run.",
                       "Reject": "Not yet. Our clinic system cannot be re-pointed until next quarter."},
    "diff:ORC-12": {"Confirm": "Accepted for now. The lab reads the ordering provider from the first order in the message.",
                    "Reject": "Not acceptable. The lab needs the ordering provider on every order."},
}


def call(path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, headers={"Content-Type": "application/json"})
    return json.load(urllib.request.urlopen(req, timeout=30))


def settle(cr, statuses, timeout=2000):
    end = time.time() + timeout
    card = {"status": "not read yet"}
    while time.time() < end:
        card = call("/change-requests/" + cr)
        if card["status"] in statuses:
            return card
        time.sleep(3)
    raise SystemExit(f"{cr} did not settle: {card['status']}")


def show(card):
    print(f"\n=== {card['id']} verdict={card['verdict']} agent={card['agent_verdict']} round={card['round']} tools={card['tool_calls']} tokens={card['prompt_tokens']}+{card['completion_tokens']} ms={card['duration_ms']}")
    print("request:", card["text"][:150])
    print("summary:", card["summary"])
    for reason in card["gate_reasons"]:
        print("  gate:", reason)
    denied = [e["tool"] for e in card["audit"] if e["outcome"] == "DENIED"]
    if denied:
        print("  denied:", denied)
    print("  tools:", " ".join(e["tool"] for e in card["audit"]))
    for number in unsupported_numbers(card):
        print(f"  WARNING: {number} in the summary is in no tool result, do not keep this recording")
    sys.stdout.flush()


def unsupported_numbers(card):
    """The summary is the model's own wording, so its numbers are compared with what the tools returned."""
    tools = json.dumps({k: v for k, v in card.items() if k != "summary"})
    return [n for n in re.findall(r"\b\d+\b", card["summary"] or "") if not re.search(rf"\b{n}\b", tools)]


def run(text, combo=None):
    """combo maps a task key to Confirm or Reject. Tasks not named are confirmed."""
    cr = call("/change-requests", {"text": text, "requester": "integration-lead"})["id"]
    card = settle(cr, ("DONE", "WAITING-OWNERS"))
    while card["status"] == "WAITING-OWNERS":
        open_tasks = [t for t in card["tasks"] if not t["complete"]]
        if not open_tasks:
            time.sleep(2)
            card = call("/change-requests/" + cr)
            continue
        for task in open_tasks:
            key = "sender:annex-7" if "annex-7" in task["subject"] else "diff:" + task["subject"].split("review ")[-1]
            action = (combo or {}).get(key, "Confirm")
            comment = ANSWERS.get(key, {}).get(action, "Accepted." if action == "Confirm" else "Not acceptable.")
            call("/tasks/" + str(task["id"]), {"action": action, "comment": comment})
            print(f"  answered {key}: {action}")
        time.sleep(3)
        card = call("/change-requests/" + cr)
        if card["status"] == "WAITING-OWNERS" and not [t for t in card["tasks"] if not t["complete"]]:
            time.sleep(5)
            card = call("/change-requests/" + cr)
        if card["status"] == "IN-REVIEW":
            card = settle(cr, ("DONE",))
    show(card)
    return card


if __name__ == "__main__":
    presets = {p["id"]: p for p in call("/presets")}
    wanted = sys.argv[1:] or list(presets)
    for pid in wanted:
        print(f"\n##### preset {pid}", time.strftime("%H:%M:%S", time.gmtime()))
        if pid == "retire":
            for combo in ({}, {"sender:annex-7": "Reject"}, {"diff:ORC-12": "Reject"}, {"sender:annex-7": "Reject", "diff:ORC-12": "Reject"}):
                print("owner answers:", combo or "both confirm")
                run(presets[pid]["text"], combo)
        else:
            run(presets[pid]["text"])
    print("\nALL RECORDED", time.strftime("%H:%M:%S", time.gmtime()))
