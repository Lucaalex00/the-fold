# Changelog — The Fold

## 2026-05-18 — STEP 7: i18n + Tutti i sistemi rimanenti + Tests

### i18n
- `LocalizationManager.gd` (Autoload "L"): `tr("KEY", {vars})`, switch locale runtime, save in user://settings.cfg
- `data/translations/en.json` + `it.json`: 80+ chiavi — ere, tratti, stat, morti, eventi, poteri, prestige, UI

### Sistemi core
- `LocalizationManager.gd`: sistema i18n completo EN/IT
- `DivinePowersSystem.gd`: 11 poteri, check era_required + divine_energy cost, effetti diretti su stat/coesione
- `PrestigeSystem.gd`: sequenza buco nero, analisi metriche run, bonus 1 (resource multiplier) + bonus 2 dinamico (5 tipi), slot cap 3, twist narrativo prestige 1-5+
- `Universe.gd`: player planet + 5 bot planets generati proceduralmente, posizionamento circolare
- `BotPlanet.gd`: avanzamento a 5% velocità player, step/era autonoma

### UI completa
- `HUD.gd` + `HUD.tscn`: counter distanza real-time ogni frame, barre cohesion/divine energy/popolazione, notifiche temporizzate
- `EventPanel.gd` + `EventPanel.tscn`: coda eventi, scelte dinamiche da JSON, mostra urgency
- `BubbleLabel.gd` + `BubbleLabel.tscn`: 8 tipi simbolo, float upward + fade out in 2.5s
- `MemoryBook.gd` + `MemoryBook.tscn`: lista completa morti + run prestige, scrollabile
- `PrestigeScreen.gd` + `PrestigeScreen.tscn`: animazione fade-in nero, god message con tween, bonus reveal
- `Main.gd`: entry point completo, init fondatori, tutti i signal connessi, gestione population collapse

### Scene aggiornate
- `Main.tscn`: struttura completa con tutti i nodi UI istanziati
- `Universe.tscn`: script + planet_scene export
- `Planet.tscn`: Sprite2D + OminiContainer

### Tests
- `TestRunner.gd` + `TestRunner.tscn`: runner automatico, print risultati, quit(1) se fallimenti
- `test_game_state.gd`: 12 test (limiti ere, energia, advance_step, reset_run, living_omini)
- `test_omino_system.gd`: 13 test (death curve completa, fondatori, TraitDatabase, era cap)
- `test_culture_system.gd`: 9 test (cohesion formula, soglie, war_penalty)
- `test_genetic_system.gd`: 8 test (70% stats, intelligence bonus, trait dominante, era cap, DNA)
- `test_prestige_system.gd`: 10 test (multiplier formula, bonus 2, slot cap, effetti bonus)
- `test_localization.gd`: 11 test (EN/IT keys, substitution, trait names, era names)

### project.godot
- Main scene impostata: `res://scenes/main/Main.tscn`
- 12 Autoload totali (inclusi L, DivinePowersSystem, PrestigeSystem)

---

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

