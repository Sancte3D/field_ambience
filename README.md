# Field Ambience

SuperCollider ambient engine (`.scd`), Browser-Panel (`field_ambience_panel.html`), Python OSC/WebSocket-Brücke (`field_ambience_bridge.py`).

## Start

```bash
cd /path/to/field-ambience
python3 field_ambience_bridge.py
```

Dann: `http://127.0.0.1:8080/field_ambience_panel.html` — SuperCollider-Patch laden und Hauptblock ausführen (`Cmd+Enter`).

Abhängigkeiten: `pip install python-osc websockets` (optional: `pyserial` für Pico).

Details und Plan: `ROADMAP.md`.
