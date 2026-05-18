# Time Counter
## Stato: ✅ Completato
## Dipendenze: [TimeManager.gd, GameState.gd]
## Note implementazione:
- distance_from_center parte da 1.000.000 anni luce
- Si decrementa in _process(delta) — MAI in Timer
- Velocità: base_speed_per_second * era_multiplier * navigator_bonus * prestige_multiplier
- Progresso offline: base_speed * secondi_offline * offline_multiplier (0.5)
- HUD: numero in tempo reale + barra progresso percentuale
