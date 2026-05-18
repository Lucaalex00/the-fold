# THE FOLD — CLAUDE.md

---

## ⚠️ ISTRUZIONI PER CLAUDE CODE

1. **Leggi questo file SEMPRE** prima di toccare qualsiasi cosa
2. **Aggiorna `## STATO ATTUALE`** dopo ogni sessione di lavoro
3. **Mantieni aggiornati i file in `/docs/`** — ogni feature ha il suo `.md`
4. **Non inventare variabili o nomi** non presenti in questo documento
5. **Fix chirurgici** — non riscrivere sistemi funzionanti

### Struttura docs da mantenere aggiornata
```
docs/
├── features/
│   ├── entity_system.md
│   ├── genetic_system.md
│   ├── event_system.md
│   ├── cosmic_events.md
│   ├── divine_powers.md
│   ├── time_counter.md
│   ├── daily_reset.md
│   ├── prestige_system.md
│   ├── memory_book.md
│   ├── universe_map.md
│   ├── culture_system.md
│   └── bubble_system.md
└── progress/
    └── changelog.md
```

Ogni file feature segue questo formato:
```
# [Feature Name]
## Stato: ❌ Non iniziato | 🔄 In sviluppo | ✅ Completato
## Dipendenze: [lista]
## Note implementazione: [dettagli tecnici aggiornati]
```

---

## 📊 STATO ATTUALE
> Aggiornato: 2026-05-19

| Feature | Stato | Note |
|---|---|---|
| project.godot | ✅ | Autoload configurati, viewport 390x844 |
| Assets entities | ✅ | spritesheet.png 8x4, frame 181x271px |
| Assets pianeti | ✅ | 15 pianeti, strip 6 frame 64x64px |
| traits.json | ✅ | 8 tratti base |
| events.json | ✅ | Struttura base social + cosmic |
| GameState.gd | ✅ | EntityData inner class, segnali, costanti ERA, variabili globali, reset_run() |
| TimeManager.gd | ✅ | _process() ogni frame, calcolo velocità, offline progress, daily reset 00:00 |
| SaveManager.gd | ✅ | save/load JSON user://save.json, save_to_memory_book(), serializ. DNA/Color |
| EventManager.gd | ✅ | GameEvent inner class, MAX 3 social + MAX 1 cosmic, scadenza eventi |
| docs/ | ✅ | 12 feature docs + changelog creati |
| Sistema entities | ✅ | EntityGenerator.gd, Entity.gd, TraitDatabase, fondatori Cube+Triangle |
| Sistema genetico | ✅ | GeneticSystem.gd — generate_child(), mix DNA, crescendo generazionale |
| CultureSystem | ✅ | coesione, soglie, war_penalty, ratio warrior/origini |
| ResourceSystem | ✅ | harvest/fishing/labor/trade, food_deficit_days, daily_reset() |
| Planet.gd | ✅ | setup, initialize_founders(), add_entity(), can_add_entity() |
| i18n (en + it) | ✅ | LocalizationManager (Autoload "L"), en.json + it.json, tr("KEY", {vars}) |
| Sistema eventi (UI) | ✅ | EventPanel.gd + EventPanel.tscn, scelte dinamiche, scadenza |
| Sistema poteri | ✅ | DivinePowersSystem.gd, 11 poteri, check era/energy, effetti |
| Counter distanza (HUD) | ✅ | HUD.gd + HUD.tscn, update ogni frame, barre stato |
| Daily reset | ✅ | Implementato in TimeManager._check_daily_reset() |
| Prestige | ✅ | PrestigeSystem.gd, sequenza, bonus 1+2, slot cap 3, twist narrativo |
| Memory Book | ✅ | MemoryBook.gd + MemoryBook.tscn, UI completa |
| PrestigeScreen | ✅ | PrestigeScreen.gd + PrestigeScreen.tscn, tween fade + god message |
| BubbleSystem | ✅ | BubbleLabel.gd + BubbleLabel.tscn, 8 tipi simbolo, float+fade |
| Universe | ✅ | Universe.gd, 5 bot planets, posizionamento circolare |
| BotPlanet | ✅ | BotPlanet.gd, avanza lentamente (5% velocità player) |
| Main.gd | ✅ | Entry point, init fondatori, connect signals, gestione game over |
| Tests | ✅ | TestRunner + 6 suite: GameState, Entity, Culture, Genetic, Prestige, L10n |
| Tutorial | ❌ | Non iniziato |

### Decisioni tecniche sessione 2026-05-19
- **Rename completo Italiano→Inglese** — tutti gli identificatori, nomi file, commenti e stringhe hardcoded sono ora in inglese. Solo le stringhe visibili al player passano per `L.tr("KEY")`.
- File rinominati: `Omino.gd` → `Entity.gd`, `OminoGenerator.gd` → `EntityGenerator.gd`, `test_omino_system.gd` → `test_entity_system.gd`
- Identificatori chiave rinominati: `OminoData` → `EntityData`, `ERA_OMINI_LIMIT` → `ERA_ENTITY_LIMIT`, `oldest_omino_age` → `oldest_entity_age`, signal `omino_died` → `entity_died`, `create_omino` → `create_entity`, `_deserialize_omino` → `_deserialize_entity`
- Death cause hardcoded `"vecchiaia"` → `"old_age"` (chiave i18n)

### Decisioni tecniche sessione 2026-05-18
- `EntityData` implementata come inner class di `GameState` (non standalone) — in GDScript 4 le inner class non supportano `class_name`; accesso via `GameState.EntityData.new()`
- `distance_from_center` è variabile di `GameState`, aggiornata da `TimeManager._process()` ogni frame
- `SaveManager._ready()` gestisce caricamento iniziale e calcolo offline progress
- `EventManager` carica events.json in `_ready()`, trigger CultureSystem/ResourceSystem sono placeholder da completare al prossimo step

---
> Game Design Document completo per Claude Code
> Motore: Godot 4.4+ | Linguaggio: GDScript | Asset: Pixel Art 32bit generativa

---

## INDICE RAPIDO
1. [Concept & Identità](#1-concept--identità)
2. [Struttura Tecnica Godot](#2-struttura-tecnica-godot)
3. [Il Sistema Omini](#3-il-sistema-omini)
4. [Il Sistema Tratti & Statistiche](#4-il-sistema-tratti--statistiche)
5. [Il Loop Giornaliero](#5-il-loop-giornaliero)
6. [Il Sistema Età & Morte](#6-il-sistema-età--morte)
7. [Il Sistema Eventi](#7-il-sistema-eventi)
8. [Il Sistema Poteri Divini](#8-il-sistema-poteri-divini)
9. [L'Universo & Il Counter](#9-luniverso--il-counter)
10. [Il Sistema Prestige & Buco Nero](#10-il-sistema-prestige--buco-nero)
11. [Il Sistema Bubble](#11-il-sistema-bubble)
12. [Monetizzazione](#12-monetizzazione)
13. [Narrativa & Twist](#13-narrativa--twist)
14. [Asset Pipeline](#14-asset-pipeline)
15. [Priorità di Sviluppo](#15-priorità-di-sviluppo)

---

## 1. CONCEPT & IDENTITÀ

**Genere:** Physics God Game
**Piattaforma:** Mobile (Android + iOS)
**Sessioni:** 3-4 aperture/giorno × 10-15 min
**Retention loop:** Daily reset 00:00 + counter tempo reale
**Endgame:** Asintoticamente irraggiungibile (prestige infinito)

### Pillole di design
- Il giocatore è un dio silenzioso — **plasma le condizioni**, non controlla le unità
- La civiltà si muove da sola — il giocatore interviene sull'ambiente e la fisica
- Ogni civiltà è **irripetibile** — estetica, genetica e storia uniche per player
- Il gioco ha un **twist narrativo oscuro** rivelato progressivamente dal prestige 3 in poi
- Tono visivo: pixel art 32bit, palette che si espande con l'era

### Le 5 Ere
```
ERA 1 — The Folde    step 1-10    (atomo → cellula)
ERA 2 — Biologica      step 11-20   (organismo → tribù)
ERA 3 — Civile         step 21-30   (villaggio → nazione)
ERA 4 — Industriale    step 31-40   (tecnologia → spazio)
ERA 5 — Cosmica        step 41-50   (sistema solare → galassia)
```

---

## 2. STRUTTURA TECNICA GODOT

### Struttura cartelle
```
res://
├── scenes/
│   ├── main/
│   │   ├── Main.tscn
│   │   ├── Universe.tscn
│   │   └── Planet.tscn
│   ├── ui/
│   │   ├── HUD.tscn
│   │   ├── EventPanel.tscn
│   │   ├── MemoryBook.tscn
│   │   ├── PrestigeScreen.tscn
│   │   └── BubbleLabel.tscn
│   ├── omini/
│   │   ├── Omino.tscn
│   │   └── OminoRenderer.tscn
│   └── fx/
│       ├── CosmicEvent.tscn
│       └── BlackHole.tscn
├── scripts/
│   ├── core/
│   │   ├── GameState.gd          # Autoload — stato globale
│   │   ├── TimeManager.gd        # Autoload — counter tempo reale
│   │   ├── EventManager.gd       # Autoload — generazione eventi
│   │   └── SaveManager.gd        # Autoload — salvataggio
│   ├── omini/
│   │   ├── Omino.gd
│   │   ├── OminoGenerator.gd     # Genera aspetto da DNA
│   │   ├── GeneticSystem.gd      # Eredità, mutazioni
│   │   └── TraitDatabase.gd      # Database tutti i tratti
│   ├── planet/
│   │   ├── Planet.gd
│   │   ├── CultureSystem.gd      # Coesione, conflitti
│   │   └── ResourceSystem.gd     # Raccolta, reset 00:00
│   ├── universe/
│   │   ├── Universe.gd
│   │   ├── CosmicEventSystem.gd
│   │   └── BotPlanet.gd
│   └── prestige/
│       └── PrestigeSystem.gd
├── assets/
│   ├── omini/                    # Sprite generati
│   ├── planets/
│   ├── ui/
│   └── fx/
└── data/
    ├── traits.json
    ├── events.json
    └── cosmic_events.json
```

### Autoload obbligatori (Project Settings)
```gdscript
GameState      → res://scripts/core/GameState.gd
TimeManager    → res://scripts/core/TimeManager.gd
EventManager   → res://scripts/core/EventManager.gd
SaveManager    → res://scripts/core/SaveManager.gd
```

---

## 3. IL SISTEMA OMINI

### Struttura dati Omino
```gdscript
class_name OminoData

var id: String                    # UUID univoco
var name: String                  # Generato proceduralmente
var birth_day: int                # Giorno reale di nascita
var birth_date_real: String       # "15 Gennaio 2025"
var age_years: int                # Età in anni di gioco
var is_alive: bool

var trait_primary: String         # Tratto dominante
var trait_secondary: String       # Tratto secondario (da era 2+)

var stats: Dictionary = {
    "health": 0,
    "energy": 0,
    "intelligence": 0,
    "attack": 0,
    "construction": 0,
    "harvest": 0,
    "fishing": 0,
    "research": 0,
    "diplomacy": 0
}

var dna: Dictionary = {
    "body_shape": 0,        # 0-7 forme diverse
    "color_primary": Color,
    "color_secondary": Color,
    "color_accent": Color,
    "accessory_type": 0,    # 0-15 accessori
    "size_modifier": 0.0    # 0.8 - 1.2
}

var origin_planet: String         # ID pianeta di origine
var generation: int               # Numero generazione
var parents: Array[String]        # ID genitori (max 2)
var children: Array[String]       # ID figli
var notable_events: Array[String] # Eventi storici vissuti
var death_cause: String           # Causa morte (per Memory Book)
```

### Limite omini per era
```gdscript
const ERA_OMINI_LIMIT = {
    1: 4,
    2: 8,
    3: 15,
    4: 30,
    5: 50
}
```

### Omini di partenza
```
Cubo Giallo    — tratto: Costruttore
Triangolo Rosso — tratto: Guerriero
```
Forma e colore sono fissi per i fondatori. Stats generate randomicamente nel range base dell'era 1.

### Generazione visiva DNA
```gdscript
# OminoGenerator.gd
func generate_sprite(dna: Dictionary) -> Texture2D:
    # Combina 5 layer pixel art:
    # Layer 1: corpo base (shape)
    # Layer 2: colore primario
    # Layer 3: colore secondario
    # Layer 4: accessorio
    # Layer 5: effetto era (alone, particelle)
    pass
```

---

## 4. IL SISTEMA TRATTI & STATISTICHE

### Statistiche universali (tutti gli omini)
| Stat | Descrizione |
|------|-------------|
| ❤️ SALUTE | Sopravvivenza a eventi, malattie, conflitti |
| ⚡ ENERGIA | Azioni eseguibili per giorno |
| 🧠 INTELLIGENZA | Velocità apprendimento generazionale |

### Statistiche specializzate
| Stat | Descrizione |
|------|-------------|
| ⚔️ ATTACCO | Efficacia in conflitti |
| 🏗️ COSTRUZIONE | Velocità edifici/infrastrutture |
| 🌾 RACCOLTO | Efficienza risorse terrestri |
| 🎣 PESCA | Efficienza risorse acquatiche |
| 🔬 RICERCA | Accelera step evolutivi |
| 🤝 DIPLOMAZIA | Riduce tensione culturale |

### Tratti base (LAUNCH — 8 tratti)
```gdscript
const TRAITS = {
    "warrior": {
        "icon": "⚔️",
        "stats_high": ["attack", "health"],
        "stats_mid": ["energy"],
        "stats_low": ["diplomacy"],
        "base_values": {"attack": 10, "health": 9, "energy": 7, "diplomacy": 3}
    },
    "builder": {
        "icon": "🏗️",
        "stats_high": ["construction", "harvest"],
        "stats_mid": ["intelligence"],
        "stats_low": ["attack"],
        "base_values": {"construction": 11, "harvest": 8, "intelligence": 7, "attack": 3}
    },
    "fisher": {
        "icon": "🎣",
        "stats_high": ["fishing", "energy"],
        "stats_mid": ["health"],
        "stats_low": ["research"],
        "base_values": {"fishing": 11, "energy": 9, "health": 6, "research": 2}
    },
    "scientist": {
        "icon": "🔬",
        "stats_high": ["research", "intelligence"],
        "stats_mid": ["diplomacy"],
        "stats_low": ["health"],
        "base_values": {"research": 12, "intelligence": 10, "diplomacy": 6, "health": 3}
    },
    "diplomat": {
        "icon": "🤝",
        "stats_high": ["diplomacy", "intelligence"],
        "stats_mid": ["harvest"],
        "stats_low": ["attack"],
        "base_values": {"diplomacy": 12, "intelligence": 9, "harvest": 6, "attack": 2}
    },
    "farmer": {
        "icon": "🌾",
        "stats_high": ["harvest", "health"],
        "stats_mid": ["construction"],
        "stats_low": ["research"],
        "base_values": {"harvest": 12, "health": 10, "construction": 6, "research": 2}
    },
    "healer": {
        "icon": "⚕️",
        "stats_high": ["health", "diplomacy"],
        "stats_mid": ["research"],
        "stats_low": ["attack"],
        "base_values": {"health": 14, "diplomacy": 8, "research": 6, "attack": 1}
    },
    "explorer": {
        "icon": "🗺️",
        "stats_high": ["energy", "fishing"],
        "stats_mid": ["attack"],
        "stats_low": ["construction"],
        "base_values": {"energy": 14, "fishing": 8, "attack": 5, "construction": 2}
    }
}
```

### Cap statistiche per era
```gdscript
const ERA_STAT_CAP = {1: 15, 2: 25, 3: 40, 4: 60, 5: 100}
```

### Sistema ereditarietà
```gdscript
# GeneticSystem.gd
func generate_child(parent_a: OminoData, parent_b: OminoData) -> OminoData:
    var child = OminoData.new()
    child.generation = max(parent_a.generation, parent_b.generation) + 1
    
    # Eredita 70% delle stat dai genitori
    for stat in child.stats.keys():
        var avg = (parent_a.stats[stat] + parent_b.stats[stat]) / 2.0
        child.stats[stat] = round(avg * 0.70)
    
    # Bonus intelligenza per generazione
    var gen_bonus = child.generation * 0.05
    child.stats["intelligence"] = round(child.stats["intelligence"] * (1.0 + gen_bonus))
    
    # Tratto dominante dal genitore con stat più alta
    child.trait_primary = _dominant_trait(parent_a, parent_b)
    
    # DNA visivo — mix dei genitori con variazione minima
    child.dna = _mix_dna(parent_a.dna, parent_b.dna)
    
    # Cap per era corrente
    _apply_era_cap(child)
    
    return child
```

### Crescendo generazionale
```
Gen 1 (fondatori):   stat base 8-10
Gen 2 (figli):       +20% → 10-12
Gen 3 (nipoti):      +30% → 13-16
Gen 4 (pronipoti):   +40% → 18-22
Gen 5+:              cap per era
```

---

## 5. IL LOOP GIORNALIERO

### Reset 00:00
```gdscript
# ResourceSystem.gd
func daily_reset() -> void:
    resources["harvest"] = calculate_harvest()
    resources["fishing"] = calculate_fishing()
    resources["labor"] = calculate_labor()
    resources["trade"] = calculate_trade()
    EventManager.generate_daily_events()
    TimeManager.advance_game_year()  # +2 anni di gioco
```

### 4 Aperture tipo
```
APERTURA 1 — Mattina (10-15 min)
  - Riepilogo notte (animazione 30 sec)
  - Raccolta risorse (2 min)
  - Eventi sociali attivi (5-7 min)
  - Evento cosmico (2-3 min)
  - Mappa universo (1 min)

APERTURA 2 — Pausa pranzo (5-7 min)
  - Verifica evento cosmico
  - Evento nuovo generato
  - Check progressione civiltà
  - ADS rewarded opzionale

APERTURA 3 — Sera (10-15 min)
  - Raccolta risorse secondarie
  - Risoluzione eventi
  - Nuovi eventi sociali
  - Scelta strategica giornaliera

APERTURA 4 — Notte (3-5 min)
  - Ultimi eventi in scadenza
  - Preview risorse domani
  - Evento cosmico notturno opzionale
```

### Scala tempo
```
1 giorno reale = 2 anni di gioco
Cap morte vecchiaia = 30 anni (= 15 giorni reali)
```

---

## 6. IL SISTEMA ETÀ & MORTE

### Curva probabilità morte per vecchiaia
```gdscript
# Omino.gd
func calculate_death_probability(age_years: int) -> float:
    if age_years < 20:
        return 0.0
    elif age_years <= 30:
        # Curva crescente 0% → 80%
        var t = (age_years - 20.0) / 10.0
        return t * 0.80
    else:
        # Oltre 30: 80% + 0.05% per ogni anno extra
        var extra_years = age_years - 30
        return 0.80 + (extra_years * 0.0005)
        # Max teorico ~98% a 200 anni — mai 100%

func roll_death() -> bool:
    var prob = calculate_death_probability(age_years)
    return randf() < prob
```

### Cause di morte
```
- Vecchiaia (probabilità crescente)
- Conflitto (guerra interna/esterna)
- Malattia (evento random)
- Evento cosmico (meteorite, caldo estremo)
- Carestia (risorse a zero per X giorni)
- Crollo sociale (coesione a zero)
```

### Memory Book — struttura salvataggio
```gdscript
# SaveManager.gd
func save_to_memory_book(omino: OminoData) -> void:
    var entry = {
        "id": omino.id,
        "name": omino.name,
        "trait": omino.trait_primary,
        "born_day": omino.birth_day,
        "born_date_real": omino.birth_date_real,
        "death_day": GameState.current_day,
        "death_date_real": Time.get_date_string_from_system(),
        "age_years": omino.age_years,
        "stats_final": omino.stats.duplicate(),
        "generation": omino.generation,
        "children_count": omino.children.size(),
        "origin_planet": omino.origin_planet,
        "notable_events": omino.notable_events.duplicate(),
        "death_cause": omino.death_cause,
        "dna_snapshot": omino.dna.duplicate(),
        "prestige_run": GameState.prestige_count
    }
    GameState.memory_book.append(entry)
    SaveManager.save_game()
```

---

## 7. IL SISTEMA EVENTI

### Livelli urgenza
```gdscript
enum EventUrgency {
    MANAGEABLE,  # 🟡 2-3 giorni
    URGENT,      # 🟠 oggi
    CRITICAL     # 🔴 adesso
}
```

### Struttura evento
```gdscript
class_name GameEvent

var id: String
var type: String              # "social" | "cosmic" | "resource"
var urgency: EventUrgency
var title: String
var description: String
var expires_in_hours: float
var choices: Array[EventChoice]
var triggered_by: String      # causa generante (tratto, coesione, etc.)
```

### Regole generazione eventi sociali
```gdscript
# EventManager.gd
func generate_social_events() -> void:
    # Gli eventi emergono dallo stato reale della civiltà
    
    if CultureSystem.cohesion < 40:
        _generate_conflict_event()
    
    if CultureSystem.warrior_ratio > 0.5:
        _generate_internal_violence_event()
    
    if ResourceSystem.food_deficit_days > 3:
        _generate_famine_event()
    
    # Max 3 eventi sociali attivi contemporaneamente
```

### Eventi cosmici — tabella completa
```gdscript
const COSMIC_EVENTS = {
    "approaching_star": {
        "warning_hours": [6, 8],
        "consequence": "extreme_heat",
        "choices": ["lower_temperature", "mutate_citizens"]
    },
    "meteorite": {
        "warning_hours": [4, 6],
        "consequence": "permanent_crater",
        "choices": ["deflect_high_cost", "prepare_citizens", "ignore"]
    },
    "prolonged_eclipse": {
        "warning_hours": [12],
        "consequence": "famine_panic",
        "choices": ["artificial_light", "food_reserves"]
    },
    "cosmic_tide": {
        "warning_hours": [2],
        "consequence": "coastal_flood",
        "choices": ["evacuate_coast", "build_barriers"]
    },
    "solar_wind": {
        "warning_hours": [1],
        "consequence": "tech_disruption",  # solo era 4+
        "choices": ["shield_tech", "shutdown_systems"]
    },
    "alien_signal": {
        "warning_hours": [24],
        "consequence": "opportunity_or_threat",
        "choices": ["respond", "ignore", "analyze"]
    }
}
# Regola: MAX 1 evento cosmico attivo alla volta
```

### Conflitto culturale — numeri
```gdscript
# CultureSystem.gd
func calculate_cohesion() -> float:
    var base = 100.0
    
    # Penalità per mix incompatibile
    var warrior_ratio = _get_trait_ratio("warrior")
    if warrior_ratio > 0.5:
        base -= (warrior_ratio - 0.5) * 100
    
    # Bonus per omini stesso pianeta
    var same_origin_bonus = _same_origin_ratio() * 20
    base += same_origin_bonus
    
    # Penalità per diversità estrema (>4 origini diverse)
    if _unique_origins() > 4:
        base -= (_unique_origins() - 4) * 5
    
    return clamp(base, 0, 100)

const COHESION_THRESHOLDS = {
    "stable":    [60, 100],
    "tension":   [40, 60],   # eventi sociali più frequenti
    "conflict":  [20, 40],   # guerre probabili
    "collapse":  [0,  20]    # morte omini, fuga
}
```

---

## 8. IL SISTEMA POTERI DIVINI

### 3 Categorie
```gdscript
enum DivinePowerCategory {
    GEOGRAPHY,   # Crea/modifica territorio
    PHYSICS,     # Cambia condizioni fisiche
    BIOLOGY      # Modifica gli omini
}
```

### Poteri per era
```gdscript
const DIVINE_POWERS = {
    # GEOGRAFIA
    "create_mountain": {era_required: 1, cost: 30, category: "geography"},
    "create_wall": {era_required: 1, cost: 20, category: "geography"},
    "create_ocean": {era_required: 2, cost: 50, category: "geography"},
    "create_island": {era_required: 2, cost: 40, category: "geography"},
    
    # FISICA
    "change_temperature": {era_required: 1, cost: 25, category: "physics"},
    "change_gravity": {era_required: 2, cost: 60, category: "physics"},
    "accelerate_day": {era_required: 3, cost: 45, category: "physics"},
    
    # BIOLOGIA
    "mutate_faction": {era_required: 1, cost: 35, category: "biology"},
    "accelerate_evolution": {era_required: 2, cost: 70, category: "biology"},
    "create_disease": {era_required: 2, cost: 30, category: "biology"},
    "grant_immunity": {era_required: 2, cost: 40, category: "biology"}
}
```

### Energia divina
```gdscript
# GameState.gd
var divine_energy: float = 100.0
var divine_energy_max: float = 100.0
var divine_energy_regen_per_hour: float = 5.0  # ricarica lenta
```

---

## 9. L'UNIVERSO & IL COUNTER

### Counter distanza — TEMPO REALE
```gdscript
# TimeManager.gd — Autoload
var distance_from_center: float    # anni luce, parte da 1.000.000
var base_speed_per_second: float   # velocità automatica

func _process(delta: float) -> void:
    # Si aggiorna OGNI FRAME — online e offline
    distance_from_center -= _calculate_speed() * delta
    _update_hud_counter()

func _calculate_speed() -> float:
    var speed = base_speed_per_second
    speed *= GameState.get_era_speed_multiplier()
    speed *= GameState.get_omini_navigator_bonus()
    speed -= CultureSystem.get_war_penalty()
    speed *= GameState.prestige_resource_multiplier
    return max(speed, base_speed_per_second * 0.1)

# Calcolo offline — chiamato all'apertura del gioco
func calculate_offline_progress(seconds_offline: float) -> float:
    return base_speed_per_second * seconds_offline * offline_multiplier
```

### HUD Counter
```
📍 847,293 anni luce
[▓▓▓▓▓░░░░░░░░░░░░░░░] 23.4%
```
Numero che scende in tempo reale — visibile sempre in HUD.

### Struttura universo
```gdscript
# Universe.gd
var player_planet: PlanetData
var bot_planets: Array[BotPlanetData]    # generati proceduralmente
var player_planets: Array[PlanetData]    # altri giocatori reali

# I bot avanzano automaticamente, molto lentamente
# Si "sbloccano" come pianeti player quando un utente li scopre
```

---

## 10. IL SISTEMA PRESTIGE & BUCO NERO

### Trigger prestige
```
Condizione: era 5 raggiunta + distanza < soglia buco nero
Costruzione Nave Cosmica: X giorni di preparazione
```

### Sequenza buco nero
```gdscript
# PrestigeSystem.gd
func enter_black_hole() -> void:
    # 1. Animazione 20-30 sec
    # 2. Schermo nero — silenzio
    # 3. Il Dio parla — testo personalizzato basato sul run
    # 4. Analisi run (3 metriche)
    # 5. Assegna bonus 1 (fisso) + bonus 2 (dinamico)
    # 6. Big Bang — universo rinasce
    
    _analyze_run_metrics()
    _assign_prestige_bonuses()
    _save_to_memory_book_run()
    _reset_game_state()
    prestige_count += 1
```

### Bonus 1 — Fisso cumulabile
```gdscript
func get_resource_multiplier() -> float:
    if prestige_count <= 5:
        return pow(1.5, prestige_count)
    else:
        # Rallenta dopo prestige 5
        return pow(1.5, 5) * pow(1.15, prestige_count - 5)
```

### Bonus 2 — Dinamico basato su run
```gdscript
const PRESTIGE_BONUS_2 = {
    "war_god": {
        "condition": "conflicts_won > 10",
        "effect": "founders_attack_bonus_3",
        "god_message": "Vedo un guerriero."
    },
    "harmony_god": {
        "condition": "avg_cohesion > 75",
        "effect": "cultural_tension_minus_20",
        "god_message": "Vedo un pacificatore."
    },
    "resilience_god": {
        "condition": "omini_lost > 15",
        "effect": "free_lifeboat_1x",
        "god_message": "Vedo chi non si arrende."
    },
    "explorer_god": {
        "condition": "planets_visited > 5",
        "effect": "exploration_radius_plus_50pct",
        "god_message": "Vedo un collezionista."
    },
    "eternal_god": {
        "condition": "oldest_omino_age > 60",
        "effect": "death_cap_plus_5_years",
        "god_message": "Vedo chi ama ciò che crea."
    }
}
```

### Slot bonus — accumulo
```
Prestige 1: slot 1
Prestige 2: slot 1 + slot 2
Prestige 3: slot 1 + slot 2 + slot 3 (cap)
Prestige 4+: sostituisci uno slot a scelta
```

### Reveal twist — progressivo
```
Prestige 1: "Torna. Ho ancora molto da osservare."
Prestige 2: "Le tue civiltà sono... nutrienti."
Prestige 3: Memory Book — pagina omino di civiltà sconosciuta
Prestige 4: Il Dio mostra la sua forma reale
Prestige 5: Reveal completo — sei intrappolato
Prestige 6+: ???  (contenuto misterioso, mai rivelato tutto)
```

---

## 11. IL SISTEMA BUBBLE

Nessun testo sugli omini. Solo simboli.

```gdscript
enum BubbleType {
    QUESTION,      # ?  — confusione
    EXCLAMATION,   # !  — scoperta/pericolo
    HEART,         # ♥  — legame/nascita/morte serena
    SWORD,         # ⚔  — conflitto
    ELLIPSIS,      # …  — attesa/tensione
    STAR,          # ★  — evoluzione/traguardo
    ARROW_UP,      # ↑  — crescita/accordo
    SPARKLE        # ✦  — evento cosmico percepito
}

# BubbleLabel.tscn — appare sopra l'omino, dura 2-3 sec, poi svanisce
func show_bubble(omino: Node2D, type: BubbleType) -> void:
    var bubble = BUBBLE_SCENE.instantiate()
    bubble.set_type(type)
    omino.add_child(bubble)
```

---

## 12. MONETIZZAZIONE

### ADS Rewarded
```
- +20% risorse domani (apertura mattina)
- Navicella di soccorso (trigger: <2 omini vivi)
- Rivela stats omino reclutabile
- Accelera evento in scadenza +2 ore
```

### Pacchetti in-app (non P2W)
```
0.99€ — Scegli tratto navicella di soccorso
1.99€ — Pack eventi (3 eventi extra/settimana)
2.99€ — Skin poteri divini (effetti visivi)
4.99€ — Pack cosmico (skin pianeta + omini fondatori)
```

### Mai P2W
```
❌ Non si comprano stat
❌ Non si comprano step evolutivi
❌ Non si bypassa il gameplay core
✅ Solo comfort + cosmetics + tempo
```

---

## 13. NARRATIVA & TWIST

### Video iniziale (fumetto 30-45 sec)
```
SCENA 1: Spazio profondo, buio — segnale pulsa da lontano
SCENA 2: Il segnale viaggia attraverso galassie
SCENA 3: Un piccolo pianeta sperduto
          Cubo Giallo + Triangolo Rosso — soli
SCENA 4: Il segnale arriva — i due si illuminano, si guardano
SCENA 5: Schermo nero → "Rispondi?" → [INIZIA]
```

**Cosa NON mostrare mai nel video:**
- Altre civiltà che ricevono lo stesso segnale
- Il buco nero o il suo contenuto
- Chi siamo noi (il dio/giocatore)
- La fonte del segnale

### Il Dio del Buco Nero — tono
```
Non epico. Non drammatico.
Intimo, personale, leggermente inquietante.
Fa riferimento a eventi REALI del tuo run.
Non è mai completamente onesto.
```

### Il twist — struttura
```
Il segnale era un'esca (bait)
Il buco nero non è un traguardo — è una bocca
Il Dio divora le civiltà per vivere all'infinito
I bonus prestige sono il modo in cui ti ingrassa
per il prossimo ciclo
Il giocatore non può smettere — è la trappola
```

---

## 14. ASSET PIPELINE

### Strategia generazione pixel art
```
OPZIONE A — Generazione Python (consigliata per MVP)
  Libreria: Pillow (PIL)
  Genera sprite omini proceduralmente da DNA
  Output: PNG spritesheet 32x32 per variante
  
OPZIONE B — Aseprite + automazione
  Template base per ogni tratto
  Script Lua per variazioni colore/forma
  
OPZIONE C — Kenney.nl assets (free)
  Base per placeholder durante sviluppo
  Sostituire prima del lancio
```

### Script Python generazione omini
```python
# generate_omino.py
from PIL import Image, ImageDraw
import json

SHAPES = {
    0: "square",      # Cubo
    1: "triangle",    # Triangolo  
    2: "circle",      # Cerchio
    3: "diamond",     # Diamante
    4: "pentagon",    # Pentagono
    5: "hexagon",     # Esagono
    6: "star",        # Stella
    7: "cross"        # Croce
}

def generate_omino_sprite(dna: dict) -> Image:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    shape = SHAPES[dna["body_shape"]]
    color_primary = tuple(dna["color_primary"])
    color_secondary = tuple(dna["color_secondary"])
    
    # Disegna corpo base
    _draw_shape(draw, shape, color_primary)
    # Disegna dettagli secondari
    _draw_details(draw, dna["accessory_type"], color_secondary)
    
    return img
```

### Palette per era
```
Era 1: 4 colori  — quasi monocromatico, toni terrosi
Era 2: 8 colori  — prime variazioni, verde/blu
Era 3: 16 colori — colori vivaci, architettura
Era 4: 24 colori — metallici, tecnologici
Era 5: 32 colori — explosion cosmica, neon + spazio
```

---

## 15. PRIORITÀ DI SVILUPPO

### MVP (3-4 mesi)
```
[ ] Autoload core (GameState, TimeManager, SaveManager)
[ ] Sistema omini base (2 fondatori, DNA visivo semplice)
[ ] Counter distanza tempo reale
[ ] Daily reset 00:00
[ ] 3 eventi sociali base
[ ] 2 eventi cosmici base
[ ] 3 poteri divini base
[ ] Memory Book
[ ] Era 1 completa
[ ] Tutorial primi 10 minuti
[ ] ADS rewarded (navicella)
```

### Alpha (2-3 mesi dopo MVP)
```
[ ] Era 2-3
[ ] Sistema genetico completo (figli, eredità)
[ ] Conflitto culturale numerico
[ ] 8 tratti completi
[ ] Pianeti bot (3-5 vicini)
[ ] Mappa universo base
[ ] Primo prestige funzionante
```

### Beta (2-3 mesi dopo Alpha)
```
[ ] Era 4-5
[ ] Multiplayer pianeti (visualizzazione)
[ ] Classifica per era
[ ] Tutti gli eventi cosmici
[ ] Reveal twist prestige 1-5
[ ] Monetizzazione completa
[ ] Generazione asset Python automatizzata
```

---

## NOTE PER CLAUDE CODE

- **Non inventare variabili** non presenti in questo documento
- **Non riscrivere sistemi** funzionanti — fix chirurgici
- **Consistenza prima di tutto** — usa sempre i nomi esatti definiti qui
- Il counter distanza deve aggiornarsi in `_process()` — mai in timer
- Il Memory Book è **permanente** — non si cancella mai, neanche col prestige
- Gli eventi cosmici: **mai più di 1 attivo contemporaneamente**
- La morte per vecchiaia è **probabilistica** — mai garantita prima dei 30 anni
- I bonus prestige sono **cumulativi** — non si resettano tra i run

---

*Documento generato il: 2025 | Versione: 1.0*
*Aggiornare questo file ad ogni decisione di design significativa*
