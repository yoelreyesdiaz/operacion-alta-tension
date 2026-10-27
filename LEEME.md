# Operación Alta Tensión

Juego 2D pixel art (Godot 4.7). Capítulo 1 completo: intro → llegada a la subestación →
caseta → tablero TSA-01 → portón. Obra de ficción.

## Cómo jugar
- **Mac:** doble clic en **`Operación Alta Tensión.app`** (en esta misma carpeta).
- **Windows:** descomprime `ejecutables/OperacionAltaTension_Windows.zip` y abre el `.exe`.
- **Desde Godot:** abre `juego/project.godot` y pulsa F5.

## Recorrido del Capítulo 1
1. Nueva partida → intro (mantén E para saltarla).
2. Camioneta: multímetro y destornillador.
3. Portón: no tiene energía; lo alimenta el tablero TSA-01.
4. Caseta: fusibles en el gabinete, bitácora y diagrama.
5. Recinto este: cuidado con el cable caído, da toques cuando chispea.
6. Tablero TSA-01: medir fusible [2] → cambiarlo [F] → energizar [1] (45 s) →
   girar los 7 nodos con ESPACIO (WASD cambia de nodo) hasta llevar la energía al portón.
7. Volver al portón y abrirlo con E: fin del capítulo.

## Controles
WASD/flechas mover · SHIFT correr · E interactuar · Q/R herramienta · TAB inventario · M mapa · ESC pausa

## Carpetas
- `juego/` — proyecto de Godot (código, arte, audio, datos, pruebas).
- `ejecutables/` — versiones compiladas para compartir (Windows y Mac).
- `avances/` — capturas de avance por día con `AVANCES.txt`.
- `herramientas/` — scripts para capturas del editor y armado de avances.

## Pruebas
```
cd juego
godot --headless -s tests/test_circuito_model.gd
godot --headless res://tests/playthrough.tscn
```

## Equipo
- `CONTEXTO.md` — qué es el proyecto, estructura y reglas de trabajo. Léelo primero.
- `BITACORA.md` — avances por fecha y persona. Agrega tu entrada cada vez que subas cambios.
- Los compilados para jugar están en la sección **Releases** del repositorio en GitHub.
