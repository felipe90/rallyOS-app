# Evaluación de Arquitectura y UX: RallyOS (Q2 2026)

**Fecha**: 2 de Abril, 2026
**Nivel de Severidad**: 🔴 Crítico (Análisis Profundo)

Esta es una evaluación brutalmente honesta del estado de RallyOS. Hemos pasado de un MVP de 3 tablas a un "monstruo" empresarial con 40 migraciones que incluyen Round Robin, Pools de Árbitros, y motores ELO determinísticos. 

---

## 1. Complejidad del Sistema y Optimizaciones (Fat DB vs Thin Client)

El sistema adoptó el patrón de **Fat Database** (Toda la lógica de negocio vive en PostgreSQL a través de Triggers y RPCs).

### El Problema (Fat DB)
Tenés 40 migraciones, y archivos como `00000000000040_rr_rpcs.sql` tienen más de 700 líneas de lógica en PL/pgSQL. 
*   **Debuggability**: Rastrear un error cuando se genera un bracket de Round Robin o cuando falla el sistema que auto-asigna al perdedor como árbitro es casi imposible sin usar logs nativos de Postgres.
*   **Escalabilidad Activa**: Postgres está calculando brackets enteros y procesando colas de ELO en tiempo real.

### Optimizaciones Propuestas (Urgent)
1.  **Mover a Edge Functions (Edge Compute)**: La lógica matemática compleja (como `generate_bracket_from_groups` o el cálculo matemático del ELO diferencial) no debería estar en RPCs. Debería estar en **Supabase Edge Functions** (TypeScript). Dejale a Postgres solo lo que hace bien: Integridad Referencial (Foreign Keys) y RLS (Seguridad).
2.  **Consolidación de Migraciones (Squash)**: Tener 40 migraciones secuenciales hace que el CI/CD y el entorno local demoren muchísimo en levantar. Es hora de hacer un "Squash" a una migración base `00000000000001_foundation.sql`.

---

## 2. Seguridad de la App (Vectores de Ataque Activos)

La re-evaluación anterior de seguridad (`SECURITY_RE_EVALUATION.md`) identificó brechas que, al revisar los RPCs actuales, se han agravado:

### Privilege Escalation en RPCs
La mayoría de los nuevos RPCs (ej. para Round Robin) son ejecutados en el lado del servidor y muchas veces asumen permisos globales o corren con `SECURITY DEFINER`. Si un usuario autenticado llama a `create_round_robin_group` pasando el ID de un torneo del cual *no es dueño*, **el sistema lo va a crear igual** porque los RPCs validan el estado del torneo, pero a veces omiten verificar el `auth.uid()` contra `tournament_staff`.
*   **Fix**: Cada RPC debe arrancar con una aserción estricta de propiedad: `IF NOT EXISTS (SELECT 1 FROM tournament_staff WHERE tournament_id = p_tournament_id AND user_id = auth.uid()) THEN RAISE EXCEPTION 'Unauthorized'; END IF;`

### Time-Tampering & Offline Sync
Seguimos basados en `local_updated_at`. Si un celular con la hora de 2028 manda un score y el backend lo acepta como "Last-Write", ese partido queda bloqueado irreversiblemente (inmutable).
*   **Fix**: Validar severamente en Edge Functions el delta de tiempo, forzar timestamps del servidor en la resolución de conflictos.

---

## 3. Idempotencia y Fuentes de Verdad (SSO)

La Base de Datos (Supabase Postgres) es la única y absoluta **Fuente de Verdad (SSO)**. Esto es correcto arquitectónicamente, pero choca violentamente con la realidad del UX:

*   **Idempotencia en Scores**: Actualmente el trigger asume `points_a` y `points_b`. Si la app (por mala señal) manda el request de "Punto 15 para A" dos veces, ¿la base de datos qué hace? 
*   **Falla del Modelo Actual**: Al ser la DB la SSO, obligamos a que el MVP maneje el `Live Scoring` (CU-05) golpeando la base de datos por cada punto. 

### Solución UX/DB
*   **Los puntos individuales (15-0, 30-0) NO deben vivir de forma persistente en Postgres durante el vivo**. Deberían transmitirse por **Supabase Realtime (Broadcast)** de dispositivo a dispositivo. 
*   **Manejo Epímero**: Postgres solo debe recibir requests de "Set Finalizado" o "Match Finalizado". Si guardamos cada _tap_ táctil en Postgres, los triggers van a estrangular el pool de conexiones en un torneo de 50 canchas simultáneas.

---

## 4. Conexión Real: Specs (CU) vs Sistema Implementado

Evaluamos si los documentos en `UX/flows/` y los Use Cases (`openspec/changes/mvp-tournament-flow/usecases/`) conectan con la DB:

### ✅ CU-01: Crear Torneo
**100% Conectado**: El formulario en `UX/flows/tournament-creation.md` encaja directo con el esquema de la tabla `tournaments`, soporta hándicap, ELO diferencial, y estatus.

### ⚠️ CU-04 & CU-07: Bracket Generation y Round Robin
**Sobre-Ingeniería en Base de Datos**: Los RPCs de Round Robin (`00000000000040_rr_rpcs.sql`) soportan auto-asignación de perdedores como árbitros cruzados e incluso "BYE prioritization". 
*   **Veredicto**: El sistema técnico está 5 pasos por delante del UX diseñado. El frontend ni siquiera tiene pantallas diseñadas para estas lógicas complejas. Esto generará "cuellos de botella" donde el backend espera datos que el frontend MVP no puede mandar.

### 🔴 CU-05: Carga de Scores (Live Board) vs Offline Sync
**Desconectado de la Realidad Físoca**: El `live-scoring.md` dice: *"Carga de puntos con latencia cero... Sync de supabase in bg"*.
Sin embargo, las funciones de DB (Triggers de validación de puntuación de la migración `00000000000032_add_score_validation_trigger.sql`) tienen más de 300 líneas validando si es un Tie-Break, o un Golden Point.
*   **Veredicto**: Al delegar la validación al trigger de Postgres, es IMPOSIBLE que la UI tenga "Zero-Latency" porque no puede confirmar el estado "Optimistic" sin que el trigger lo autorice de forma asíncrona. Si el usuario aprieta rápido y el trigger rechaza por red, el estado optimista del celular y el estado de Postgres se van a romper (State Discrepancy).

---

## 5. Recomendación Ejecutiva

Esta aplicación no puede ser lanzada con los triggers controlando la validación en tiempo real. Mi plan es:

1.  **Detener temporalmente el código de Postgres (Ya está muy sólido)**.
2.  Desacoplar la validación de los Puntos. **El teléfono manda**. El sistema central debe ser un Registro (Ledger) y usar Edge Functions para reconciliar asincrónicamente el torneo, no sincrónicamente cada raquetazo.
3.  Desarrollar la capa cliente en base a la filosofía de **Local-First (WatermelonDB o Expo SQLite)**, porque si dependemos del SDK de Supabase para cada punto, en un club cerrado de Padel el sistema falla.
