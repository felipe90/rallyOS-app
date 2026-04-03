# Flow: Match Scheduling & Notifications

Este flujo gestiona la logística crítica "Dónde y Cuándo" para los jugadores durante un torneo activo. Cero ruido, 100% utilidad práctica.

## User Intent: **Tournament Logistics**
El usuario (jugador) necesita saber exactamente en qué cancha juega, a qué hora y contra quién, sin tener que navegar profundamente en la app. El organizador necesita asignar recursos (canchas y horarios) rápidamente.

## Flow Pathway

### 1. **Organizer Assignment (Admin View)**
- **Trigger**: Match generado por el sistema de Brackets y estado = `PENDING`.
- **Action**: Tap en el Match -> Selección de `Court` (Cancha) y `Time` (Horario).
- **Component**: `CourtSelectorModal` listando canchas disponibles y ocupadas.
- **Result**: Match pasa a estado `SCHEDULED`. Sistema emite notificación.

### 2. **Player Notification (Direct Information)**
- **Trigger**: Match actualizado a `SCHEDULED`.
- **Action**: Disparo de Push Notification y UI Banner interno.
- **Content Policy (No Fluff)**:
  - Formato estricto: `[Tu Equipo] vs [Oponente]`
  - Detalles obligatorios: `Cancha [X] - [Hora]`
  - Ejemplo: `Tapia/Coello vs. Lebron/Galan | Cancha 1 | 18:30`

### 3. **The "Up Next" Card (Player Home View)**
- **Trigger**: Jugador entra al Tab `Play` o `Home` teniendo un match en estado `SCHEDULED` en el corto plazo (próximas 2hs).
- **Component**: `UpNextCard` fijada en el tope de la pantalla.
- **Data**:
  - Reloj de cuenta regresiva (ej. `Starts in 15m`).
  - Botón de acción rápida: `Mark as Ready / Check-In` (que retroalimenta la vista del organizador).
  - Info obligatoria de dónde ir.

### 4. **Calling to Court (Court-side Display)**
- **Trigger**: Organizador o Referee marca el match como `WARMUP`.
- **Result**: La pantalla pública (TV) resalta el partido asignado y parpadea un indicador en el app del jugador.

---

## Component Checklist (Top-Down)

- [ ] `CourtSelectorModal`: Lista rápida de radio buttons para elegir número de cancha.
- [ ] `UpNextCard`: Tarjeta de ultra-alta prioridad. Fondo con borde `border-tertiary` (Amber) grueso si falta poco tiempo.
- [ ] `CountdownTimer`: Componente de texto dinámico que descuenta minutos, pasando de texto gris a naranja ambarino cuando quedan menos de 10 minutos.
- [ ] `NotificationPayloadDef`: Esquema estricto de JSON para la Payload de Push Notifications, evitando textos largos de relleno.

## Interaction Design Standards

- **Brevity**: Las notificaciones no deben truncarse en pantallas pequeñas (iPhones antiguos, Apple Watches).
- **Urgency vs Panic**: El color ámbar (`bg-amber-500/20`) se usa para cercanía del partido, pero sin intermitencias molestas que induzcan pánico. Solo debe usarse pulso/vibración si el partido ya está "Vencido" en horario y los jugadores no han marcado presencia.
