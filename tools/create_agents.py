"""Create or update Winger's ElevenLabs companion agent.

The companion is the voice on a Winger call: the medicine call when a dose is
due, and the daily check-in. It reads back what a person already approved and
never gives medical advice.

The key is read from ELEVENLABS_API_KEY (or the ignored .el_key file) and is
never written anywhere. The agent is public (the app connects with the id
alone), so no key ships in the app. Pass the printed id to the build:

  python tools/create_agents.py                    # create
  python tools/create_agents.py --update <id>      # change in place
  python tools/create_agents.py --print            # show the request, no key needed
"""
import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

VOICE = "cgSgspJ2msm6clMCkdW9"  # Jessica: a warm premade voice

VARIABLES = {
    "user_name": "Kamla",
    "language": "English",
    "call_kind": "medicine",
    "medicines": "Telma 40, Glycomet 500",
}

PROMPT = """\
You are Winger, a warm and patient companion calling an older person in India,
{{user_name}}, on the phone. Speak {{language}} (simple Hindi or simple English),
slowly, in short sentences. Be kind and respectful; use "ji" in Hindi.

This call is a {{call_kind}} call.

If call_kind is "medicine": tell them it is time for these medicines:
{{medicines}}. Ask if they have taken them.
- If they say yes, or that they will take them now, call confirm_taken. The
  screen then asks them to tick each medicine; tell them so.
- If they say later, call remind_later and say you will remind them again.

If call_kind is "check_in": ask how they are feeling today, and listen.
- Then call report_feeling with feeling "fine", "unwell" or "help".
- "unwell" or "help" tells their family. Say their family has been told and
  will call soon.

Rules you never break:
- Never give medical advice, never suggest a dose, never say why a medicine
  was prescribed. If asked, say their doctor is the right person to ask.
- Never claim to be a doctor, a nurse or an emergency service. In an
  emergency, tell them to call 112 and call report_feeling with "help".
- Never invent a medicine name. Only read the list you were given.
- Keep the call under two minutes, then say goodbye warmly.
"""


def tool(name, description, params=None):
    t = {
        "type": "client",
        "name": name,
        "description": description,
        "expects_response": True,
        "response_timeout_secs": 5,
    }
    if params:
        t["parameters"] = {
            "type": "object",
            "properties": params,
            "required": list(params.keys()),
        }
    return t


def config(voice):
    return {
        "agent": {
            "first_message": "Namaste {{user_name}} ji, Winger bol raha hoon.",
            "language": "en",
            "dynamic_variables": {"dynamic_variable_placeholders": VARIABLES},
            "prompt": {
                "prompt": PROMPT,
                "llm": "gemini-2.5-flash",
                "temperature": 0.4,
                "max_tokens": 150,
                "tools": [
                    tool("confirm_taken", "Call when they say they have taken, or will now take, the medicines."),
                    tool("remind_later", "Call when they want to be reminded again later."),
                    tool(
                        "report_feeling",
                        "Call with how they are feeling on a check-in call.",
                        {"feeling": {"type": "string", "description": "fine, unwell or help"}},
                    ),
                ],
            },
        },
        "tts": {"voice_id": voice, "model_id": "eleven_flash_v2_5"},
        "turn": {"turn_timeout": 10, "silence_end_call_timeout": 30},
        "conversation": {"max_duration_seconds": 180},
    }


def key():
    k = os.environ.get("ELEVENLABS_API_KEY", "").strip()
    if not k:
        f = Path(__file__).resolve().parent.parent / ".el_key"
        if f.exists():
            k = f.read_text().strip()
    return k


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--voice", default=VOICE)
    ap.add_argument("--update", metavar="AGENT_ID")
    ap.add_argument("--print", action="store_true")
    args = ap.parse_args()

    payload = {"conversation_config": config(args.voice)}
    if not args.update:
        payload |= {"name": "Winger companion", "platform_settings": {"auth": {"enable_auth": False}}}
    if args.print:
        print(json.dumps(payload, indent=2))
        return 0

    k = key()
    if not k.startswith("sk_"):
        print("Set ELEVENLABS_API_KEY (or .el_key) to a key starting with sk_.", file=sys.stderr)
        return 1
    url = "https://api.elevenlabs.io/v1/convai/agents/" + (args.update or "create")
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode(),
        method="PATCH" if args.update else "POST",
        headers={"xi-api-key": k, "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            agent_id = json.load(r)["agent_id"]
    except urllib.error.HTTPError as e:
        print(f"FAIL: HTTP {e.code} {e.read()[:600]!r}", file=sys.stderr)
        return 2
    print(f"companion agent {'updated' if args.update else 'created'}: {agent_id}")
    print(f"Build with: --dart-define=WINGER_COMPANION_AGENT_ID={agent_id}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
