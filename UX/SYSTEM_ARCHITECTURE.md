# RallyOS Architecture Proposal (Q2 2026)

Basado en el acoplamiento profundo (y ahora celebrado) con Supabase y tu requisito explícito de tener una experiencia **Offline-First (Latencia Cero) para el Scorerecard**, esta es la arquitectura definitiva que deberías implementar. 

He descartado pilas tradicionales (Node.js/Express) porque agregarían latencia, costos y duplicarían código de seguridad (PostgREST RLS ya lo maneja).

## 1. Topología del Sistema (C4 Container Diagram)

```mermaid
C4Context
    title RallyOS B2B SaaS Architecture (Current Stack)

    Person(player, "Jugador / Referee", "Registra puntos offline o con mala señal en la cancha.")
    Person(organizer, "Organizador", "Gestiona brackets, inscripciones y sedes corporativas.")

    System_Boundary(frontend, "RallyOS Client App (Expo / React Native)") {
        Container(ui, "UI & State", "React Native, Expo Router, Zustand", "Vistas y flujos guiados.")
        ContainerDb(localDb, "Local SQLite (PowerSync/Watermelon)", "SQLite", "Fuente de verdad local. Latencia Cero.")
    }

    System_Boundary(supabase_cloud, "Supabase Cloud Ecosystem") {
        Container(postgrest, "PostgREST API", "HTTP/REST", "Capa auto-generada sobre Postgres. Segura vía RLS.")
        Container(realtime, "Supabase Realtime", "WebSockets", "Broadcast P2P para marcadores en vivo (espectadores).")
        Container(edge_functions, "Edge Functions", "Deno, TS", "Lógica pesada: Pagos Stripe, Notificaciones Push, Emparejamiento Semifinales.")
        ContainerDb(pg_database, "PostgreSQL", "SQL, RLS", "Fuente de verdad en la nube. Guarda torneo y estadísticas.")
    }
    
    System_Ext(powersync_cloud, "PowerSync Cloud", "Sincronizador bi-direccional Postgres <-> SQLite.")
    System_Ext(stripe, "Stripe", "Pasarela B2B pagos.")

    Rel(player, ui, "Toca el tablero de puntos", "Touch")
    Rel(organizer, ui, "Crea y maneja torneos", "Touch/Web")
    
    Rel(ui, localDb, "Escribe y lee puntos instantáneos", "SQLite Sync")
    Rel(localDb, powersync_cloud, "Sincroniza background cuando hay internet", "HTTP/WSS")
    Rel(powersync_cloud, pg_database, "Upserts seguros hacia Postgres", "SQL")
    
    Rel(ui, postgrest, "Llamadas mutaciones directas (Crear Torneo)", "HTTP")
    Rel(ui, realtime, "Emite canal de Broadcast", "WSS")
    Rel(ui, edge_functions, "Llama proceso de Checkout", "HTTP")
    
    Rel(edge_functions, stripe, "Procesa Checkout", "HTTP")
```

---

## 2. Definición del Stack Tecnológico

### Capa Frontend (Client-Side)
-   **Framework:** `Expo` (React Native). Permite exportar a Web, iOS y Android con una sola base de código (Expo Router para la navegación universal).
-   **Local Database & Sync (El corazón Offline-First):** `PowerSync` (o alternativamente `WatermelonDB`). 
    -   *¿Por qué?* Mencionaste que necesitamos *Latencia Cero* y que *desactivamos los triggers del DB para hacer el score optimista*. Con PowerSync + Supabase, tú haces un `INSERT` en la BD local de SQLite del teléfono en 1 milisegundo. La app avanza. Cuando vuelve el 4G, PowerSync envía el batch a Postgres de forma silenciosa.
-   **State Management:** `Zustand` (UI state rápido) combinado con Queries directos al Local SQLite.
-   **Styling:** `NativeWind` o `Tamagui` (Recomiendo usar tokens muy firmes para no romper el layout).

### Capa Backend (Supabase)
Aquí aplicamos el patrón **BaaS (Backend as a Service)** Thin-Client. Significa: "Menos código en el medio, mejor".
-   **API Core:** `@supabase/supabase-js`. Lee y escribe directamente a las tablas. La seguridad la garantiza el RLS y los JWT, no controladores intermedios.
-   **Lógica de Negocios Pesada (Microservicios):** `Supabase Edge Functions` (Deno). ¿Dónde pones esto?
    1.  Procesamiento de pagos (Stripe Webhooks).
    2.  Envío de notificaciones (Expo Push Notifications).
    3.  Lógica de torneos muy pesada: Ejemplo, cerrar Fase de Grupos y disparar la creación de llaves (Brackets) de eliminatoria.
-   **Live Score (Transmisión a espectadores):** `Supabase Realtime (Broadcast)`. En vez de grabar cada "15-0" en la BD (lo cual colgaría la red), el dispositivo emite un suceso efímero por WebSocket a los teléfonos de la grada. Solo graba en la BD local de SQLite (y sincroniza a Postgres) cuando termina el *Juego* o el *Set*.

---

## 3. ¿Por qué NO usar un Backend Tradicional (Node/NestJS)?

Podrías estar tentado a poner un NestJS, Express o Go Lang entre el celular y Supabase. **¡NO lo hagas!**
1.  **Duplicación Inútil**: Vas a tener que re-escribir la autenticación y el Row Level Security en controladores HTTP.
2.  **Anti-Offline**: Un backend REST tradicional te obliga a tener buena conexión a internet para avanzar la UI. Si usas directamente el túnel Supabase->PowerSync->App, rompes esa atadura.
3.  **Cuello de botella de Startups**: Agregar un repo de Backend y un servidor requiere mantener 2 pipelines, configurar Docker, Swagger y balanceadores de carga. Mantener la lógica en **Edge Functions** (Deno TS) bajo el ecosistema Supabase reduce drásticamente tu TCO (Total Cost of Ownership).

## Veredicto de Implementación
Empieza inicializando un monolito frontend en **Expo**. Implementa `@supabase/supabase-js` para loguear y `PowerSync` (Local SQLite) para la tabla Score. Resto de mutaciones via PostgREST estándar.
