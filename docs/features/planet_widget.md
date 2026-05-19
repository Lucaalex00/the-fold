# Planet Widget
## Stato: ✅ Completato
## Dipendenze: [GameState.gd, EntitySprite.gd, Main.tscn]

## Architettura
- Script: `scripts/main/PlanetWidget.gd`
- Nodo: `Control` fullscreen in `PlanetLayer` (CanvasLayer layer=60)
- Sprite pianeta: `PlanetCornerSprite` (Sprite2D, sibling in PlanetLayer)
- UI overlay: `ExpandedPanel` > `FacingLabel` + `LayerDots`

## Sistema Layer
- **6 layer gameplay** mappati su 16 frame animazione: `[0, 3, 6, 9, 12, 15]`
- `view_layer` (int 0-5): layer attualmente visualizzato — solo UI, zero effetto gameplay
- `facing_layer` (GameState): layer esposto al cosmo — gestito da TimeManager ogni 4h
- Gli altri 10 frame del pianeta (non gameplay) sono riservati a decorazioni/eventi futuri

## Stati widget
| Stato | Posizione pianeta | Scala |
|---|---|---|
| Corner | Vector2(0, 850) | (2, 2) |
| Expanded | Vector2(195, 370) | (3, 3) |

## Transizioni
- **Corner → Expanded**: click su sfera → overlay nero + pianeta si muovono insieme in 0.5s (SINE EASE_OUT), entità compaiono solo a fine animazione
- **Expanded → Corner**: tap fuori dalla sfera → pianeta torna in angolo (BACK EASE_IN_OUT 0.4s), overlay sparisce
- **Overlay**: ColorRect nero 50% opacity, creato programmaticamente come primo figlio di PlanetLayer (z-index 0, dietro il pianeta)

## Navigazione layer
- **Swipe orizzontale** (>50px): cambia layer di 1, pausa rotazione automatica
- **Auto-rotazione**: Timer 10s/16 frame — quando passa su un gameplay frame aggiorna `view_layer` e visibilità entità
- **Resume rotazione**: automatico 4s dopo ultimo swipe, 3s dopo drop entità

## Input
- `_gui_input`: gestisce mouse/touch press, release, motion
- `_entity_at(pos)`: hit detection entità (raggio 22px) per long-press
- `_process(delta)`: long-press timer (0.5s), layer drag timer (1s/layer), rotation resume timer
