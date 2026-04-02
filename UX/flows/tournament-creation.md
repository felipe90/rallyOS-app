# Flow: Tournament Creation

Este flujo permite a un organizador configurar y lanzar un nuevo torneo desde cero.

## User Intent: **Configure Tournament** (CU-01)
El usuario quiere definir deporte, reglas y fees en pasos claros y con feedback visual "premium".

## Flow Pathway

### 1. **Entry Point**
- **Trigger**: Tab `Home` -> Botón `[+] Create Tournament`.
- **Screen**: `Tournament Config Form`.

### 2. **Step 1: Type Selection (Vibe Selection)**
- **Action**: Elegir deporte (Padel, Tennis, Pickleball).
- **Component**: `SportSelectionCard` (Icono + Color branding).

### 3. **Step 2: Rules & ELO Setup**
- **Action**: Toggle `Differential ELO`, `Handicap`.
- **Component**: `GlassFormInput`, `DifferentialELOToggle`.

### 4. **Step 3: Registration Fees**
- **Action**: Ingresar monto (o 0 para gratis).
- **Component**: `FeeInput` (Currency selector).

### 5. **Confirmation & Launch**
- **Trigger**: Botón `Create`.
- **State**: Transición a `DRAFT`.
- **Result**: Redirección automática al `Organizer Dashboard`.

---

## Component Checklist (Top-Down)

- [ ] `GlassForm`: Contenedor base de los inputs.
- [ ] `StepIndicator`: Barra de progreso superior.
- [ ] `DifferentialELOToggle`: Switch estilizado (Primary/Amber).
- [ ] `LaunchConfirmation`: Notificación central táctil.
