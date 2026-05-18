# Changelog — The Fold

## 2026-05-18 — STEP 6: CultureSystem, ResourceSystem, Planet

### Aggiunto
- `CultureSystem.gd`: `calculate_cohesion()` con formula esatta da CLAUDE.md (warrior ratio, same origin bonus, penalità >4 origini), `get_cohesion_state()`, `get_war_penalty()`, autoconnect su `omino_died`
- `ResourceSystem.gd`: calcolo harvest/fishing/labor/trade da stat omini vivi, `food_deficit_days`, `daily_reset()`
- `Planet.gd`: setup pianeta, `initialize_founders()` crea Cubo+Triangolo, gestione lista omini per pianeta
- `project.godot`: TraitDatabase, OminoGenerator, GeneticSystem, CultureSystem, ResourceSystem aggiunti come Autoload

---

## 2026-05-18 — STEP 5: Sistema Omini & Genetico

### Aggiunto
- `TraitDatabase.gd`: carica traits.json, `get_base_stats()` con variazione ±20%, `is_valid_trait()`
- `OminoGenerator.gd`: `create_founders()` — Cubo Giallo (builder) + Triangolo Rosso (warrior) con DNA fissi da lore; `create_omino()` generico; `generate_name()` da sillabe; `generate_random_dna()`
- `Omino.gd`: `calculate_death_probability()` — curva 0%→80% tra 20-30 anni, mai 100%; `roll_death()`; `die()` che chiama `save_to_memory_book()`
- `GeneticSystem.gd`: `generate_child()` — 70% media stat, bonus intelligenza +5%/gen, tratto dominante per score, tratto secondario da era 2+, mix DNA colori con mutazione H

---

## 2026-05-18 — STEP 1-4: Core Autoload

### Aggiunto
- `GameState.gd`: OminoData inner class, segnali omino_died/era_changed/prestige_triggered/cohesion_changed, costanti ERA_OMINI_LIMIT/ERA_STAT_CAP, variabili globali (era, step, prestige, day, divine_energy, distance_from_center), metriche run, reset_run()
- `TimeManager.gd`: counter distanza in _process() ogni frame, _calculate_speed() con moltiplicatori, apply_offline_progress(), daily reset alle 00:00 tramite confronto stringa data
- `SaveManager.gd`: save/load JSON su user://save.json, serializzazione completa omini+DNA (Color→Array), save_to_memory_book(), calcolo e applicazione offline progress all'avvio
- `EventManager.gd`: GameEvent inner class, MAX 3 social + MAX 1 cosmic, caricamento events.json, scadenza eventi, genera cosmic con probabilità 30%/giorno
- `project.godot`: autoload configurati (GameState, TimeManager, EventManager, SaveManager), viewport 390x844, stretch canvas_items
- `docs/`: struttura completa 12 feature docs + changelog

