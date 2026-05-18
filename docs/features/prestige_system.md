# Prestige System
## Stato: ✅ Completato
## Dipendenze: [GameState.gd, SaveManager.gd, PrestigeSystem.gd]
## Note implementazione:
- Trigger: era 5 raggiunta + distance_from_center < soglia buco nero
- Sequenza: animazione → schermo nero → messaggio dio → analisi run → bonus → reset
- Bonus 1 fisso: moltiplicatore 1.5^prestige (rallenta dopo prestige 5)
- Bonus 2 dinamico: basato su metriche run (conflicts_won, avg_cohesion, omini_lost, planets_visited, oldest_omino_age)
- Slot bonus: 1 al prestige 1, +1 al 2, cap 3 dal prestige 3, poi sostituzione
- Bonus prestige NON si resettano mai
- Twist narrativo progressivo dal prestige 1 al 6+
