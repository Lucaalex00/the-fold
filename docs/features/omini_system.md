# Omini System
## Stato: ❌ Non iniziato
## Dipendenze: [GameState.gd, GeneticSystem.gd, TraitDatabase.gd]
## Note implementazione:
- 2 fondatori fissi: Cubo Giallo (builder), Triangolo Rosso (warrior)
- Ogni omino ha id UUID, name procedurale, birth_day, age_years
- Stats ereditate al 70% dai genitori, cap per era (ERA_STAT_CAP)
- DNA visivo: body_shape 0-7, 3 colori, accessory_type 0-15, size_modifier 0.8-1.2
- Limite per era definito in ERA_OMINI_LIMIT
- Morte probabilistica: 0% sotto 20 anni, curva 0→80% tra 20-30 anni
