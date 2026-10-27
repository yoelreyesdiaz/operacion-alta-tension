# BITÁCORA DE AVANCES — Operación Alta Tensión

> Agrega tu entrada **arriba** (lo más reciente primero). Formato:
> `## AAAA-MM-DD · Nombre` y luego viñetas: qué hiciste, qué falta, problemas.

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
