# Diseño: cuarto de seguridad del edificio y tableros físicos

Fecha: 2026-11-19 · Capítulo 2 · Rama `sofia/cap2-impacto-rayo`

## 1. Objetivo

Dentro del edificio del nivel 2, el jugador enciende el edificio por zonas desde un **cuarto de
seguridad** mientras los compañeros electrizados lo acechan. Para cuidarse vigila **cámaras en
vivo** y usa la luz como carnada. Al terminar se abre la sala de control.

Junto con esto entra en vigor una **regla para todo el juego**: las acciones se hacen moviendo a
Leo en el mundo y se ve la animación (bajar una palanca, medir, cambiar un fusible, sentarse).
Por eso los tableros TSA-01 (nivel 1) y TD-02 (pasillo del edificio) pasan a ser físicos. Solo la
red de nodos («el circuito») se queda en pantalla, igual que hoy.

**Criterios de éxito**
- El puzzle de zonas es medianamente difícil: obliga a decidir entre carnada y puerta blindada
  más de una vez durante los 25 s de arranque.
- Las cámaras sirven para jugar: sin mirarlas, es fácil que un zombi te alcance.
- Ninguna acción importante se resuelve con una tecla en una pantalla, salvo girar nodos.
- El tono sigue siendo aventura técnica, no terror (sin sustos ni gore).
- Todas las pruebas automáticas pasan.

**Fuera de este diseño** (sub-proyectos posteriores, cada uno con su propio diseño)
- La maniobra final en la sala de control: abrir el interruptor, las cuchillas y poner tierras,
  con acciones físicas.
- Curar a los compañeros («que todos queden sanos») como objetivo final.

## 2. Recorrido del nivel

1. **Pasillo (como hoy).** Revisar la puerta → gabinete → **TD-02 físico** (sección 5). Al
   resolver el circuito, la puerta tiene energía y se abre.
2. **Edificio a oscuras.** Al abrir la puerta no hay recorrido de cámara por el salón: el
   edificio sigue sin luz (solo luces de emergencia tenues). Nuevo objetivo: *«Enciende el
   edificio desde el cuarto de seguridad»*.
3. **Presentación.** Al entrar al cuarto de seguridad, el monitor del acceso principal se
   destaca: los 5 compañeros electrizados fuerzan la puerta principal y entran. Leo reacciona
   por radio con Ing. Morales, que explica la idea de la carnada.
4. **Puzzle de zonas con zombis** (secciones 3 y 4).
5. **Arranque completo.** La sala de control se desbloquea: se abre su puerta y el objetivo pasa
   a *«Ve a la sala de control»*. Hasta aquí llega este diseño.

Objetivos nuevos en `Quest` (capítulo 2), después de `abrir_puerta`: `seguridad` (llegar al
cuarto), `zonas` (encender las obligatorias), `arranque` (completar el arranque) y `control` (ir
a la sala de control). Se quita `explorar`.

## 3. Nuevo interior del edificio

Mismo tamaño de mapa: 60×39 casillas de 16 px. El salón abierto se reemplaza por cuartos con
paredes y puertas. Distribución de referencia (en casillas; los números exactos los fija el
plan):

```
 x→ 0        12        24          36        48        60
 y0 ┌─────────┬─────────┬───────────┬───────────────────┐
    │ TALLER  │ BODEGA  │ PASILLO N │  SALA DE CONTROL   │
    │         │         │   (P.N.)  │   (cerrada)        │
 y12├───D─────┴───D─────┤           ├────────D──────────┤
    │ COMEDOR      D   VESTÍBULO    D   CUARTO DE        │
    │              │               │   MÁQUINAS         │
 y22├────D─────────┤   SEGURIDAD   ├───────────D───────┤
    │ OFICINA      │   (monitores, │  ACCESO PRINCIPAL  │
    │              │   tablero)    │  (puerta a patio)  │
 y25└──────────────┴──────D────────┴───────────────────┘
                     PASILLO DE ENTRADA (TD-02, como hoy)
```
D = puerta. El cuarto de seguridad conecta con el pasillo de entrada (la puerta del TD-02) y con
el vestíbulo mediante la **puerta blindada**.

**Cuarto de seguridad** (paredes y objetos, todo físico):
- Pared norte: 6 monitores chicos en vivo y, debajo, la consola con silla.
- Pared este: tablero de zonas (8 interruptores) con el medidor de aguja de kW arriba.
- Pared oeste: interruptor principal, para rearmarlo tras una sobrecarga.
- Puerta blindada al vestíbulo, con botón a un lado.

Arte nuevo, hecho con `tools/gen_cap2_art.py`: tablero de zonas con interruptores
arriba/abajo, medidor de aguja, monitor de pared, consola con silla, puerta blindada (abierta y
cerrada), interruptor principal, mesas del comedor, archiveros de la oficina y luz de
emergencia. Se reutilizan los props existentes (bancos del taller, estantes, máquinas, racks,
consola, cajas, escritorios).

## 4. Puzzle de zonas y zombis

### 4.1 Zonas (datos en `data/zonas_edificio.json`)

| Zona | Carga | Tipo |
|---|---|---|
| Pasillo norte | 3 kW | obligatoria |
| Sala de control | 4 kW | obligatoria |
| Servicios (ventilación) | 3 kW | obligatoria |
| Taller | 2 kW | carnada (atrae) |
| Bodega | 2 kW | carnada |
| Comedor | 1 kW | carnada |
| Máquinas | 3 kW | carnada |
| Puerta blindada | 3 kW | mientras está cerrada (no cabe junto con las 3 obligatorias) |

- Capacidad: **12 kW**. Las obligatorias suman 10, así que sobran 2.
- **Sobrecarga** (la suma pasa de 12): salta el principal, se apaga todo (la puerta blindada se
  abre) y los zombis van hacia el cuarto de seguridad. Hay que caminar al interruptor principal
  y rearmarlo (animación de palanca, 1.5 s). Los interruptores conservan su posición, así que
  antes de rearmar hay que bajar carga o vuelve a saltar.
- **Arranque**: mientras las 3 obligatorias están encendidas, la sala de control avanza hacia
  25 s; una barra en los monitores lo muestra. Si se apaga una obligatoria, el arranque se
  **pausa**; no se pierde lo avanzado. Al llegar a 25 s se completa y ya no se puede perder.
- Encender una zona enciende las luces de su cuarto. Las zonas con equipo (las de carnada)
  además suenan y parpadean.

### 4.2 Comportamiento de los zombis

- Son los mismos 5 `Companero` electrizados del patio, que entran por el acceso principal.
- **Destino**: el cuarto de carnada encendido más cercano (por ruta). Al llegar, rondan dentro
  del cuarto mientras siga encendido. Si no hay carnada encendida, caminan **lento** hacia el
  cuarto de seguridad.
- Se mueven de cuarto en cuarto por las puertas (`MapaCuartos`), sin atorarse en paredes.
- **Puerta blindada cerrada**: no pasan; golpean (sonido y chispas). **Abierta**: si un zombi
  toca a Leo, se reinicia el tramo: todo se apaga, el arranque vuelve a 0, los zombis regresan
  al acceso y Leo aparece frente al tablero. No hay daño, como en la huida del patio.
- Velocidad: más lenta que Leo caminando; se reutiliza la del patio.

### 4.3 Cámaras en vivo

- 6 cámaras: acceso principal, vestíbulo, taller, bodega, comedor y máquinas. La oficina y el
  pasillo norte no tienen cámara (puntos ciegos).
- Cada cámara es un `SubViewport` que comparte el mundo del nivel, con su propia `Camera2D`
  fija sobre el cuarto. Se ve lo que pasa de verdad, con un filtro verdoso de monitor y una
  etiqueta con el nombre del cuarto.
- **Monitores de pared**: los 6 chicos en la pared norte, siempre encendidos (van con la UPS,
  no cuentan en la carga).
- **Consola**: Leo camina a la silla, la usa (animación de sentarse) y la vista pasa a una
  cuadrícula grande de 2×3 cámaras con la barra de arranque y el medidor de carga. Moverse o
  presionar E lo levanta. Sentado no puede tocar el tablero, que está en otra pared: esa es la
  tensión del puzzle.

## 5. Regla de acciones físicas y tableros

### 5.1 Acción física del jugador

Nueva función en `Player`: `perform(anim, time, facing)` reproduce una animación de acción, deja
a Leo quieto ese tiempo y regresa con `await`. Animaciones nuevas en `leo.png`, generadas con
`tools/gen_art.py`:
- `palanca`: baja una palanca.
- `medir`: puntas del multímetro.
- `fusible`: saca y pone un fusible.
- `boton`: presiona un botón.
- `sentado`: frente a la consola.

Las usan los interruptores de zonas, el principal, el botón de la puerta blindada, la consola y
los tableros.

### 5.2 Tableros TSA-01 y TD-02 físicos

En el mundo, cada tablero tiene tres puntos de uso en su frente: **portafusibles**, **palanca de
energizar** y **puerta del circuito**. Los pasos reales:

1. Abrir la tapa con el destornillador en la mano (animación, como hoy).
2. **Medir el fusible**: multímetro en la mano, en el portafusibles → animación `medir`. La
   lectura aparece sobre el tablero (∞ Ω, en rojo).
3. **Cambiar el fusible**: en el portafusibles con fusibles en el inventario → animación
   `fusible`. Se ve el fusible nuevo (verde).
4. **Energizar**: en la palanca → animación `palanca`. Empieza el tiempo y se abre la pantalla
   de nodos, ya energizada.
5. **Circuito** (pantalla, sin cambios en su juego): girar nodos con ESPACIO o clic hasta la
   salida, con las tierras del TD-02.
6. Si se acaba el tiempo, la pantalla se cierra, el fusible se ve fundido en el tablero y se
   vuelve al paso 3.

Cambios en `tablero_tsa.gd`: se quitan los botones y teclas de medir, fusible y energizar, y el
panel de pasos. La pantalla abre ya energizada y conserva el tiempo, el avance, las tierras, la
animación de energía y el indicador «MANO». Dentro de la pantalla, `1` y `2` vuelven a ser
herramientas (ya no chocan). `CircuitoModel` no cambia sus reglas, solo quién llama a
`measure_fuse`, `replace_fuse` y `start`.

## 6. Piezas del código

| Pieza | Archivo | Responsabilidad |
|---|---|---|
| ZonasModel | `scripts/systems/zonas_model.gd` | Zonas, cargas, capacidad, sobrecarga, arranque y carnadas. Sin dibujo. |
| MapaCuartos | `scripts/systems/mapa_cuartos.gd` | Cuartos (Rect2), puertas, cuarto de un punto, ruta entre puntos por las puertas. |
| Cámaras | `scripts/systems/camara_monitor.gd`, `scripts/ui/consola_camaras.gd` | Monitor de pared en vivo; vista 2×3 de la consola. |
| Tablero físico | `scripts/systems/tablero_fisico.gd` | Tablero en el mundo con sus pasos físicos; abre `tablero_tsa` energizado. |
| Acción física | `scripts/player/player.gd` | `perform()` y las animaciones nuevas. |
| Zombis | `scripts/levels/companero.gd` | Seguir una ruta de `MapaCuartos` y rondar dentro de un cuarto. |
| Mapa del edificio | `scripts/levels/edificio_mapa.gd` | Casillas, paredes, puertas y props del interior. |
| Nivel | `scripts/levels/edificio.gd` | Estados y recorrido: pasillo → abriendo → seguridad → arranque → control. |
| Nivel 1 | `scripts/levels/zona_01.gd` | Usa el tablero físico para el TSA-01. |
| Datos | `data/zonas_edificio.json`, `data/dialogos_cap2.json`, `data/puzzle_*.json` | Números del puzzle y diálogos nuevos. |

## 7. Pruebas

Primero la prueba y luego el código (TDD), con teclas y rueda reales donde haya jugador.

- `tests/test_zonas_model.gd` (unitaria): suma de cargas; sobrecarga al pasar de 12; rearmar con
  carga alta vuelve a saltar; el arranque avanza solo con las 3 obligatorias, se pausa y no se
  pierde; la puerta cuenta 3 kW; las carnadas encendidas se reportan.
- `tests/test_mapa_cuartos.gd` (unitaria): cuarto de un punto; ruta del acceso al cuarto de
  seguridad pasando por puertas; sin ruta a la sala de control mientras está cerrada.
- `tests/playthrough.tscn` (actualizada): TSA-01 físico (medir, cambiar fusible, palanca y
  circuito).
- `tests/test_edificio.tscn` (actualizada): TD-02 físico; entrada al cuarto de seguridad y
  presentación por cámara; una carnada atrae a un zombi a su cuarto; cerrar la puerta lo
  detiene; la sobrecarga apaga todo y abre la puerta; rearmar; un zombi que te alcanza reinicia
  el tramo; con las obligatorias encendidas el arranque llega a 25 s y se abre la sala de
  control; la consola muestra las 6 cámaras.
- `tests/test_inventario.tscn` (actualizada): en la pantalla de nodos, `1` y `2` cambian de
  herramienta.
- `tests/test_cap2.tscn`, `tests/test_circuito_model.gd`: deben seguir pasando.
- Capturas en ventana para revisar arte, monitores, consola y animaciones de Leo.

## 8. Ejecución

Después de aprobar el plan, un orquestador de agentes trabaja en paralelo lo que no depende
entre sí (máximo 4 agentes):
1. Arte: interior, tablero de zonas, monitores y animaciones de Leo.
2. `ZonasModel` y `MapaCuartos`, con sus pruebas unitarias.
3. Cámaras: monitor de pared y vista de la consola.
4. Acción física y tableros físicos (TSA-01 y TD-02).

La integración en `edificio.gd` y `edificio_mapa.gd`, las pruebas de recorrido, la revisión de
código y la verificación final se hacen en secuencia al terminar.

## 9. Riesgos

- **Rendimiento de 6 cámaras en vivo**: 6 `SubViewport` chicos de 426×240 escalados. Si baja el
  rendimiento, las cámaras de pared se actualizan cada pocos cuadros y solo la consola va en
  tiempo real.
- **Legibilidad a 426×240**: los monitores de pared son pequeños; la consola es la vista para
  jugar.
- **Dificultad**: los números viven en el JSON para ajustarlos tras probarlo a mano.
- **Partidas guardadas**: el guardado ya no lleva el estado de los pasos del tablero en
  pantalla; las banderas del nivel 1 se mantienen compatibles.
