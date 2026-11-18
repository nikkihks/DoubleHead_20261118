"""
CLI Wrapper for `gemini-api-offload` in 08_Doppelkopf_P2P_turn_servern.
Supports:
  - `prompt`: 1-shot stateless offload with context_files + optional PNG/JPG images (for subagent-critic)
  - `agent`: Mode 2 autonomous agent loop (defaults to flash35-lite-high, 500 RPD)
  - `status`: Show offloaded tokens, RPD cooldowns, and savings
"""

from __future__ import annotations

import argparse
import base64
import json
import sys
from pathlib import Path
from typing import Any, Dict, List

PROJECT_ROOT = Path(__file__).resolve().parent.parent
OFFLOAD_ROOT = PROJECT_ROOT / ".tools" / "gemini-api-offload"
if str(OFFLOAD_ROOT) not in sys.path:
    sys.path.insert(0, str(OFFLOAD_ROOT))

from server.agent_loop import AutonomousAgentLoop  # noqa: E402
from server.router import GeminiOffloadRouter, is_secret_file_path  # noqa: E402


def _make_router() -> GeminiOffloadRouter:
    return GeminiOffloadRouter(config_dir=PROJECT_ROOT)


def cmd_prompt(args: argparse.Namespace) -> int:
    router = _make_router()
    prompt_text = args.prompt or ""
    if args.prompt_file:
        prompt_text = Path(args.prompt_file).read_text(encoding="utf-8")
    if not prompt_text.strip():
        print("Error: empty prompt", file=sys.stderr)
        return 1

    parts: List[Dict[str, Any]] = []
    for fpath in args.context_files or []:
        p = Path(fpath)
        if is_secret_file_path(p):
            parts.append({"text": f"--- FILE ({p.name}): [SECURITY BLOCKED] ---"})
            continue
        if p.exists() and p.is_file():
            content = p.read_text(encoding="utf-8", errors="replace")
            parts.append({"text": f"--- FILE: {p.as_posix()} ---\n{content}\n--- END FILE ---"})

    for img_path in args.images or []:
        ip = Path(img_path)
        if ip.exists() and ip.is_file():
            ext = ip.suffix.lower()
            mime = "image/png" if ext == ".png" else "image/jpeg"
            b64 = base64.b64encode(ip.read_bytes()).decode("ascii")
            parts.append({"inlineData": {"mimeType": mime, "data": b64}})

    parts.append({"text": prompt_text})
    contents = [{"role": "user", "parts": parts}]

    res = router.generate_raw(
        contents=contents,
        model_alias=args.model,
        system_instruction=args.system,
        temperature=args.temperature,
        allow_fallback=True,
        mode="stateless",
    )

    text = res.get("text", "")
    if args.out:
        out_path = Path(args.out)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(text, encoding="utf-8")

    meta = {
        "model_used": res.get("model_used"),
        "model_alias": res.get("model_alias"),
        "input_tokens": res.get("input_tokens"),
        "output_tokens": res.get("output_tokens"),
        "total_tokens": res.get("total_tokens"),
        "out_file": args.out,
    }
    print("=== OFFLOAD_META ===")
    print(json.dumps(meta, ensure_ascii=False))
    if not args.out or args.print_text:
        print("=== OFFLOAD_TEXT ===")
        print(text)
    return 0


def cmd_agent(args: argparse.Namespace) -> int:
    router = _make_router()
    task_text = args.task or ""
    if args.task_file:
        task_text = Path(args.task_file).read_text(encoding="utf-8")
    loop = AutonomousAgentLoop(
        router=router,
        workspace_path=str(PROJECT_ROOT),
        model_alias=args.model,
        max_steps=args.max_steps,
    )
    res = loop.run(task_text)
    print(json.dumps(res, ensure_ascii=False, indent=2))
    return 0


def cmd_status(_args: argparse.Namespace) -> int:
    router = _make_router()
    summary = router.quota_tracker.get_summary()
    cooldowns = router.quota_tracker.get_active_cooldowns()
    print(
        json.dumps(
            {
                "keys_configured": len(router.api_keys),
                "summary": summary,
                "active_cooldowns": cooldowns,
            },
            ensure_ascii=False,
            indent=2,
        )
    )
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Gemini API Offload CLI")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_prompt = sub.add_parser("prompt")
    p_prompt.add_argument("--model", default="hydrogen-high")
    p_prompt.add_argument("--prompt", default="")
    p_prompt.add_argument("--prompt-file", default="")
    p_prompt.add_argument("--system", default=None)
    p_prompt.add_argument("--context-files", nargs="*", default=[])
    p_prompt.add_argument("--images", nargs="*", default=[])
    p_prompt.add_argument("--temperature", type=float, default=0.2)
    p_prompt.add_argument("--out", default="")
    p_prompt.add_argument("--print-text", action="store_true")
    p_prompt.set_defaults(func=cmd_prompt)

    p_agent = sub.add_parser("agent")
    p_agent.add_argument("--model", default="flash35-lite-high")
    p_agent.add_argument("--task", default="")
    p_agent.add_argument("--task-file", default="")
    p_agent.add_argument("--max-steps", type=int, default=15)
    p_agent.set_defaults(func=cmd_agent)

    p_status = sub.add_parser("status")
    p_status.set_defaults(func=cmd_status)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
