# BITÁCORA DE AVANCES — Operación Alta Tensión

> Agrega tu entrada **arriba** (lo más reciente primero). Formato:
> `## 2026-11-13 · Yoel
- Capítulo 2, cinemática 2: el rayo ahora se ve caer. La cámara sube al cielo, el rayo baja en
  zigzag desde arriba de la pantalla (nubes iluminadas y chispas en la punta) hasta el
  transformador; golpe con destello más corto para que el rayo se vea; después la cámara baja y
  la energía corre por el piso del transformador a cada cuerpo antes de que se levanten.
- Cambios en `scripts/levels/zona_02.gd` (`_start_descent`, `_start_ground`, dibujo en `_draw_fx`)
  y en el guion `cin2` de `data/cinematicas_cap2.json` (dura 11.25 s).
- Pruebas: `test_circuito_model`, `playthrough` y `test_cap2` OK.

## AAAA-MM-DD · Nombre` y luego viñetas: qué hiciste, qué falta, problemas.

## 2026-11-19 · Sofía
- Acciones físicas en todo el juego: `Player.perform(anim, tiempo, cara)` y animaciones nuevas de Leo
  (palanca, medir, fusible, sentado, botón, ayudar). Los tableros TSA-01 y TD-02 son físicos
  (`TableroFisico`): tapa con destornillador, medir y cambiar el fusible y bajar la palanca en el
  mundo; la pantalla de nodos abre ya energizada y `1`/`2` vuelven a cambiar de herramienta.
- Edificio con cuartos y puertas (`edificio_mapa.gd`). Cuarto de seguridad: tablero de 8 zonas con
  medidor de kW (`ZonasModel`, capacidad 12 kW, arranque de 25 s), interruptor principal, puerta
  blindada con botón, 6 monitores en vivo y la consola con la vista 2×3 (`CamaraFeed`,
  `CamaraMonitor`, `ConsolaCamaras`). Los compañeros electrizados entran por el acceso y van tras
  la luz (carnadas) o, sin carnada, al cuarto de seguridad; se mueven por las puertas (`MapaCuartos`).
- Final del Capítulo 2: en la sala de control, maniobra contra reloj de 90 s (potencia, cuchillas,
  verificar ausencia de tensión, tierras); fuera de orden cuesta 10 s. Con las tierras los 5 se
  descargan; Leo ayuda a cada uno a levantarse y aparece la victoria del Capítulo 2.
- Revisión: los compañeros ya no atraviesan muros cuando Leo cambia de cuarto (recalculan la ruta
  por las puertas); si alcanzan a Leo a media acción, el interruptor/principal/botón no se aplica
  después del reinicio; se quitaron las teclas viejas del tablero (medir/fusible/energizar) y la
  ayuda de controles; textos de radio corregidos (todo está en la pared norte del cuarto).
- Pruebas nuevas: `test_zonas_model`, `test_mapa_cuartos`, `test_camaras`, `test_final`; se
  actualizaron `playthrough`, `test_edificio` y `test_inventario`.
- Falta: probar a mano la dificultad del puzzle de zonas; «Guardar y salir» en el Capítulo 2 y luego
  «Continuar» regresa al nivel 1 (viene de antes, el guardado no recuerda el nivel).

## 2026-11-05 · Sofía
- Inventario siempre visible en todo el juego: barra de chaleco abajo a la izquierda con un
  bolsillo numerado por herramienta, el nombre de la que está en la mano, y los fusibles y
  documentos en cuanto se consiguen. La lámpara y el radio no salen porque siempre se traen.
- Cambio de herramienta con `1` (multímetro), `2` (destornillador) y la rueda del mouse; Q/R
  siguen funcionando. En el tablero, `1` y `2` conservan su función (energizar y medir), la
  rueda sí cambia de herramienta y un indicador «MANO» muestra la que traes.
- Prueba nueva: `tests/test_inventario.tscn` (teclas y rueda reales, también en el tablero).

## 2026-10-30 · Sofía
- Capítulo 2 jugable (Zona 2, `scenes/levels/zona_02.tscn`), que reemplaza la cinemática anterior
  «El impacto del rayo». Secuencia: entrada por el portón del nivel 1 → zona A: cinemática 1
  (los 5 compañeros reciben una descarga en el transformador y caen) → carrera para ayudarlos →
  zona B: cinemática 2 (un rayo cae en el transformador y se levantan como trabajadores
  electrizados) → huida al edificio (los zombis persiguen; caminando te alcanzan, corriendo con
  SHIFT te les adelantas) → zona C: puerta de la oficina, fin con fundido.
- Cinemática 2 más intensa: el rayo cae con ramas, doble golpe, onda en el piso, temblor de
  cámara y una luz que ilumina todo el patio. La transformación se ve: los cuerpos convulsionan
  y parpadean entre su aspecto normal, el cuerpo cargado (fila 3 de `trabajador.png`) y el
  electrizado; al levantarse la ropa humea. El uniforme electrizado queda rasgado y chamuscado
  (manchas de quemado, dobladillo deshilachado, mangas rotas, agujeros en el pantalón).
- Si te alcanzan, el tramo se reinicia desde el final de la cinemática 2 (no se repiten las cinemáticas).
- Mapa abierto inspirado en la foto de referencia: naves al norte, fila de transformadores al
  centro, patio de interruptores al suroeste, tanques al este, oficina y portón al sur.
- Arte nuevo en `tools/gen_cap2_art.py` (naves, oficina, caseta, tanque); se reutilizan
  `trabajador.png`, `trafo.png`, `interruptor_potencia.png` y el portón del nivel 1.
- Guion de las cinemáticas en `data/cinematicas_cap2.json`. El reproductor de eventos ahora es
  compartido (`scripts/cinematics/cine_events.gd`) entre cinemáticas y niveles.
- Se quitó la intro anterior: `cap2_impacto.tscn`, `cinematica_cap2.json`, `patio_noche.png`,
  `trabajador_cerca.png` y sus tomas en `shots.gd`.
- Prueba nueva: `tests/test_cap2.tscn` (35 verificaciones, con persecución usando teclas reales).
- Interior del edificio (`scenes/levels/edificio.tscn`): al llegar a la puerta se entra a un pasillo
  con la puerta, el tablero TD-02 y un gabinete. Mismo proceso que el portón: revisar la puerta →
  destornillador en el tablero → medir, cambiar fusible, energizar y girar nodos → abrir. Al abrir se
  destapa todo el salón con un recorrido de cámara. Por ahora el salón solo se recorre.
- Tablero TD-02 (`data/puzzle_puerta.json`), más difícil que el TSA-01: 9×9, 12 nodos, 5 s por nodo
  (TSA-01: 6.4) y 4 TIERRAS. Algunos nodos son piezas en T: si la tercera salida toca una tierra hay
  corto, resta 5 s y no se resuelve hasta alejarla. `tablero_tsa.gd` ahora se configura con un JSON.
- Falta: qué pasa dentro del edificio una vez abierto.

## 2026-10-27 · Sofía
- Capítulo 2 — «El impacto del rayo»: cinemática de apertura. Al volver a la camioneta, un rayo
  cae sobre la cuadrilla que revisa un poste: explosión azulada, la descarga alcanza la camioneta,
  la lámpara de Leo estalla y, en la oscuridad, los trabajadores siguen de pie soltando chispas
  con ojos azules. Uno gira la cabeza hacia Leo.
- Trabajadores electrizados a partir del dibujo de la autora (`assets/fuentes/trabajador_electrizado.ase`),
  repintados con la paleta y el uniforme de Leo, rasgado tras la descarga. Se generan con
  `python tools/gen_cap2_art.py`.
- La pantalla de victoria ahora tiene «Continuar: Capítulo 2». El reproductor de cinemáticas
  acepta cualquier guion JSON (`data_path`).
- Falta: la parte jugable del Capítulo 2 después de la cinemática.

## 2026-10-27 · Equipo
- Proyecto subido a GitHub. Se crearon `CONTEXTO.md` (contexto y reglas) y esta bitácora.
- Compilados del Capítulo 1 publicados en Releases (Windows y Mac), reconstruidos desde la
  versión más reciente: intro, tablero de 7 nodos con timer de 45 s y apertura del portón.
- Repositorio público para compartir el avance.

## 2026-10-23 · Equipo
- Todo el proyecto quedó en una sola carpeta: juego, ejecutables, avances y herramientas.
- Confirmado: el cable caído da toques (quita un casco).
- Ejecutables nuevos del Capítulo 1 completo y app de Mac de doble clic.

## 2026-10-22 · Equipo
- Se unió la versión del Drive (intro cinemático, transiciones, narrador, diálogos con Don Chuy)
  con el original (menú, caseta, energía, mapa, guardado, victoria).
- Rediseño del tablero TSA-01 en 3 iteraciones hasta la final: medir fusible → cambiarlo →
  energizar con timer → girar 7 nodos con ESPACIO por un cable con tramos rectos y curvas.
- 30 capturas de avance del tablero en `avances/2026-10-22/`.

## 2026-10-19 · Equipo
- Entregables por fase: Fase 1 (hasta la camioneta) y versión hasta el tablero bloqueado.

## 2026-10-06 · Equipo
- Vertical slice del Capítulo 1: personaje, Zona 1, caseta, puzzle del tablero, energía,
  lluvia, audio, HUD, inventario, mapa, guardado y pantalla de victoria.
