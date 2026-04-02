# Flow: Organizer Admin Desktop Dashboard

Este flujo define la experiencia de gestión pesada para el organizador de torneos desde una PC/Laptop. Aprovechamos el ancho de pantalla para maximizar la productividad y visibilidad.

## User Intent: **Command & Control** (Admin)
El organizador quiere ver el estado global del torneo, gestionar múltiples inscripciones de un vistazo y realizar ediciones masivas sin navegar entre 20 sub-pantallas.

## Desktop Layout: 3-Zone Architecture

### 1. **Sidebar Navigation** (Left - 240px fixed)
- **Content**: Logo, Tournament Selector, Navigation Tabs (Inscriptions, Brackets, Scores, Finance, Settings).
- **Vibe**: High-Tech Clubhouse / Minimalist Slate.

### 2. **Main High-Density Grid** (Center - Flexible)
- **Component**: `AdminDataGrid`.
- **Action**: Infinite scroll or fast pagination. 
- **Density**: Tablas con 8-10 columnas (Nombre, ELO, Categoría, Fee Status, Check-in Status, Action).
- **Interactions**: Filtros dinámicos en los headers, sorting y búsqueda global superior.

### 3. **Quick Action Panel** (Right - 320px sidebar)
- **Trigger**: Aparece al seleccionar una o más filas en el Grid.
- **Action**: Botones de `Check-in All`, `Edit Group`, `Send Notification`.
- **Component**: `ContextualActionCard` (Glassmorphism con fondo acentuado).

---

## Flow Pathway (Specific Tasks)

### 1. **Bulk Inscription Management**
- **Action**: Seleccionar 10 jugadores -> Tap `Mark Paid` en el Action Panel.
- **Feedback**: Barra de progreso de Sync con Supabase (Background).

### 2. **Bracket Drag & Drop**
- **Action**: Reordenar cabezas de serie arrastrando nodos en el Canvas de Bracket.
- **Vibe**: Suave, con guías visuales en color Teal.

### 3. **Live TV Toggle**
- **Action**: Botón `[Go Live / TV View]` en el header.
- **Trigger**: Abre una nueva pestaña con la URL pública `/display/:tournament_id`.

---

## Technical Constraints (MVP)

- **Stack**: React Native Web (Expo) + NativeWind.
- **Responsive**: Este layout solo se activa en `viewports > 1024px`.
- **Performance**: Usar `FlashList` u optimizar el renderizado de filas para evitar lag en tablas de 100+ jugadores.
