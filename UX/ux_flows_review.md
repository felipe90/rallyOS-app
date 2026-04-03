# UX Expert Review: RallyOS Flows (Q2 2026)

**Auditor**: Antigravity (Senior Architect & UX Expert)
**Vibe Check**: 🟢 High-Tech Clubhouse (Modern, Translucent, Tactile)
**Structural Integrity**: 🟡 Warning (Sync & Architecture Disconnect)

---

## 1. Global Observations

### 🔴 The "Sync Paradox"
Todos los flujos (`CU-03`, `CU-05`, `CU-04`) mencionan **Optimistic Updates**. 
> [!CAUTION]
> **CRITICAL GAP**: El reporte de arquitectura Q2 indica que la lógica de negocio vive en Triggers de Postgres sincronizados. Si el trigger falla (ej. por validación de reglas de Padel), la UI "optimista" ya le mintió al usuario.
> **Solución UX**: Implementar indicadores de "Ghost State" (Score en color tenue hasta que el servidor confirme) o mover la validación al cliente (Local-first).

### 🟢 Aesthetic Consistency
El uso de **Glassmorphism**, **Teal/Amber/Slate** y **Haptic Feedback** es coherente en todos los documentos. El sistema se siente "Premium".

---

## 2. Flow-by-Flow Deep Dive

### 🎾 Live Scoring (`CU-05`)
- **Fortaleza**: Los `MassiveTapTargets` son perfectos para el uso "sin mirar" en cancha.
- **Debilidad**: El botón de `Undo` es vital. Si el usuario hace un "fat finger" en un punto de campeonato, el estrés es total. El `Undo` debería tener un gesto físico dedicado (shake o long press en el área contraria).

### 🏆 Bracket Management (`CU-04`)
- **Fortaleza**: El "Amber Glow" para el avance de ganadores es una micro-interacción excelente.
- **Debilidad**: **Escalabilidad Visual**. Un canvas con zoom es difícil de usar en mobile para torneos grandes. 
- **Sugerencia**: Agregar una vista de "Listado de Cruces" (Linear View) como alternativa al "Canvas View" para usuarios que prefieren eficiencia sobre estética.

### 📋 Attendance & Check-in (`CU-03`)
- **Debilidad**: No aborda el caso de "Jugadores de último momento". 
- **Sugerencia**: El `SearchFilterBar` debería permitir agregar un jugador "On-the-fly" si no estaba inscripto, para evitar trabar el inicio del torneo.

### 📈 Post-Match Feedback (`CU-06`)
- **Fortaleza**: El `ShareCardGenerator` es la mejor herramienta de marketing.
- **Sugerencia**: ¿Por qué no incluir el ELO del oponente? El "Social Proof" es más fuerte si le ganaste a alguien "importante".

---

## 3. UI Patterns Audit (`ui-patterns.md`)

- **Badges**: Los estados (DRAFT, LIVE, FINISHED) son claros. 
- **Glassmorphism**: Cuidado con la legibilidad en días de sol (torneos al aire libre). El contraste de `text-white` sobre `bg-white/10` puede fallar.
- **Accessibility**: No se mencionan tamaños de fuente mínimos ni soporte para lectores de pantalla. En un ambiente ruidoso de club, la **retroalimentación auditiva** (sonido de raqueta al marcar punto) podría ser un gran aliado UX.

---

## 4. Next Steps Recommended

1.  **Sync State Mapping**: Definir visualmente cómo se ve un componente cuando está "Sincronizando" vs "Error de Sync".
2.  **Edge Function Migration**: Sacar la lógica de los triggers para que el "Optimistic UI" sea más certero (validando en JS/TS antes de mandar a la DB).
3.  **Prototipado de Canvas**: Validar la performance de las "Líneas de Neon" en dispositivos mobile de gama media.

---

> [!IMPORTANT]
> **Veredicto Final**: El diseño es de 10, pero la arquitectura actual lo está "saboteando". Necesitamos que la app sea **Local-First** para que la UX de "Latencia Cero" sea verdad y no una promesa vacía.
