# Culture System
## Stato: ❌ Non iniziato
## Dipendenze: [CultureSystem.gd, GameState.gd]
## Note implementazione:
- cohesion float 0-100, calcolata da CultureSystem.calculate_cohesion()
- Penalità warrior_ratio > 0.5: (ratio - 0.5) * 100
- Bonus same_origin: _same_origin_ratio() * 20
- Penalità > 4 origini diverse: (unique_origins - 4) * 5
- Soglie: stable 60-100, tension 40-60, conflict 20-40, collapse 0-20
- Penalità sulla velocità distanza: CultureSystem.get_war_penalty()
- Signal cohesion_changed emesso da GameState
