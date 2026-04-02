# RallyOS Strategy: Phase A (The Weekend Blitz)
**Market Focus:** Bogotá, Colombia (Table Tennis & Padel Clubs)
**Status:** MVP Operational Definition | **Strategy:** Admin-Centric / Concierge Model

## 1. Visión de Negocio (Etapa A)
La Fase A se enfoca en **confrontaciones de fin de semana** en clubes privados. El objetivo es validar la usabilidad del marcador (Scoreboard) y el sistema de ELO en un entorno controlado de baja burocracia y alta recurrencia.

### Propuesta de Valor (MVP):
- **Para el Organizador:** Reducción del 80% en carga administrativa (pagos y cuadros).
- **Para el Jugador:** Integridad competitiva (ELO real) y estatus social (Shareable cards).

## 2. Pipeline Operativo (Flujo de 3 Etapas)

RallyOS v1.0 delega el control total al **Admin del Torneo** para asegurar la calidad de la data y reducir la fricción de entrada de los jugadores.

| Etapa | Acción del Admin | Estado del Entry | Lógica de Negocio |
| :--- | :--- | :--- | :--- |
| **1. Inscripción** | Carga manual o búsqueda en DB. | `REGISTERED` | El Admin actúa como promotor y "dueño" del registro. |
| **2. Confirmación** | Valida pago (Manual / Nequi). | `CONFIRMED` | El sistema solicita número de guía/referencia de Nequi. |
| **3. Asistencia** | Check-in físico en el club. | `CHECKED_IN` | Solo los presentes entran al sorteo de llaves (Brackets). |

## 3. Integración de Pagos (Local Context)
- **Método Primario:** Nequi (Manual).
- **Flujo:** El jugador transfiere al Nequi del club -> Muestra comprobante -> El Admin valida en la App -> La App registra `payment_confirmed_at`.
- **Finalidad:** Evitar el fraude de "pantallazos editados" mediante el registro de hora y referencia única.

## 4. Identidad Visual & Vibe (Antigravity Input)
El diseño debe seguir el manifiesto **"High-Tech Clubhouse"**:
- **Keywords:** `Competitive Integrity`, `Social Connection`, `Zero-Latency`, `Offline-First`.
- **UI Vibes:** Bordes muy redondeados (24px+), Glassmorphism, feedback táctil (haptics) al marcar puntos.
- **Colores (Stitch Tokens):**
    - `Primary (#14B8A6)` - Teal: Tecnología y precisión.
    - `Secondary (#A7F3D0)` - Menta: Comunidad y relajación.
    - `Tertiary (#F59E0B)` - Ámbar: Interacción social y victoria.

## 5. User Stories Críticas para el MVP
1. **Admin/Organizer:** "Como organizador, quiero registrar 20 jugadores en <10 minutos usando solo sus nombres y apodos."
2. **Admin/Referee:** "Como árbitro, quiero marcar puntos en modo offline y que se sincronicen cuando el Wi-Fi del club vuelva."
3. **Player:** "Como ganador, quiero recibir un link a mi 'Victory Card' con mi nuevo ELO para compartirlo en mis historias de Instagram."

## 6. Tech Stack Reference
- **Frontend:** React Native + Expo + NativeWind.
- **Backend:** Supabase (PostgreSQL 3NF + RLS).
- **Local Store:** SQLite (para persistencia offline del marcador).