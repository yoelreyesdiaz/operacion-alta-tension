# Plan: edificio del Capítulo 2 hasta el final del juego

> Para agentes: implementa SOLO tu tarea, con TDD (prueba primero, verla fallar, código mínimo, verla pasar).
> No hagas commit. Diseño: `docs/superpowers/specs/2026-11-19-edificio-seguridad-design.md` (léelo).

**Meta:** cuarto de seguridad (zonas + zombis + cámaras en vivo), tableros TSA-01/TD-02 físicos,
maniobra final física y curar a los 5 compañeros como final del juego.

## Restricciones globales
- Godot 4.7.2, GDScript con tipos y tabulaciones, como el código existente. Sin dependencias nuevas.
- Proyecto: `C:\Users\lilia\Desktop\claude\operacion-alta-tension\juego` (rutas `res://` relativas a él).
- Godot: `/c/Users/lilia/Godot/Godot_v4.7.2-stable_win64_console.exe` (siempre `--headless --audio-driver Dummy --path .`).
- Pruebas: `-s tests/test_circuito_model.gd`, escenas `res://tests/playthrough.tscn`, `test_cap2.tscn`,
  `test_edificio.tscn`, `test_inventario.tscn` y las nuevas. Una prueba `-s` (SceneTree) no puede
  usar autoloads; las pruebas de modelos puros pueden ser `-s`.
- Textos del juego en español. Tono aventura técnica, NUNCA terror ni gore.
- Regla del juego: toda acción importante se hace en el mundo con Leo y una animación visible
  (`Player.perform`). Solo la red de nodos del tablero sigue en pantalla.
- Archivos con CRLF: al editar con Python normaliza (`newline=''`). No toques los `.import` existentes.
- No cambies archivos que pertenecen a otra tarea (lista en cada tarea).

## Interfaces compartidas (nombres exactos)

### Hoja de Leo `assets/sprites/leo.png` (20×24 por cuadro, 4 columnas, 9 filas)
Filas 0-4 sin cambio. Nuevas:
- fila 5: `palanca` cols 0-3 (de espaldas, brazos arriba → baja la palanca)
- fila 6: `medir` cols 0-1 (de espaldas, puntas del multímetro), `fusible` cols 2-3 (de espaldas, mete fusible)
- fila 7: `sentado` cols 0-1 (de espaldas, sentado tecleando), `boton` cols 2-3 (de espaldas, brazo presiona)
- fila 8: `ayudar` cols 0-1 (de frente, agachado tendiendo la mano)

### `Player` (scripts/player/player.gd)
- `func perform(anim: String, time: float, face := "up") -> void` — corutina: Leo se voltea, reproduce
  la animación `anim`, no se mueve ni interactúa durante `time` s, y regresa a idle. No usa `GameState.modal`
  (el mundo sigue corriendo). `var performing: bool` es true mientras dura.
- Animaciones en `_build_frames`: `"palanca": [5,[0,1,2,3],8.0,false]`, `"medir": [6,[0,1],4.0,true]`,
  `"fusible": [6,[2,3],4.0,true]`, `"sentado": [7,[0,1],3.0,true]`, `"boton": [7,[2,3],6.0,false]`,
  `"ayudar": [8,[0,1],4.0,true]`.

### Sprites nuevos (`tools/gen_cap2_art.py`, `assets/sprites/*.png`)
`tablero_zonas` (64×40, sin interruptores), `interruptor_on`/`interruptor_off` (6×10), `medidor` (24×18,
sin aguja), `monitor_pared` (40×28; pantalla en x3..36, y3..22), `consola_seguridad` (56×24), `silla` (14×16),
`puerta_blindada_cerrada`/`puerta_blindada_abierta` (48×32), `principal_on`/`principal_off` (16×24),
`luz_emergencia` (10×6), `mesa_comedor` (32×18), `archivero` (14×22), `fusible_fundido`/`fusible_nuevo`
(4×8), `palanca_arriba`/`palanca_abajo` (8×14), `cuchillas_cerradas`/`cuchillas_abiertas` (32×36),
`punto_prueba` (12×14), `rack_tierras` (20×24), `tierras_puestas` (20×24), `reloj_pared` (24×14).

### `ZonasModel` (scripts/systems/zonas_model.gd, `class_name ZonasModel extends RefCounted`)
Datos `data/zonas_edificio.json`: `{"capacidad": 12, "arranque": 25, "zonas": [{"id","nombre","carga","tipo","cuarto"}]}`
con tipo `obligatoria|carnada|puerta`. Zonas: pasillo_norte 3 obl, sala_control 4 obl, servicios 3 obl,
taller 2 carnada, bodega 2 carnada, comedor 1 carnada, maquinas 3 carnada, puerta_blindada 2 puerta.
- `load_cfg(cfg: Dictionary)`, `ids() -> Array[String]`, `zone(id) -> Dictionary`, `is_on(id) -> bool`
- `toggle(id) -> String`: "ok" o "sobrecarga" (si la suma de encendidas pasa de la capacidad → `tripped=true`)
- `set_on(id, on: bool) -> String` igual que toggle pero explícito
- `powered(id) -> bool` (encendida y sin disparo), `total() -> float` (0 si disparado)
- `reset_main() -> String`: rearma; si la suma sigue > capacidad queda disparado y devuelve "sobrecarga"
- `lures_on() -> Array[String]` carnadas con energía; `tick(delta) -> String` "" o "arrancado"
- `var capacity`, `var boot_time`, `var boot` (s acumulados), `var booted`, `var tripped`
- `boot_ratio() -> float`, `reset()` (todo apagado, boot 0, sin disparo, booted false)

### `MapaCuartos` (scripts/systems/mapa_cuartos.gd, `class_name MapaCuartos extends RefCounted`)
Datos: `{"cuartos": {"id": [x,y,w,h]}, "puertas": [{"a": id, "b": id, "pos": [x,y], "abierta": true}]}` (px).
- `load_cfg(cfg)`, `room_at(p: Vector2) -> String` ("" si ninguno), `rect(id) -> Rect2`, `center(id) -> Vector2`
- `set_door(a: String, b: String, open: bool)`, `door_open(a, b) -> bool`
- `route(from: Vector2, to: Vector2) -> PackedVector2Array` puntos de puertas (BFS por cuartos) y al final `to`;
  vacío si no hay camino. Mismo cuarto → `[to]`.

### Cámaras (scripts/systems/camara_feed.gd, camara_monitor.gd; scripts/ui/consola_camaras.gd)
- `class_name CamaraFeed extends SubViewport`: `setup(world: World2D, focus: Rect2, nombre: String)`; tamaño 160×96,
  Camera2D interna centrada y con zoom para que quepa `focus`. `var nombre`.
- `class_name CamaraMonitor extends Node2D`: `setup(feed: CamaraFeed)`; dibuja `monitor_pared` y la imagen en vivo
  en la pantalla, con tinte verdoso, líneas de barrido y el nombre. Se coloca con su pie en `position`.
- `class_name ConsolaCamaras extends CanvasLayer` (layer 15): `setup(feeds: Array[CamaraFeed])`; cuadrícula 2×3
  en vivo con nombres; propiedades `boot_ratio: float`, `load_kw: float`, `capacity_kw: float`, `tripped: bool`
  que dibuja abajo; `alert(i: int, on: bool)` hace parpadear un cuadro; señal `closed` al presionar
  `interact`, `pause` o moverse; ocupa toda la pantalla.

### `TableroFisico` (scripts/systems/tablero_fisico.gd, `class_name TableroFisico extends Node2D`)
- Se crea con `TableroFisico.new()`, se asigna `config_path` y se agrega al `_entities` del nivel en el pie del tablero.
- Dibuja `tsa_off`/`tsa_on`, el fusible (`fusible_fundido`/`fusible_nuevo`, oculto hasta medir) y la palanca.
- Puntos de uso (Interactable): tapa (destornillador en mano, `perform("medir"...)`/`"fusible"` según paso),
  portafusibles (medir con multímetro → anim `medir`; cambiar con fusible → anim `fusible`), palanca (anim `palanca`
  → `model.start()` → abre `tablero_tsa` ya energizado, inyectando `model`).
- Señales: `solved`, `tool_missing(tool: String)`, `first_open`. `var model: CircuitoModel`, `func set_on(on: bool)`.
- Guarda el modelo en `GameState.puzzles[id]`. Radio "fusible_abierto" la 1ª medición y "disparo" el 1er disparo.
- `tablero_tsa.gd`: sin botones ni teclas de medir/fusible/energizar ni panel de pasos; `var model` inyectable;
  al disparo muestra el mensaje 1.5 s y se cierra solo; `tool_1`/`tool_2` cambian de herramienta.

## Tareas (orden del orquestador)

**Fase 1 (paralelo)**
1. **Arte** — `tools/gen_art.py` (solo `leo()`/`leo_sheet()`), `tools/gen_cap2_art.py`, `assets/sprites/` nuevos y `leo.png`.
   Ejecuta los generadores; revisa las imágenes a 4× con PIL. Verifica que `leo.png` sea 80×216.
2. **Modelos** — `zonas_model.gd`, `mapa_cuartos.gd`, `data/zonas_edificio.json`, `tests/test_zonas_model.gd`,
   `tests/test_mapa_cuartos.gd` (ambas `-s`, con casos de la sección 7 del diseño).
3. **Cámaras** — los tres archivos de cámaras y `tests/test_camaras.gd/.tscn` (mundo de prueba con un sprite
   que se mueve: el feed lo ve; la consola emite `closed` con E; capturas con `--shots`).
4. **Físico** — `player.gd`, `tablero_fisico.gd`, `tablero_tsa.gd`, `zona_01.gd`, la parte del TD-02 en
   `edificio.gd`, `data/dialogos_cap1.json` si hace falta, `tests/playthrough.gd`, `tests/test_edificio.gd`
   (solo la parte del TD-02), `tests/test_inventario.gd`.

**Fase 2** — **Edificio**: `edificio_mapa.gd` (casillas, paredes, puertas, props, datos de cuartos), `edificio.gd`
(estados, cuarto de seguridad, tablero de zonas físico, medidor, principal, puerta blindada, monitores, consola,
presentación por cámara, zombis con `MapaCuartos`), `companero.gd` (`follow(route)` y `roam(rect)`),
`quest.gd`, `dialogos_cap2.json`, `tests/test_edificio.gd` completo.

**Fase 3** — **Final**: maniobra en la sala de control y curar a los compañeros (decisiones abajo),
`victory` del Capítulo 2, pruebas en `tests/test_final.gd/.tscn`.

**Fase 4** — **Revisión**: revisor independiente + corrige lo confirmado; corre TODAS las pruebas.

## Decisiones del final (tomadas)
- Al completar el arranque se abre la sala de control; al entrar, su puerta se cierra detrás (los zombis no entran).
  Radio: el transformador sigue energizado y eso mantiene cargados a los compañeros; hay que desenergizar y aterrizar.
- Maniobra contra reloj de 90 s (reloj de pared en el mundo), 4 estaciones físicas en orden:
  1 abrir interruptor de potencia (`palanca`), 2 abrir cuchillas (`palanca`), 3 verificar ausencia de tensión con el
  multímetro en la mano (`medir`), 4 colocar tierras (`fusible`, 2 s). Paso fuera de orden: alarma y −10 s.
  Tiempo agotado: el sistema se restablece y se reinicia la maniobra.
- Al poner las tierras: las luces parpadean, los compañeros se descargan, caen y quedan aturdidos donde estaban.
  Objetivo «Ayuda a tus compañeros (n/5)». Leo camina a cada uno: «Ayudar a levantarse» → `perform("ayudar", 1.2, ...)`
  → el compañero se levanta normal (fila 0, sin chispas ni humo) y da las gracias. Con los 5: radio de cierre de
  Ing. Morales, fundido y pantalla de victoria del Capítulo 2 (los 5 sanos).
