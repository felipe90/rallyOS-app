# Flow: Staff & Referee Management

Este flujo gestiona la delegación de responsabilidades dentro de un torneo, específicamente la capacidad del Organizador para nombrar Árbitros (Referees) sin requerir que estos atraviesen interfaces complejas de configuración.

## User Intent: **Delegate Control**
El organizador quiere recibir ayuda en la carga de puntajes y validación de partidos, invitando a personas de su confianza u otros jugadores ("Player-as-Referee") a tener permisos elevados solo durante este torneo.

## Flow Pathway

### 1. **Invitation Generation (Organizer View)**
- **Trigger**: `Organizer Dashboard` -> Tab `Staff/Referees`.
- **Action**: Tap en el botón `Invite Referee`.
- **Result**: Generación en el cliente de un enlace único (Magic Link / Deep Link) atado al ID del torneo.
- **Component**: `ShareLinkModal` con opción de copiar al portapapeles o abrir UI nativa de compartir (WhatsApp).

### 2. **Invitation Acceptance (Referee View)**
- **Trigger**: El usuario (futuro referee) abre el enlace en su móvil.
- **State Check**: 
  - Si no está autenticado, pasa por el Auth/Onboarding de RallyOS de manera expedita.
  - Si está autenticado, ve la pantalla de aceptación.
- **Screen**: `Role Acceptance Prompt`.
- **Content**: "[Nombre del Organizador] te está invitando a ser Árbitro en el torneo [Nombre]".
- **Action**: Tap en `Accept Role`.

### 3. **Role Context Switching (Active Referee)**
- **State**: Ahora el usuario es un "Referee" en este torneo, pero sigue siendo un jugador normal en el sistema.
- **Component**: `RoleSwitcherPill` (Badge clickeable en el navbar o cabecera).
- **Interaction**: Si el usuario abre el torneo, puede alternar entre ver como "Player" (feed normal) o "Referee".
- **Result**: Si está en modo "Referee", el `Bracket Canvas` y el `Live Match Tracker` (CU-05) le habilitan botones de edición de `Score` a los cuales normalmente no tendría acceso.

### 4. **Match Assignment (Optional / Ad-hoc)**
- **Action**: Un referee con permisos puede asignarse a un partido libre tocándolo en el Bracket y seleccionando `Take Control`. 
- **Validation**: Si otro referee ya tiene el partido, se le notifica visualmente que está ocupado.

---

## Component Checklist (Top-Down)

- [ ] `RoleSwitcherPill`: Un switch sutil en la cabecera. Oscuro/Teal si está en modo Jugador, vibrante/Amber si está en modo Comando (Referee). 
- [ ] `ShareLinkModal`: Tarjeta inferior limpia con input de solo lectura del enlace y botón gigante de Copiar.
- [ ] `RoleAcceptancePrompt`: Diseño focalizado con botón táctil inmenso de `Accept` y advertencia en letra chica sobre permisos.

## Interaction Design Standards

- **Link over UI**: En lugar de hacer que el organizador busque al usuario en una base de datos para darle permisos, el modelo de envío de Link traslada la fricción a WhatsApp, lo cual es orgánico y rápido para el organizador de cancha.
- **Clear Visual Context**: Cuando el modo "Referee" está activo, la barra superior debe cambiar sutilmente de color (Theme Change) para que el usuario NUNCA olvide que sus toques en la pantalla tienen un efecto destuctivo o autoritativo en la base de datos (vs su experiencia normal de solo lectura).
