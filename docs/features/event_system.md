# Event System
## Stato: ✅ Completato
## Dipendenze: [EventManager.gd, GameState.gd, CultureSystem.gd, ResourceSystem.gd]
## Note implementazione:
- MAX 3 eventi sociali attivi contemporaneamente
- Struttura GameEvent: id, type, urgency, title, description, expires_in_hours, choices, triggered_by
- Urgency enum: MANAGEABLE (2-3 gg), URGENT (oggi), CRITICAL (adesso)
- Eventi emergono dallo stato reale: cohesion < 40 → conflict, warrior_ratio > 0.5 → violence, food_deficit > 3 → famine
- events.json già presente con struttura base
