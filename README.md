# Uriges Doppelkopf (Godot 4.7 Cross-Platform App & Web + Schreibblock)

Cross-Platform Doppelkopf-App (Android / Desktop / HTML5-WebAssembly) inklusive digitalem & physischem **Schreibblock-Tracker**, **WSS-Signaling** und **WebRTC + TURN (TCP/TLS Port 443)** für zuverlässiges Cross-Play auch in restriktiven Hochschul-WLANs (z. B. eduroam).

## Voraussetzungen
- **Godot Engine 4.7.2** (Renderer: `GL Compatibility`)
- Optional für eigenen Signaling-Server: **Python 3.10+** (keine externen `pip`-Pakete nötig)

## Projekt starten & testen
1. Repository klonen und in Godot 4.7.2 öffnen (`project.godot`), oder per CLI:
   ```powershell
   Godot_v4.7.2-stable_win64_console.exe --headless --path . --import
   Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/run_tests.gd
   ```
2. **Signaling-Server starten** (lokal Port `8765`, in Produktion hinter HTTPS/WSS-Reverse-Proxy auf Port `443`):
   ```powershell
   python server/signaling_server.py
   ```

## Export (Android & Web)
In `export_presets.cfg` sind bereits Presets für **Web** und **Android** (`arm64-v8a`) vorkonfiguriert.
```powershell
Godot_v4.7.2-stable_win64_console.exe --rendering-driver opengl3 --path . --export-debug "Android" "build/android/UrigesDoppelkopf.apk"
```

## Projektstruktur
- `scripts/core/` — `card_data.gd`, `rule_config.gd`, `doko_engine.gd`, `doko_bot.gd`
- `scripts/network/` — `network_manager.gd` (WSS + WebRTC + TURN-443 + Relay-Fallback), `qr_generator.gd`
- `scripts/schreibblock/` — `schreibblock_store.gd` (Persistenz, Statistiken, Kassen-Abrechnung)
- `scripts/ui/` — `main.gd`, `hand_fan.gd`, `card_view.gd`, `schreibblock_panel.gd`, `lobby_panel.gd`, `rules_dialog.gd`, `points_chart.gd`, `theme_helper.gd`, `audio_fx.gd`
- `server/` — `signaling_server.py` (Zero-Dependency Python WebSocket-Signaling & Relay)
- `tests/` — `run_tests.gd` (116 automatisierte Unit-Tests), `capture_screenshots.gd`
