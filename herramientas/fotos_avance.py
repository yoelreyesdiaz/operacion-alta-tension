"""Arma la carpeta de capturas de avance del día SOLO con capturas reales:
fotogramas tal cual los muestra la ventana del juego (1278x720) y capturas del
editor de Godot con el código abierto. Escribe AVANCES.txt con la descripción.
Uso: python3 tools/fotos_avance.py"""
import os
import shutil
from PIL import Image

BASE = os.path.join(os.path.dirname(__file__), "..")
DIA = os.path.join(BASE, "avances", "2026-10-22")
CRUDAS = os.path.join(DIA, "_capturas_crudas")
SCR = os.path.join(BASE, "avances", "_tmp")  # carpeta donde se dejan las capturas nuevas antes de ordenarlas

# Sólo el tablero de nodos. (carpeta, archivo, nombre, tipo, título, descripción)
LISTA = [
    ("tablero_v1_original", "09_puzzle_vivo.png", "antes_tablero_original", "ANTES", "Tablero original",
     "Puzzle anterior: rejilla completa de 7x7 nodos cuadrados con interruptor y verificación."),
    ("tablero_v1_original", "12_puzzle_resuelto.png", "antes_tablero_resuelto", "ANTES", "Tablero original resuelto",
     "Había que conectar TODOS los nodos de la red."),
    ("tablero_v2_cuadrado", "03_tablero_paso1.png", "iteracion1_paso1", "REDISEÑO · iteración 1", "Nueva lógica, estilo anterior",
     "Primer rediseño: pasos medir → cambiar → energizar con timer; banco al centro y meta a la derecha."),
    ("tablero_v2_cuadrado", "05_tablero_energizado.png", "iteracion1_energizado", "REDISEÑO · iteración 1", "Iteración 1 energizada",
     "Arranca el temporizador y se giran los nodos."),
    ("tablero_v2_cuadrado", "08_tablero_meta.png", "iteracion1_meta", "REDISEÑO · iteración 1", "Iteración 1 resuelta",
     "La energía llega a la meta del portón."),
    ("tablero_v3_49nodos", "03_tablero_paso1.png", "iteracion2_paso1", "REDISEÑO · iteración 2", "Estilo de la referencia",
     "Nodos redondos tipo PVC, banco arriba a la izquierda y portón abajo a la derecha."),
    ("tablero_v3_49nodos", "05_tablero_energizado.png", "iteracion2_energizado", "REDISEÑO · iteración 2", "49 nodos: se satura",
     "Con la rejilla llena de nodos era fácil perderse."),
    ("tablero_v4_final", "05_tablero_energizado.png", "iteracion3_energizado", "REDISEÑO · iteración 3", "Sólo el recorrido",
     "Se quitaron los nodos de relleno, pero seguía habiendo un nodo en cada casilla."),
    ("tablero_v4_final", "08_tablero_meta.png", "iteracion3_meta", "REDISEÑO · iteración 3", "Iteración 3 resuelta",
     "Recorrido completo con piezas fijas cuadradas."),
    ("tablero_v5_final", "08_tablero_paso1.png", "final_paso1_medir", "REDISEÑO · final", "Versión final: paso 1",
     "Cable fijo con tramos rectos y curvas, y sólo 7 nodos giratorios. Primero se mide el fusible."),
    ("tablero_v5_final", "09_tablero_medido.png", "final_paso2_fusible", "FUNCIONALIDAD", "Paso 2: fusible abierto",
     "El multímetro marca ∞ Ω; se habilita cambiar el fusible."),
    ("tablero_v5_final", "10_tablero_energizado.png", "final_paso3_energizado", "FUNCIONALIDAD", "Paso 3: energizado",
     "Corre el tiempo. Todos los nodos empiezan girados (en rojo): la energía no pasa."),
    ("tablero_v5_final", "11_tablero_disparo.png", "final_disparo", "FUNCIONALIDAD", "Se acabó el tiempo",
     "Disparo de protección: se funde el fusible y baja un intento."),
    ('tablero_v5_final', '12_tablero_nodo_1.png', 'final_nodo_1_alineado', 'FUNCIONALIDAD', 'Nodo 1 de 7 alineado', 'Se giró el nodo 1 con ESPACIO; la energía avanza un tramo más por el cable.'),
    ('tablero_v5_final', '13_tablero_nodo_2.png', 'final_nodo_2_alineado', 'FUNCIONALIDAD', 'Nodo 2 de 7 alineado', 'Se giró el nodo 2 con ESPACIO; la energía avanza un tramo más por el cable.'),
    ('tablero_v5_final', '14_tablero_nodo_3.png', 'final_nodo_3_alineado', 'FUNCIONALIDAD', 'Nodo 3 de 7 alineado', 'Se giró el nodo 3 con ESPACIO; la energía avanza un tramo más por el cable.'),
    ('tablero_v5_final', '15_tablero_nodo_4.png', 'final_nodo_4_alineado', 'FUNCIONALIDAD', 'Nodo 4 de 7 alineado', 'Se giró el nodo 4 con ESPACIO; la energía avanza un tramo más por el cable.'),
    ('tablero_v5_final', '16_tablero_nodo_5.png', 'final_nodo_5_alineado', 'FUNCIONALIDAD', 'Nodo 5 de 7 alineado', 'Se giró el nodo 5 con ESPACIO; la energía avanza un tramo más por el cable.'),
    ('tablero_v5_final', '17_tablero_nodo_6.png', 'final_nodo_6_alineado', 'FUNCIONALIDAD', 'Nodo 6 de 7 alineado', 'Se giró el nodo 6 con ESPACIO; la energía avanza un tramo más por el cable.'),
    ('tablero_v5_final', '18_tablero_nodo_7.png', 'final_nodo_7_alineado', 'FUNCIONALIDAD', 'Nodo 7 de 7 alineado', 'Se giró el nodo 7 con ESPACIO; la energía avanza un tramo más por el cable.'),
    ("tablero_v5_final", "19_tablero_meta.png", "final_circuito_completo", "FUNCIONALIDAD", "Circuito completo",
     "La energía llega al portón: ABIERTO y avance 100%."),
    ("editor", "codigo_modelo_reglas.png", "codigo_modelo_reglas", "CÓDIGO", "Modelo del tablero",
     "Editor de Godot: CircuitoModel con pasos, estados y resultados."),
    ("editor", "codigo_modelo_recorrido.png", "codigo_recorrido", "CÓDIGO", "Generación del recorrido",
     "Editor de Godot: camino del banco al portón con semilla fija."),
    ("editor", "codigo_modelo_nodos_girados.png", "codigo_nodos_girados", "CÓDIGO", "Nodos que empiezan girados",
     "Editor de Godot: el camino es cable fijo y los 7 nodos se giran para cortar la energía."),
    ("editor", "codigo_modelo_pasos.png", "codigo_pasos", "CÓDIGO", "Medir, cambiar y energizar",
     "Editor de Godot: reglas de cada paso antes de poder girar."),
    ("editor", "codigo_modelo_timer.png", "codigo_timer", "CÓDIGO", "Temporizador y disparo",
     "Editor de Godot: se resuelve al llegar a la meta o dispara al acabarse el tiempo."),
    ("editor", "codigo_tablero_controles.png", "codigo_controles", "CÓDIGO", "Controles del tablero",
     "Editor de Godot: ESPACIO gira, 2 mide, F cambia fusible, 1 energiza."),
    ("editor", "codigo_tablero_cursor_nodos.png", "codigo_cursor", "CÓDIGO", "Cursor de nodo en nodo",
     "Editor de Godot: WASD salta al nodo más cercano."),
    ("editor", "codigo_tablero_cable_curvas.png", "codigo_cable_curvas", "CÓDIGO", "Cable con curvas",
     "Editor de Godot: tramos rectos y curvas en arco con pulsos de energía."),
    ("editor", "codigo_tablero_nodo_pvc.png", "codigo_nodo_pvc", "CÓDIGO", "Nodo redondo tipo PVC",
     "Editor de Godot: carcasa redonda, LED rojo/azul y pieza de tubo."),
]


def main():
    for f in os.listdir(DIA):
        if f.endswith(".png") or f == "AVANCES.txt":
            os.remove(os.path.join(DIA, f))
    for nombre, src in (("tablero_v5_final", os.path.join(SCR, "v5")), ("editor", os.path.join(SCR, "editor"))):
        dst = os.path.join(CRUDAS, nombre)
        if os.path.isdir(dst):
            shutil.rmtree(dst)
        shutil.copytree(src, dst, ignore=shutil.ignore_patterns("*.log", "prev.png"))
    filas = []
    for n, (carpeta, archivo, nombre, tipo, titulo, desc) in enumerate(LISTA, 1):
        im = Image.open(os.path.join(CRUDAS, carpeta, archivo)).convert("RGB")
        if im.width == 426:  # fotograma del juego: se muestra x3 en la ventana
            im = im.resize((1278, 720), Image.NEAREST)
        salida = f"{n:02d}_{nombre}.png"
        im.save(os.path.join(DIA, salida))
        filas.append((salida, tipo, titulo, desc))
    with open(os.path.join(DIA, "AVANCES.txt"), "w", encoding="utf-8") as f:
        f.write("OPERACIÓN ALTA TENSIÓN — TABLERO DE NODOS TSA-01 · CAPTURAS DE AVANCE · 22-OCT-2026\n")
        f.write("=" * 66 + "\n\n")
        f.write("Todas son capturas reales: fotogramas del juego tal como se ven en la ventana (1278x720)\n"
                "y capturas del editor de Godot con el código abierto.\n\n")
        f.write("Rediseño del tablero de nodos TSA-01 (3 iteraciones + versión final):\n"
                "  medir fusible → cambiarlo → energizar (timer de 45 s) → girar 7 nodos con ESPACIO\n"
                "  para llevar la energía del banco al portón por un cable con tramos rectos y curvas.\n\n")
        f.write("Tipos: ANTES · REDISEÑO · FUNCIONALIDAD · CÓDIGO\n\n")
        for salida, tipo, titulo, desc in filas:
            f.write(f"{salida}\n  [{tipo}] {titulo}\n  {desc}\n\n")
    print(len(filas), "capturas")


main()
