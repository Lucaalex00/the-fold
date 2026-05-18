# Genetic System
## Stato: ✅ Completato
## Dipendenze: [GameState.gd, omini_system]
## Note implementazione:
- GeneticSystem.gd — generate_child(parent_a, parent_b) -> OminoData
- Figlio eredita 70% media stat genitori
- Bonus intelligenza: generation * 5% cumulativo
- Tratto dominante dal genitore con stat più alta nel tratto
- DNA visivo: mix dei due genitori con variazione minima
- Crescendo generazionale: Gen1 8-10, Gen2 +20%, Gen3 +30%, Gen4 +40%, Gen5+ cap era
