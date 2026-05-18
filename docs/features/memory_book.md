# Memory Book
## Stato: ✅ Completato
## Dipendenze: [SaveManager.gd, GameState.gd]
## Note implementazione:
- Salvato in GameState.memory_book (Array)
- Persistente FOREVER — non si cancella col prestige
- save_to_memory_book(omino) in SaveManager.gd
- Entry include: id, name, trait, date_born/died, age_years, stats_final, generation, children_count, notable_events, death_cause, dna_snapshot, prestige_run
- Visualizzato in MemoryBook.tscn (UI da implementare)
