# CONTEXTO DEL PROYECTO — Operación Alta Tensión

> Documento vivo. Léelo antes de empezar a trabajar. Si cambia algo importante
> (una decisión, una regla, la estructura), actualízalo en el mismo cambio.

## Qué es
Videojuego 2D en pixel art para PC hecho en **Godot 4.7 (GDScript)**. Leo, técnico de
mantenimiento, entra de noche y en plena tormenta a una subestación eléctrica en Guadalajara
para devolverle la energía; las fallas no son todas por la tormenta. Obra de ficción: la empresa
y la subestación (S.E. Atemajac) no representan instalaciones reales.

## Estado actual
- **Capítulo 1 completo y jugable:** intro cinemático → llegada → camioneta → portón →
  caseta (fusibles, bitácora, diagrama) → cable caído que da toques → tablero TSA-01 → portón → fin.
- **Tablero TSA-01 (puzzle):** medir el fusible con el multímetro → cambiarlo → energizar
  (45 s) → girar 7 nodos con ESPACIO para llevar la energía por el cable hasta el portón.
- Siguiente: Capítulo 2 (patio de interruptores y generador auxiliar).

## Estructura del repositorio
| Carpeta | Contenido |
|---|---|
| `juego/` | Proyecto de Godot. Ábrelo con `juego/project.godot`. |
| `juego/autoload/` | Sistemas globales: GameState, Inventory, PowerGrid, Quest, Radio, SaveSystem, Transition, Narrator, AudioManager. |
| `juego/scripts/` | Jugador, nivel (zona_01), tablero (puzzles), intro (cinematics), UI. |
| `juego/data/` | Textos y datos editables sin tocar código: diálogos, objetos, intro, configuración del tablero. |
| `juego/assets/` | Sprites, tiles, audio, fuente. Se generan con `juego/tools/*.py`. |
| `juego/tests/` | Pruebas automáticas. |
| `juego/docs/GDD.md` | Documento de diseño completo (historia, zonas, capítulos, roadmap). |
| `avances/AAAA-MM-DD/` | Capturas reales del avance del día + `AVANCES.txt` (para entregables). |
| `herramientas/` | Scripts para capturas del editor y armado de avances. |

## Cómo trabajar en equipo
1. **Antes de empezar:** `git pull` para traer lo último.
2. Trabaja en una **rama** con tu nombre y el tema: `git checkout -b yoel/tablero-sonidos`.
3. Antes de subir, corre las pruebas (deben salir **OK**):
   ```
   cd juego
   godot --headless -s tests/test_circuito_model.gd
   godot --headless res://tests/playthrough.tscn
   ```
4. Agrega una entrada en **`BITACORA.md`** con lo que hiciste.
5. Sube tu rama y abre un **Pull Request** en GitHub para que el equipo lo revise antes de unirlo a `main`.
6. Los compilados (.exe / .app) no van en el código: se publican en **Releases** de GitHub.

## Cómo unirse al equipo
- Para **ver** el avance basta el link del repositorio (es público).
- Para **subir cambios** hace falta una cuenta de GitHub y una invitación del dueño:
  Settings → Collaborators → Add people (por usuario o correo). Llega un correo para aceptar.

## Reglas y decisiones del proyecto
- Resolución 426×240 con escalado entero; pixel art nítido (filtro *nearest*).
- Textos y datos en `juego/data/*.json` siempre que se pueda, para editarlos sin programar.
- La seguridad eléctrica es mecánica de juego: **corta → verifica → trabaja → restablece**.
- Tablero: pocos nodos (no saturar), cable fijo con tramos rectos y curvas, nodos que empiezan girados.
- Capturas de avance: **solo capturas reales** del juego y del editor, nada de imágenes armadas;
  20–30 por día, solo de lo trabajado ese día, con `AVANCES.txt`.
- Mensajes de commit en español, cortos y claros: qué cambió y por qué.
