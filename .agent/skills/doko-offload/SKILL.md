---
name: doko-offload
description: Orchestrates `subagent-researcher`, `subagent-coder`, and `subagent-critic` via `.tools/offload_cli.py` and `.tools/gemini-api-offload` to save Antigravity tokens.
---

# Doppelkopf Gemini API Offload Skill

Alle token-intensiven Aufgaben werden über `.tools/offload_cli.py` (basierend auf `.tools/gemini-api-offload`) auf Google AI Studio ausgelagert:

- **1-Shot Prompt + Kontext-Dateien (`hydrogen-high` / `hydrogen-xhigh`, 20 RPD)**:
  ```powershell
  python .tools/offload_cli.py prompt --model hydrogen-high --context-files path/to/a.gd path/to/b.gd --prompt "..." --out .scratch/out.md
  ```
- **Multimodal Critic mit Screenshots (`subagent-critic`)**:
  ```powershell
  python .tools/offload_cli.py prompt --model hydrogen-xhigh --images .scratch/shot1.png --context-files scripts/ui.gd --prompt-file .scratch/critic_prompt.txt --out .scratch/critic_review.md
  ```
- **Autonomous Agent Loop (`flash35-lite-high`, 500 RPD)**:
  ```powershell
  python .tools/offload_cli.py agent --model flash35-lite-high --task "..." --max-steps 15
  ```
- **Quota & Token-Ersparnis prüfen**:
  ```powershell
  python .tools/offload_cli.py status
  ```
