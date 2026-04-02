# RallyOS Architectural Evaluation: Vendor Lock-in (Supabase)

Esta es una evaluación profunda de la arquitectura actual (Q2 2026) respecto al grado de acoplamiento (*Vendor Lock-in*) con Supabase y las implicaciones de migrar la base de datos a un PostgreSQL genérico (AWS RDS, Google Cloud SQL, On-Premise, etc.).

## 1. Nivel de Acoplamiento Actual: ALTO 🔴

Al inspeccionar el nuevo archivo fundacional `00000000000001_foundation.sql`, descubrimos que RallyOS no es una base de datos "PostgreSQL plana". Está *muy acoplada* al ecosistema de **Supabase / PostgREST**.

### Ejes de Dependencia Supabase

1. **Dependencia de la Función `auth.uid()`**:
   *   Hay **más de 20 invocaciones directas** a `auth.uid()` dentro del código fuente de tus Stored Procedures (RPCs).
   *   Ejemplos críticos: `create_round_robin_group`, `assign_staff`, `process_match_completion`. Todas tus lógicas de autorización usan `auth.uid()` para saber quién está ejecutando el código.
   *   *Consecuencia de Migración*: Si te vas de Supabase, tus RPCs reventarán con `function auth.uid() does not exist`.

2. **Esquema `auth` (GoTrue / Supabase Auth)**:
   *   Tu tabla de `persons` no implementa autenticación directa, sino que depende de que exista un registro paralelo en la tabla `auth.users` administrada por Supabase (una dependencia de foreign/logical key, explícita en los Seeds).
   *   *Consecuencia de Migración*: Emigrar implica construir desde cero tu propio Identity Provider (IdP) o instalar un servicio tipo Auth0, Firebase Auth o Keycloak, y escribir lógica para mantener ambas tablas sincronizadas.

3. **Row Level Security (RLS) dependiente del JWT**:
   *   Supabase inyecta los claims del JWT (token) directamente en el contexto transaccional en cada Request. Tu RLS funciona sin código de intermediación porque Supabase "hace la magia".
   *   *Consecuencia de Migración*: Si construyes un backend tradicional en Node.js, Spring Boot, o Go, tu ORM conectará a la base con un solo usuario administrador (Ej: `postgres`). Al hacer esto, **todo el RLS de Postgres se vuelve inútil** (porque el ORM pasa por encima de las políticas de fila a nivel de BD, ya que no se loguea como el cliente móvil).

4. **Realtime y Edge Functions (Próxima fase)**:
   *   Tu plan de desactivar validaciones en vivo para pasar a **Offline-First** nos empujará a usar Supabase Realtime Channels (Broadcast). Si confías en esa red P2P de Supabase, no podrás migrar sin refactorizar a WebSockets genéricos (como Socket.io o equivalentes).

## 2. ¿Es esto algo malo?

**Respuesta de Arquitecto Senior**: No. **El acoplamiento no es inherentemente malo si el costo de abstracción supera el costo de oportunidad.**

Intentar desacoplar el sistema hoy para que sea "Cloud-Agnostic" te forzaría a:
- Crear una capa de API Intermedia enorme en Node.js para replicar RLS.
- Montar tu propio sistema de Autenticación.
- Duplicar validaciones en el Backend.
- Gastar meses de ingeniería a cambio de nada comprobable por el usuario.

Supabase construyó su SaaS precisamente usando estándares abiertos (PostgREST, GoTrue, PostgreSQL). Estás atado, pero **estás atado a herramientas Open Source**.

## 3. Plan de Contingencia: ¿Cómo migrar si Supabase quiebra o sube precios?

Si el día de mañana se ven obligados a salir de Supabase (Migrar a AWS RDS, por ejemplo), no perderán la base ni el esquema, pero tendrán que reescribir la "capa pegamento". Este sería el mapa de ruta:

### Fase A: El Reemplazo de Auth
En PostgreSQL genérico, crearán una función que emule a Supabase:
```sql
CREATE SCHEMA IF NOT EXISTS auth;
CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid AS $$
  -- En un entorno con PostgREST o GraphQL generico, lees el claim local:
  SELECT current_setting('request.jwt.claim.sub', true)::uuid;
$$ LANGUAGE SQL;
```
Con ese parche mágico de 4 líneas, **los 20+ RPCs que tenemos hoy volverían a funcionar inmediatamente**.

### Fase B: Backend Múltiple (Si pierden PostgREST)
Si además de salir de Supabase no instalan PostgREST, y arman un backend con Prisma/TypeORM, cada request que llame a la Base de Datos tendrá que inyectar el ID de usuario manualmente al iniciar la transacción para que el RLS lo escuche:
```typescript
// Backend tradicional Node.js/Go (PostgreSQL generico)
await db.$executeRaw`SET LOCAL "request.jwt.claim.sub" = ${userTokenId};`;
// A partir de aqui corren los querys y el RLS sigue funcionando nativamente.
```

## Veredicto 🧠

1. **Estado**: RallyOS tiene un acoplamiento profundo con la API nativa de Supabase, no a nivel de sintaxis SQL (que es PostgreSQL estándar, sólido como un tanque), sino a nivel de **Identidad (Auth)** y **Contexto de Peticiones HTTP->SQL**.
2. **Recomendación**: **Aceptá el acoplamiento.** Estás en la etapa de producto para MVP hasta Series A. Jugar al Arquitecto Cloud-Agnostic ("Over-engineering") y construir capas de abstracción para protegerte de "proveedores en el futuro" solo matará tu velocidad de iteración y te dejará sin presupuesto hoy. **Exprimí Supabase hasta la última gota.**
3. **Respaldo**: Al estar montado sobre PostgreSQL plano y en ecosistema Open Source, la Base de Datos siempre será tuya y su lógica de negocio de torneo (Brackets, Puntos, Round Robin) no se pierde. Todo puede ser salvado con pequeños parches como emular el `auth.uid()`.

NO dediques un solo Story Point del ciclo actual a desacoplarte de Supabase. Seguí adelante construyendo pantallas.
