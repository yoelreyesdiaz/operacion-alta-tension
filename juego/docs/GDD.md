# OPERACIÓN ALTA TENSIÓN — Game Design Document (v0.1)

Juego 2D pixel art para PC en Godot 4.7. Obra de ficción: la empresa y la subestación
"S.E. Atemajac" están inspiradas en infraestructura eléctrica mexicana, pero no
representan ninguna instalación real.

## 1. Concepto

Noche de tormenta en Guadalajara. Una subestación cae y deja a media ciudad a oscuras.
Leo, técnico de mantenimiento, entra a devolverla a la vida zona por zona, guiado por
radio por Ing. Morales. Conforme repara, descubre que no todas las fallas son de la tormenta.

- **Género:** aventura 2D vista cenital + puzzles + mantenimiento simplificado, con
  progresión por zonas tipo metroidvania ligera.
- **Fantasía del jugador:** "estoy arreglando una planta eléctrica".
- **Pilares:** (1) razonar antes de tocar, (2) la seguridad es mecánica de juego,
  (3) cada reparación cambia el mundo (luces, puertas, sonido), (4) misterio a cuentagotas.
- **Tono:** industrial, tenso, tecnológico; calma al reparar, peligro al equivocarse.

### Loop principal
Explorar → encontrar falla → diagnosticar → conseguir herramienta/información → resolver
puzzle → reparar → restablecer energía → desbloquear zona → descubrir historia.

### Regla de seguridad (núcleo del diseño)
**CORTA · VERIFICA · TRABAJA · RESTABLECE.** Ningún equipo se repara con un solo botón:

| Paso | En el juego | Si lo ignoras |
|---|---|---|
| Cortar | Abrir el interruptor del equipo | Descarga (−1 casco) |
| Verificar | Medir 0 V con el multímetro | Descarga por carga residual |
| Trabajar | Herramienta correcta en la mano | La acción no se ejecuta |
| Restablecer | Cerrar el interruptor | Si la reparación está mal: disparo y nueva avería |

### Energía global
Cuatro circuitos sobre un total de 10: A Servicios auxiliares (1), B Patio 115 kV (3),
C Transformadores (3), D Distribución 23 kV (3). El HUD muestra la barra de 10 segmentos.
El Capítulo 1 recupera el circuito A.

### Herramientas
| Herramienta | Uso real | Disponible |
|---|---|---|
| Lámpara de casco | Luz alrededor de Leo | Inicio |
| Radio | Diálogos, pistas | Inicio |
| Multímetro | Verificar 0 V; ver continuidad en tableros | Cap. 1 |
| Destornillador | Abrir tapas; girar nodos | Cap. 1 |
| Pinzas, llave, detector de tensión, pértiga aislada | Cable dañado, válvulas, medir sin contacto, seccionadores | Cap. 2+ |

### Historia por capítulos
1. **Llegada** — entrar: reenergizar servicios auxiliares y abrir el portón. Primera pista: los nodos fueron movidos a mano.
2. **Sistemas básicos** — patio de interruptores, generador auxiliar, baterías.
3. **Transformadores** — sobrecalentamiento, enfriamiento, primer sabotaje evidente.
4. **Sistema de control** — sala de control, tableros, registros borrados.
5. **Anomalías** — almacén y torre: las fallas siguen un patrón.
6. **Zona restringida** — la orden de trabajo falsa de la bitácora.
7. **Revelación** — quién y por qué (no se adelanta aquí).
8. **Final** — secuencia completa de restablecimiento, 10/10.

## 2. Arquitectura técnica

Resolución base 426×240, escalado entero (ventana 1278×720), filtro nearest, renderer
Compatibility. Todo sistema global es un autoload pequeño con `reset()`,
`to_dict()` y `from_dict()`; se comunican por señales, no por referencias directas.

| Sistema pedido | Implementación | Estado |
|---|---|---|
| GameStateManager | `autoload/game_state.gd` (salud, banderas, modal, escenas, controles, tema UI) | ✔ |
| InventorySystem | `autoload/inventory.gd` + `data/items.json` | ✔ |
| PowerGridSystem | `autoload/power_grid.gd` | ✔ |
| QuestSystem | `autoload/quest.gd` | ✔ |
| DialogueSystem | `autoload/radio.gd` + `data/dialogos_cap1.json` | ✔ |
| AudioManager | `autoload/audio_manager.gd` (buses SFX/Ambiente/Musica) | ✔ |
| SaveSystem | `autoload/save_system.gd` (JSON en `user://`, autoguardado por objetivo) | ✔ |
| PlayerController | `scripts/player/player.gd` | ✔ |
| InteractionSystem | `scripts/systems/interactable.gd` + detector del jugador | ✔ |
| WeatherSystem | `scripts/systems/weather.gd` | ✔ |
| PuzzleSystem | `scripts/puzzles/red_model.gd` (lógica pura) + `puzzle_red.gd` (UI) | ✔ 1 puzzle |
| RepairSystem | Reglas de seguridad dentro de `RedModel` | Parcial: extraer a componente reutilizable en M2 |
| UIManager | `scripts/ui/hud.gd` (HUD + un panel a la vez) | ✔ |
| MapSystem | `scripts/ui/map_panel.gd` + `data/zonas.json` | ✔ básico |

Decisiones:
- Las escenas `.tscn` son mínimas (raíz + script) y construyen sus hijos por código: fácil de
  versionar y de generar. Cuando haya más zonas conviene pasar a TileMaps editados en el editor.
- Cada zona es una escena independiente (`scenes/levels/zona_XX.tscn`).
- El arte y el audio placeholder se regeneran con `tools/gen_art.py`, `gen_audio.py`, `gen_font.py`.

## 3. Estructura de carpetas

```
proyecto-beta-cfe/
├── project.godot
├── autoload/        sistemas globales
├── scenes/          player/ levels/ puzzles/ ui/ objects/
├── scripts/         player/ systems/ puzzles/ levels/ ui/
├── assets/          sprites/ tilesets/ audio/ fonts/ effects/
├── data/            items, diálogos, zonas, configuración de puzzles (JSON)
├── tools/           generadores de arte, audio y fuente (Python)
├── tests/           test_red_model.gd, playthrough.tscn
└── docs/            este documento
```

## 4. Primer mapa — Zona 1: Entrada y caseta (34×22 tiles de 16 px)

```
 ┌──────────── patio de interruptores (Zona 2, solo siluetas) ───────────┐
 │ ═══════ malla ═══════ [ PORTÓN ] ═══════════ malla ════════════════ │
 │                          camino         ┌── recinto TSA ──────┐      │
 │   ┌── caseta ───┐          │            │ [TSA-01]   [TSP-1]  │      │
 │   │ escritorio  │          │            │                     │      │
 │   │ diagrama    ├─puerta───┤            └──────┐  ┌───────────┘      │
 │   │ gabinete    │          │              charco + CABLE VIVO        │
 │   └─────────────┘          │                                         │
 │                       [camioneta]                                    │
 │                         ● Leo                                        │
 └──────────────────────────────────────────────────────────────────────┘
```

- **Camioneta:** multímetro y destornillador.
- **Caseta:** bitácora (historia), diagrama TSA-01 (reglas del puzzle), gabinete de fusibles (reabastece hasta 3).
- **Recinto TSA:** el único acceso cruza un charco con un cable que chispea a intervalos (riesgo eléctrico).
- **Portón:** eléctrico; se abre al recuperar el circuito A → fin del capítulo.
- Antes de la energía: oscuridad, lámpara de casco y balizas rojas. Después: alumbrado encendido.

## 5. Protagonista — Leo

Técnico de mantenimiento, 27 años. Sprite de 20×24 px: casco amarillo con lámpara, camisa
caqui con chaleco naranja reflejante, guantes amarillos, mochila gris de herramientas, radio
al hombro, pantalón azul marino y botas. El casco amarillo y el chaleco naranja lo hacen
legible aun en oscuridad.

Animaciones implementadas: caminar abajo/arriba/lado (izquierda = espejo), correr (caminar
acelerado), reparar/usar herramienta, radio, recibir daño. Interactuar reutiliza "reparar".
Velocidad 62 px/s caminando, 104 corriendo. Salud: 5 cascos.

## 6. Primer puzzle — "Red de distribución" (TSA-01)

Basado en la imagen de referencia: un gabinete verde al centro y nodos con rayo unidos por
conductos. Versión difícil: rejilla 7×7 (48 nodos + banco de emergencia).

**Objetivo:** que el banco alimente los 48 nodos sin ninguna punta suelta.

**Reglas**
+
1. Cada nodo tiene de 1 a 4 brazos y se gira 90° (clic izq/der o E). Los de un brazo son cargas (foco).n
4. La barra empieza **viva (125 V)**. Tocar un nodo así = descarga.
5. Abrir el interruptor no basta: sin medir 0 V con el multímetro queda carga residual = descarga.
6. Girar exige el destornillador en la mano; medir y **ver la continuidad** (conductos en verde)
   exige el multímetro. Hay que alternar herramientas con Q/R.
7. Al cerrar el interruptor: si la red está bien, energiza. Si no, **la protección dispara,
   se quema el fusible de un nodo en falla** y hay que volver a verificar.

**Por qué se puede razonar:** un brazo nunca apunta al borde; un nodo recto en una esquina es
imposible; los remachados fijan a sus vecinos; no puede haber lazos. La red es un árbol
generado con semilla fija (`data/puzzle_tsa01.json`), igual en todas las partidas.

**Pistas:** diagrama de la caseta, voltímetro del tablero, colores (azul vivo, verde continuidad),
lámpara de alarma, mensajes del tablero y avisos por radio.

## 7. Roadmap

| Milestone | Contenido | Estado |
|---|---|---|
| **M1 — Vertical slice Cap. 1** | Menú → Zona 1 → puzzle → energía → victoria. Guardado, HUD, inventario, mapa, clima, audio | **Hecho** |
| M2 — Sistemas básicos | Zona 2 (patio) y Zona 6 (generador). RepairSystem como componente. Fallas: interruptor disparado (diagnóstico de causa) y secuencia de arranque del generador. Transición entre zonas | Siguiente |
| M3 — Baterías y almacén | Zonas 7 y 9. Cable dañado (rastrear tramo), banco de baterías. Detector de tensión, pinzas. Coleccionables | |
| M4 — Transformadores | Zona 3. Puzzle de enfriamiento con temperatura en tiempo real. Primer evento de peligro | |
| M5 — Control | Zonas 4, 5 y 11. Secuencia de protecciones A/B/C. Objetivos secundarios | |
| M6 — Misterio | Zonas 8 y 10. Capítulos 5–7 | |
| M7 — Final y pulido | Zona 12, restablecimiento total, arte y audio definitivos, soporte de control, exportación | |

## Pruebas

```
godot --headless -s tests/test_red_model.gd        # lógica del puzzle
godot --headless res://tests/playthrough.tscn      # Capítulo 1 completo, automático
```
