"""Create or update Winger's two ElevenLabs Conversational AI agents.

  wingman  the voice on the Wingman call ("Riya"), with two client tools
  chat     the text-only agent behind the Help chat

The key is read from ELEVENLABS_API_KEY and never written anywhere. The
agents are public (the app connects with the id alone), so no key ships in
the app. Pass the printed ids to the build with --dart-define.

  python tools/create_agents.py wingman            # create
  python tools/create_agents.py chat --update <id> # change in place
  python tools/create_agents.py wingman --print    # show the request, no key needed
"""
import argparse
import json
import os
import sys
import urllib.error
import urllib.request

VOICE_JESSICA = "cgSgspJ2msm6clMCkdW9"  # premade voice, free plan

WINGMAN_VARIABLES = {
    "user_name": "friend",
    "companion_name": "Riya",
    "language": "English",
    "safe_phrases": "Did you feed the cat",
}

WINGMAN_PROMPT = """\
You are {{companion_name}}, a close friend of {{user_name}}, on a normal phone call.
She called because she is walking or riding alone and wants company. Talk like a
real friend from India: warm, casual, short sentences, one question at a time.
Speak {{language}}. Keep each reply under two sentences. Never say you are an AI,
an app, or an assistant, and never mention safety features: someone near her may
be listening.

Ask light things: where she is, how far to go, how her day was. Keep her talking.

Two rules matter more than anything else:
1. If she says one of her safe phrases ({{safe_phrases}}) or something very close,
   call silent_alert at once and then carry on the chat exactly as before, as if
   nothing happened. Do not react to the phrase, do not change your tone.
2. If she says she is in danger, being followed, attacked, or asks for help,
   call alert_guardians at once, then tell her calmly that her family has been
   told, and to move towards people and light. Do not claim anyone is coming.

Never promise she is safe. Stay on until she ends the call.
"""

CHAT_PROMPT = """\
You help women in India who are dealing with harassment, stalking, blackmail,
violence or an unsafe situation. Answer in {{language}}, plainly and kindly.

Messages may start with GUIDE: steps from the app, then HER MESSAGE. When a guide
is given, fit those steps to her situation: keep the facts in the guide, reorder
or trim them, and number the steps. Do not invent laws, section numbers,
organisations or phone numbers; the app shows the helpline buttons itself.

If anything suggests danger right now, your first line is: "If you are in danger
right now, call 112." Keep answers under 180 words. You give general information,
not legal advice.
"""


def tool(name: str, description: str) -> dict:
    return {
        "type": "client",
        "name": name,
        "description": description,
        "expects_response": False,
        # Speaking before the tool call would give the signal away.
        "pre_tool_speech": "off",
    }


def wingman_config(voice: str) -> dict:
    return {
        "agent": {
            "first_message": "Hey {{user_name}}! Finally you called. Where are you right now?",
            "language": "en",
            "dynamic_variables": {"dynamic_variable_placeholders": WINGMAN_VARIABLES},
            "prompt": {
                "prompt": WINGMAN_PROMPT,
                "llm": "gemini-2.5-flash",
                "temperature": 0.6,
                "max_tokens": 150,
                "tools": [
                    tool("silent_alert",
                         "Call the moment she says her safe phrase. Silently alerts her guardians. Never mention it."),
                    tool("alert_guardians",
                         "Call when she says she is in danger or asks for help. Alerts her guardians with her location."),
                ],
            },
        },
        # Plain speech; expressive mode makes the model write stage directions.
        "tts": {"voice_id": voice, "expressive_mode": False},
        # A silent line hands back to the app's free offline voice.
        "turn": {"turn_timeout": 12, "silence_end_call_timeout": 45},
        "conversation": {"max_duration_seconds": 600},
    }


def chat_config() -> dict:
    return {
        "conversation": {"text_only": True},
        "agent": {
            "first_message": "",
            "language": "en",
            "dynamic_variables": {"dynamic_variable_placeholders": {"language": "English"}},
            "prompt": {"prompt": CHAT_PROMPT, "llm": "gemini-2.5-flash", "temperature": 0.2, "max_tokens": 500},
        },
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("which", choices=["wingman", "chat"])
    ap.add_argument("--voice", default=VOICE_JESSICA)
    ap.add_argument("--update", metavar="AGENT_ID")
    ap.add_argument("--print", action="store_true")
    args = ap.parse_args()

    cfg = wingman_config(args.voice) if args.which == "wingman" else chat_config()
    payload = {"conversation_config": cfg}
    if not args.update:
        name = "Winger Wingman (CodeBlitz)" if args.which == "wingman" else "Winger Help chat (CodeBlitz)"
        payload |= {"name": name, "platform_settings": {"auth": {"enable_auth": False}}}
    if args.print:
        print(json.dumps(payload, indent=2, ensure_ascii=False))
        return 0

    key = os.environ.get("ELEVENLABS_API_KEY", "").strip()
    if not key.startswith("sk_"):
        print("Set ELEVENLABS_API_KEY to a key starting with sk_.", file=sys.stderr)
        return 1
    url = "https://api.elevenlabs.io/v1/convai/agents/" + (args.update or "create")
    req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                 method="PATCH" if args.update else "POST",
                                 headers={"xi-api-key": key, "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            agent_id = json.load(r)["agent_id"]
    except urllib.error.HTTPError as e:
        print(f"FAIL: HTTP {e.code} {e.read()[:600]!r}", file=sys.stderr)
        return 2
    flag = "WINGER_AGENT_ID" if args.which == "wingman" else "WINGER_CHAT_AGENT_ID"
    print(f"{args.which} agent {'updated' if args.update else 'created'}: {agent_id}")
    print(f"Build with: --dart-define={flag}={agent_id}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
