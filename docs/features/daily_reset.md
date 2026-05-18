# Daily Reset
## Stato: ✅ Completato
## Dipendenze: [TimeManager.gd, ResourceSystem.gd, EventManager.gd]
## Note implementazione:
- Reset alle 00:00 reali — confronto stringa data (Time.get_date_string_from_system())
- Controllato in TimeManager._process() ogni frame
- Al reset: +1 current_day, +2 age_years per ogni omino vivo, generate_daily_events()
- Risorse calcolate da harvest/fishing degli omini vivi
- 1 giorno reale = 2 anni di gioco
