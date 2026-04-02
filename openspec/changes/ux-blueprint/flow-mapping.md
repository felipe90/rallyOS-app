# Flow Mapping: Use Cases to Screens

Este documento detalla cómo cada **Caso de Uso (CU)** se manifiesta en la interfaz de la aplicación RallyOS.

## Tournament Life Cycle (The Organizer Journey)

### **CU-01: Organizador Crea Torneo**
1.  **Home Screen** → Botón `+ Create`.
2.  **Tournament Creation Form**: (Input step 1-3).
3.  **Confirmation Overlay**: Muestra el ID generado.
4.  **Action**: Redirección al `Organizer Dashboard`.

### **CU-03: Asistencia y Check-in**
1.  **Organizer Dashboard** → Tab `Attendance`.
2.  **Attendance/Check-in Screen**: Listado de jugadores registrados.
3.  **Interaction**: Toggle `Switch` para marcar "Checked In".
4.  **State**: Cambio visual en el badge del jugador.

### **CU-04: Generación de Bracket**
1.  **Organizer Dashboard** → Tab `Bracket`.
2.  **Action**: Botón `Generate Bracket` (Solo si Attendance >= Min).
3.  **Wait State**: Lottie animation / Glassmorphism loader.
4.  **Result**: Redirección al `Bracket Canvas`.

### **CU-08: Cierre del Torneo**
1.  **Organizer Dashboard** → Botón `Finalize Tournament`.
2.  **Verification Modal**: Confirmar que todos los matches están cerrados.
3.  **Action**: Triggering `process_closure()`.
4.  **Result**: Pantalla de `Podium / Rewards`.

---

## Competitive Integrity (The Player Journey)

### **CU-02: Registro al Torneo**
1.  **Discovery Screen** → Card de Torneo.
2.  **Tournament Detail**: Información y "Fee Summary".
3.  **Interaction**: Botón `Register`.
4.  **Result**: `Registration Modal` → Redirección al `Feed`.

### **CU-05: Carga de Scores (Live)**
1.  **Tab "Play"** → Listado de "My Active Matches".
2.  **Match Detail / Live Scoreboard**: Interfaz táctil de gran formato.
3.  **Interaction**: `Tap +1` / `Gestos`.
4.  **Result**: Optimistic UI update → `Supabase` sync in bg.

### **CU-06 / CU-07: Evolución y Bracket**
1.  **Match Finished Overlay**: Muestra cálculo de ELO temporal.
2.  **Action**: Notificación push o `Feed` update.
3.  **Bracket Canvas**: Visualización del ganador avanzando de nodo.

### **CU-09 / CU-10: Perfil y Comunidad**
1.  **Tab "Home"**: (CU-10) Feed de actividad global.
2.  **Tab "Profile"**: (CU-09) Dashboard de estadísticas y ELO personal.
3.  **Interaction**: `Share Match` → Generación de `Share Card`.
