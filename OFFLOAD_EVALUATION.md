# Evaluation: `gemini-api-offload` im Praxis-Einsatz ("Uriges Doppelkopf")

## 1. Gesamtfazit & Token-Ersparnis
Das Repository [`RaptorClash/gemini-api-offload`](https://github.com/RaptorClash/gemini-api-offload) wurde über den gesamten Entwicklungszyklus von **Uriges Doppelkopf** (Analyse von `06_Zaubera`, GDScript-Generierung und 10-stufiger multimodaler `subagent-critic` Screenshot-Loop) produktiv eingesetzt.

Gemessene Metriken aus `database/quota_stats.db` (`offload_cli.py status`):
- **Ausgelagerte API-Calls:** 17
- **Ausgelagerte Input-Tokens:** 348.227
- **Ausgelagerte Output-Tokens:** 26.632
- **Ausgelagerte Thought-Tokens:** 23.892
- **Gesamt ausgelagerte Tokens:** **398.751 Tokens**
- **Geschätzte Ersparnis (API-Gegenwert):** ~\$0,25 (bei 1-Key Free-Tier-Nutzung = \$0,00 reale Kosten)

---

## 2. Stärken von `gemini-api-offload`
1. **Zero-Dependency-Architektur:** Läuft komplett mit der Python-Standardbibliothek (`urllib`, `sqlite3`, `threading`). Die 20 mitgelieferten Unit-Tests liefen sofort ohne `pip install` fehlerfrei durch.
2. **Automatisches Multi-Tier-Fallback & Cooldown-Tracking:** In der Praxis waren `gemini-4-hydrogen` und `gemini-3.8-flash` auf dem genutzten API-Key nicht verfügbar bzw. erschöpft. Der `GeminiOffloadRouter` hat dies selbstständig erkannt, in `quota_stats.db` vermerkt und nahtlos auf `gemini-3-flash-preview` (`flash3-high`) und `gemini-3.1-flash-lite` (`flash31-lite-high`) umgeschaltet – ohne dass ein einziger Workflow-Schritt abgebrochen ist.
3. **1-Shot `context_files`-Attach:** Die Analyse von `06_Zaubera` (6 bzw. 5 GDScript-/Config-Dateien pro Request) sparte massiv lokalen Antigravity-Kontext, da keine großen Fremd-Dateien in den Haupt-Agent-Kontext geladen werden mussten.
4. **Sicherheit:** `.env`- und Key-Dateien werden strikt maskiert und vor dem Versand an die externe API blockiert (`is_secret_file_path`).

---

## 3. Schwächen & Konkrete Verbesserungsvorschläge für das Repo
1. **Fehlender Bild-/Multimodal-Support im Standard-MCP (`offload_prompt`):**
   - *Beobachtung:* `server/mcp_server.py` und `GeminiOffloadRouter.generate()` unterstützen aktuell ausschließlich Text- und Code-Dateien (`context_files` werden mit `read_text()` als UTF-8 gelesen). Für visuelle UI-/Screenshot-Reviews (`subagent-critic` mit PNG-Captures aus Godot) fehlte die Möglichkeit, Bilder als `inlineData` (`image/png`, Base64) mitzugeben.
   - *Workaround im Projekt:* Wir haben in [`.tools/offload_cli.py`](file:///c:/Users/nicol/OneDrive%20-%20studmail.w-hs.de/Antigravity_Projekte/08_Doppelkopf_P2P_turn_servern/.tools/offload_cli.py) ein `--images`-Flag ergänzt, das `GeminiOffloadRouter.generate_raw()` direkt mit `inlineData`-Parts aufruft.
   - *Empfehlung für `gemini-api-offload`:* Ein optionales `image_files: List[str]`-Argument direkt in `offload_prompt` (MCP + `router.py`) aufnehmen.
2. **Code-Generierung bei Fallback auf kleinere Modelle (`flash-lite`):**
   - *Beobachtung:* Bei sehr großen, komplexen Einzeldateien (wie `doko_engine.gd`) neigte das Fallback-Modell `gemini-3.1-flash-lite` dazu, Hilfsmethoden zu stubben (`pass`) oder Markdown-Erklärungen vor/nach dem Code einzufügen.
   - *Empfehlung:* Für komplexe Logik entweder in kleinere Teil-Prompts splitten oder Post-Processing-Stripper (Fences & Prosa entfernen) + automatischen Compiler-Check (`godot --headless --check-only`) vorschalten.
3. **Hardcodierter Pfad in `mcp_config.json`:**
   - *Beobachtung:* `mcp_config.json` enthält einen statischen Entwickler-Pfad (`C:/Marvin/...`), der bei Installation über `install_plugin.ps1` auf anderen Rechnern angepasst werden muss.
   - *Empfehlung:* `install_plugin.ps1` sollte `mcp_config.json` automatisch mit `$TargetDir` aktualisieren.
