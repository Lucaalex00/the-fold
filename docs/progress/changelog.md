# Changelog — The Fold

## 2026-05-18 — STEP 1-4: Core Autoload

### Aggiunto
- `GameState.gd`: OminoData inner class, segnali omino_died/era_changed/prestige_triggered/cohesion_changed, costanti ERA_OMINI_LIMIT/ERA_STAT_CAP, variabili globali (era, step, prestige, day, divine_energy, distance_from_center), metriche run, reset_run()
- `TimeManager.gd`: counter distanza in _process() ogni frame, _calculate_speed() con moltiplicatori, apply_offline_progress(), daily reset alle 00:00 tramite confronto stringa data
- `SaveManager.gd`: save/load JSON su user://save.json, serializzazione completa omini+DNA (Color→Array), save_to_memory_book(), calcolo e applicazione offline progress all'avvio
- `EventManager.gd`: GameEvent inner class, MAX 3 social + MAX 1 cosmic, caricamento events.json, scadenza eventi, genera cosmic con probabilità 30%/giorno
- `project.godot`: autoload configurati (GameState, TimeManager, EventManager, SaveManager), viewport 390x844, stretch canvas_items
- `docs/`: struttura completa 12 feature docs + changelog

