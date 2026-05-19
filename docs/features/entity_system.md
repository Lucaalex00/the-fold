# Entity System
## Stato: ✅ Completato
## Dipendenze: [GameState.gd, GeneticSystem.gd, TraitDatabase.gd, EntitySprite.gd]

## Note implementazione
- 2 fondatori fissi: Cubo Giallo (builder), Triangolo Rosso (warrior)
- Ogni entità ha id UUID, name procedurale, birth_day, age_years
- Stats ereditate al 70% dai genitori, cap per era (ERA_STAT_CAP)
- DNA visivo: body_shape 0-7, 3 colori, accessory_type 0-15, size_modifier 0.8-1.2
- Limite per era in ERA_ENTITY_LIMIT
- Morte probabilistica: 0% sotto 20 anni, curva 0→80% tra 20-30 anni
- Ogni entità ha `layer: int` (0-5) — persiste su save/load tramite SaveManager
- Rinominato da Omino→Entity in tutta la codebase (2026-05-19)

## EntitySprite (visualizzazione sul pianeta)
- Script: `scripts/entities/EntitySprite.gd`
- Carica `assets/entities/spritesheet.png` (8 colonne × 4 righe, frame body_shape da DNA)
- Scala prospettica graduale: 1.2x al centro del pianeta → 0.8x ai bordi (±125px)
- **Movimento autonomo**: target random ogni 1.5–4.5s, velocità 18px/s, banda equatoriale ±55px
- **Transizione layer automatica**: se supera ±125px dal centro → `data.layer ±1`, riappare dal lato opposto
- **Long-press lift**: 0.5s di hold → `lift()` scala a 3.2x, blocca movimento autonomo
- **Drag sul pianeta**: entità segue il dito, nessun cambio layer se dentro il raggio (145px)
- **Drag fuori dal pianeta**: `direction = ±1`, cambia layer ogni 1s finché tieni fuori
- **Rilascio fuori**: snap a posizione random tra gli ENTITY_OFFSETS sul layer corrente
- Visibile solo quando `data.layer == PlanetWidget._view_layer`
