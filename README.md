# 🕹️ 5D Multiverse FNAF Engine — Proyecto ADA (UNSA)

[![Roblox Luau](https://img.shields.io/badge/Language-Luau-00A2FF?logo=roblox&logoColor=white)](https://luau.org/)
[![Course](https://img.shields.io/badge/Curso-Análisis_y_Diseño_de_Algoritmos-red)](https://epis.unsa.edu.pe/)
[![University](https://img.shields.io/badge/UNSA-EPIS-blue)](https://www.unsa.edu.pe/)

Motor de simulación y lógica multiversal desarrollado en **Roblox (Luau)**, inspirado en las mecánicas de *5D Chess with Multiverse Time Travel* y ambientado en el universo de *Five Nights at Freddy's (FNAF)*. 

Este proyecto fue concebido para la aplicación práctica de **estructuras de datos avanzadas, algoritmos sobre grafos, sincronización en sistemas distribuidos y búsqueda heurística en espacios multidimensionales**.

---

## 📌 Características Principales y Algoritmos

1. **Relojes Vectoriales y de Lamport (`VectorClock.luau`)**
   - Rastreo de causalidad entre múltiples líneas temporales concurrentes ($L_0, L_1, \dots$) sin depender de un reloj físico global.
   - Evaluación en tiempo constante $O(1)$ y $O(|L|)$ de relaciones causales (*happens-before* $A \to B$ y concurrencia $A \parallel B$).

2. **Árbol de Multiversos DAG (`TimelineTree.luau`)**
   - Grafo acíclico dirigido que modela las ramificaciones en el tiempo generadas por eventos o paradojas temporales.
   - Avance temporal desacoplado y evaluación dinámica de la línea más vulnerable.

3. **Propagación del "Efecto Mariposa" con Kahn (`CausalGraph.luau`)**
   - Algoritmo de **Ordenamiento Topológico de Kahn** para resolver dependencias causales acíclicas.
   - Cuando un evento modifica el pasado (ej. sabotaje de Chica), los efectos energéticos se propagan ordenadamente hacia todas las líneas descendientes.

4. **Búsqueda Heurística $A^*$ Espacio-Temporal (`SpaceTimeAStar.luau`)**
   - Planificación de rutas en 4 dimensiones $(x, y, t, L)$ para los animatrónicos.
   - Asistido por una cola de prioridad basada en un **Min-Heap Binario** y precomputación de distancias mínimas mediante **BFS** en el grafo del restaurante (`MapGraph.luau`).

5. **Snapshots Inmutables con Structural Sharing (`SnapshotManager.luau`)**
   - Registro de deltas incrementales (*Event Sourcing*), reduciendo la complejidad espacial a $O(E)$ en lugar de clonar el estado completo $O(|V| \cdot T \cdot |L|)$.

6. **Integración 2D y 3D en Tiempo Real**
   - **`MultiverseDebugGui`:** Panel de depuración interactivo 2D para inspeccionar el grafo espacial, los estados de energía y el árbol de multiversos.
   - **`Map3DCameraController` & `MAP3D_SYNC_V2`:** Sincronización del estado lógico con los modelos 3D físicos (`AnimatronicModels`) y sistema de cámaras de seguridad 3D (`[C]`, `[Q]`, `[E]`).

---

## 📂 Estructura del Repositorio

```text
├── places/                       # Copias de seguridad completas de Roblox Studio (.rbxl)
│   └── README.md
│
├── assets/                       # Modelos 3D exportados modularmente (.rbxm / .rbxmx)
│   └── README.md
│
├── documents/
│   ├── ExplicacionArchivox.md    # Inventario exhaustivo y documentación línea por línea
│   └── Images/                   # Mapas e íconos de referencia (Maps.jpg, Icons.jpg)
│
├── src/                          # Reflejo 1:1 del DataModel de Roblox Studio
│   ├── Workspace/                # Scripts y objetos dentro de Workspace
│   ├── Lighting/                 # Configuraciones de atmósfera y post-procesado
│   ├── ReplicatedStorage/
│   │   └── Shared/               # Módulos compartidos cliente-servidor (MapGraph, Protocolo, VectorClock)
│   ├── ServerScriptService/
│   │   ├── GameController.server.luau
│   │   └── Modules/
│   │       ├── Core/             # CausalGraph, SnapshotManager, TimelineTree, A*, SimClock, GameSession
│   │       ├── Entities/         # TemporalEntity, MultiversePlayer
│   │       ├── Animatronico.luau # Clase base POO con sync a modelos 3D
│   │       ├── Bonnie.luau       # Poda de candidatos y ruta por Pasillo Izquierdo
│   │       ├── Chica.luau        # Sabotaje causal y ruta por Baños / Pasillo Derecho
│   │       └── Foxy.luau         # Salto interdimensional y sprint
│   ├── ServerStorage/            # Módulos y respaldos del servidor
│   ├── StarterGui/
│   │   └── LobbyGui/             # Interfaz del Lobby y botón de inicio
│   └── StarterPlayer/
│       └── StarterPlayerScripts/ # Scripts de cliente
│           ├── ClientScenarioReplica.client.luau
│           ├── Map3DCameraController.client.luau   # Control de cámaras 3D y puertas
│           └── MultiverseDebugGui.client.luau      # Radar táctico y panel de control 5D
│
└── README.md
```

> [!NOTE]
> Para consultar la descripción detallada de cada clase, funciones, algoritmos y métricas de líneas, revisa el archivo [`documents/ExplicacionArchivox.md`](documents/ExplicacionArchivox.md).

---

## 🎮 Controles en el Juego

| Tecla / Acción | Función |
| :---: | :--- |
| **`[C]`** | Alternar entre vista libre del jugador y modo **Cámaras de Seguridad 3D**. |
| **`← / →`** | Cambiar entre las cámaras de las diferentes habitaciones (`CameraPoints`). |
| **`[Q]`** | Alternar estado de la **Puerta Izquierda** (consume energía al cerrarse). |
| **`[E]`** | Alternar estado de la **Puerta Derecha** (consume energía al cerrarse). |
| **GUI 2D** | Panel de control superior para pausar el tiempo simulado (`SimClock`), avanzar por pasos o inspeccionar líneas temporales. |

---

## 🛠️ Tecnologías y Entorno

* **Plataforma:** Roblox Studio
* **Lenguaje:** Luau (Roblox Luau con tipado estricto `--!strict`)
* **Control de Versiones y Sincronización:** Git + GitHub / Roblox Studio MCP

---

## 👥 Equipo de Desarrollo

* **Universidad Nacional de San Agustín (UNSA)** — Escuela Profesional de Ingeniería de Sistemas (EPIS).
* **Curso:** Análisis y Diseño de Algoritmos (ADA).
