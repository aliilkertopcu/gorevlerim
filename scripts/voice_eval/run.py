#!/usr/bin/env python3
"""Regression eval for the voice-to-tasks prompt.

Runs every case in cases.json through the deployed edge function using the
`transcript` override (no audio, no quota) and scores the structure.

Usage:
  set VOICE_EVAL_JWT=<a valid user access token>
  python scripts/voice_eval/run.py [--url https://api.aitopcu.com/functions/v1/voice-to-tasks] [--only <case-id>]

Getting a token: sign in with any test account via the Supabase auth REST API
(see CLAUDE.md), or copy `sb-*-auth-token` from the browser's localStorage.
"""
import argparse, datetime, io, json, os, sys, time, urllib.request, uuid

sys.stdout.reconfigure(encoding="utf-8")
HERE = os.path.dirname(os.path.abspath(__file__))


def call(url, jwt, case):
    boundary = "----voiceeval" + uuid.uuid4().hex
    fields = {
        "transcript": case["transcript"],
        "date": resolve_date(case.get("date", "+0")),
        "group_name": case.get("group_name", ""),
        "context_tasks": json.dumps(case.get("context_tasks", []), ensure_ascii=False) if case.get("context_tasks") else "",
    }
    body = b""
    for k, v in fields.items():
        body += (f"--{boundary}\r\nContent-Disposition: form-data; name=\"{k}\"\r\n\r\n{v}\r\n").encode("utf-8")
    body += f"--{boundary}--\r\n".encode()
    req = urllib.request.Request(url, data=body, headers={
        "Authorization": f"Bearer {jwt}",
        "Content-Type": f"multipart/form-data; boundary={boundary}",
    })
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.load(r)


def a_str(a):
    return f"{a['type']} {a.get('title')} {a.get('subtask_title') or ''} {a.get('target_date') or ''}".strip()


def tr_lower(s):
    return (s or "").replace("İ", "i").replace("I", "ı").lower()


def resolve_date(spec):
    """'+N' → today+N days (server-relative); 'fri' → next Friday (incl. today+1..7); else literal."""
    today = datetime.date.today()
    if isinstance(spec, str) and spec.startswith(("+", "-")):
        return (today + datetime.timedelta(days=int(spec))).isoformat()
    days = {"mon": 0, "tue": 1, "wed": 2, "thu": 3, "fri": 4, "sat": 5, "sun": 6}
    if spec in days:
        delta = (days[spec] - today.weekday()) % 7 or 7
        return (today + datetime.timedelta(days=delta)).isoformat()
    return spec


def score(case, result):
    exp = case["expect"]
    tasks = result.get("tasks", [])
    ignored = result.get("ignored", [])
    checks = []

    def chk(name, ok, detail=""):
        checks.append((name, bool(ok), detail))

    chk("task_count", len(tasks) == exp["task_count"], f"got {len(tasks)}, want {exp['task_count']}")
    if "actions" in exp:
        acts = result.get("actions", [])
        chk("action_count", len(acts) == len(exp["actions"]), f"got {[(a['type'], a.get('title')) for a in acts]}")
        for ea in exp["actions"]:
            m = next((a for a in acts if a["type"] == ea["type"] and tr_lower(ea["title_contains"]) in tr_lower(a.get("title"))), None)
            chk(f"action {ea['type']}~{ea['title_contains']}", m is not None, "missing" if m is None else a_str(m))
            if m and "target_date" in ea:
                want = resolve_date(ea["target_date"])
                chk(f"  target[{ea['title_contains']}]", m.get("target_date") == want, f"got {m.get('target_date')}, want {want}")
    if "ignored_max" in exp:
        chk("ignored_max", len(ignored) <= exp["ignored_max"], f"got {len(ignored)}: {ignored}")
    for e in exp.get("tasks", []):
        key = tr_lower(e["title_contains"])
        match = next((t for t in tasks if key in tr_lower(t["title"])), None)
        chk(f"title~{key}", match is not None, "missing" if match is None else match["title"])
        if match is None:
            continue
        if "subtask_count" in e:
            chk(f"  subtasks[{key}]", len(match.get("subtasks", [])) == e["subtask_count"],
                f"got {len(match.get('subtasks', []))} {match.get('subtasks')}, want {e['subtask_count']}")
        if "date" in e:
            want = resolve_date(e["date"])
            chk(f"  date[{key}]", match.get("date") == want, f"got {match.get('date')}, want {want}")
        if "description_contains" in e:
            chk(f"  desc[{key}]", tr_lower(e["description_contains"]) in tr_lower(match.get("description")),
                f"got {match.get('description')!r}")
    return checks


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--url", default="https://api.aitopcu.com/functions/v1/voice-to-tasks")
    ap.add_argument("--only")
    ap.add_argument("--verbose", action="store_true")
    args = ap.parse_args()
    jwt = os.environ.get("VOICE_EVAL_JWT")
    if not jwt:
        sys.exit("VOICE_EVAL_JWT env var required")

    cases = json.load(io.open(os.path.join(HERE, "cases.json"), encoding="utf-8"))
    total = passed = 0
    for case in cases:
        if args.only and case["id"] != args.only:
            continue
        time.sleep(4)  # Groq free tier: ~8k tokens/min → pace the calls
        try:
            result = call(args.url, jwt, case)
        except Exception as e:  # noqa: BLE001
            print(f"[{case['id']}] ERROR {e}")
            continue
        checks = score(case, result)
        ok = sum(1 for _, c, _ in checks if c)
        total += len(checks)
        passed += ok
        flag = "PASS" if ok == len(checks) else "FAIL"
        print(f"[{flag}] {case['id']}  {ok}/{len(checks)}")
        for name, c, detail in checks:
            if not c or args.verbose:
                print(f"    {'✓' if c else '✗'} {name}: {detail}")
        if args.verbose:
            for t in result.get("tasks", []):
                print(f"      TASK {t['title']} | {t['date']} | {t.get('description','')} | {t.get('subtasks')}")
            print(f"      IGNORED {result.get('ignored')}")
    print(f"\nTOTAL {passed}/{total} checks passed")
    sys.exit(0 if passed == total else 1)


if __name__ == "__main__":
    main()
