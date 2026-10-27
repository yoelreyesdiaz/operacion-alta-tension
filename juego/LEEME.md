# Operación Alta Tensión — versión de trabajo (22-oct-2026)

Unión de dos versiones:
- **Original de la Mac** (`proyecto-beta-cfe`): menú, Zona 1 completa, caseta, energía, mapa, inventario, guardado, victoria.
- **Versión del Drive** (16-oct): intro cinemático, transiciones con fundido, narrador y diálogos con Don Chuy.

## Flujo
Menú → Nueva partida → intro (mantén E para saltar) → Zona 1 → camioneta → portón sin energía →
caseta (fusibles, bitácora, diagrama) → tablero TSA-01 → portón → fin del capítulo.

## Tablero TSA-01 (rediseño)
1. Medir el fusible principal con el multímetro en la mano [2].
2. Cambiarlo por uno de la caseta [F].
3. Energizar [1]: arrancan 45 s.
4. El recorrido es un cable fijo (tramos rectos y curvas) con 7 nodos redondos que empiezan girados.
   Gira cada nodo con ESPACIO (o clic) hasta llevar la energía del BANCO (arriba a la izquierda)
   al PORTÓN (abajo a la derecha). WASD salta de un nodo a otro.
Si se acaba el tiempo, el fusible se funde: hay que cambiarlo y energizar otra vez (las piezas se quedan como estaban).
Ajustes en `data/puzzle_tsa01.json` (tamaño, semilla, tiempo, número de nodos).

## Pruebas
```
godot --headless -s tests/test_circuito_model.gd
godot --headless res://tests/playthrough.tscn
```
