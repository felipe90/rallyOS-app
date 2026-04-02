# Proposal: Table Tennis Tournament Flow (Tenis de Mesa Real)

## Intent

Modelar el flujo REAL de torneos amateur de tenis de mesa según la experiencia de jugadores, no según idealizaciones de software. Este flujo es diferente al modelo actual de RallyOS (single-elimination brackets desde el inicio).

## Scope

### In Scope

**Fase 1: Registro Tradicional**
- Formulario de inscripción (Google Forms u otro)
- Pago por transferencia bancaria (evidencia por screenshot)
- Sin integración de pagos online en MVP

**Fase 2: Creación de Grupos (Pre-torneo)**
- Formato Round Robin (3-5 jugadores por grupo)
- Sistema de siembra: mejores rankings en grupos separados (cabezas de grupo)
- Confirmación de grupos post check-in
- Grupos flexibles: si alguien no llega, se juega con los presentes

**Fase 3: Desarrollo del Torneo**
- Ronda Robin: jugadores del mismo grupo arbitran partidos entre compañeros
- Sistema de puntuación manual (escribir a mano en papel)
- Llaves post Round Robin
- "El perdedor arbitra": quien pierde, arbitra el siguiente partido del ganador

**Fase 4: Cierre**
- Notas del organizador sobre desarrollo
- Reporte de resultados

### Out of Scope
- Integración con Google Forms (MVP: usar links externos)
- Sistema de pagos integrado (transferencia manual)
- App móvil (MVP: webapp responsive)

## Approach

### Modelo de Fases del Torneo

```
┌─────────────────────────────────────────────────────────────────┐
│              CICLO DE VIDA DEL TORNEO                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. CREACIÓN (Draft)                                           │
│     └─ Organizador define fecha, hora, lieu, costo             │
│                                                                  │
│  2. INSCRIPCIÓN (Registration)                                 │
│     └─ Link a formulario externo                                │
│     └─ Pago por transferencia (evidencia screenshot)              │
│     └─ Lista de inscritos crece                                 │
│                                                                  │
│  3. CONFIRMACIÓN (Pre-Tournament)                              │
│     └─ Día antes: Organizador crea GRUPOS                      │
│     └─ Round Robin: 3-5 jugadores por grupo                  │
│     └─ Siembra: Mejores rankings en grupos separados           │
│                                                                  │
│  4. CHECK-IN (Tournament Day)                                  │
│     └─ Jugadores confirman asistencia                           │
│     └─ Organizador ajusta grupos (quien no llegó)             │
│                                                                  │
│  5. RONDA ROBIN (Live)                                         │
│     └─ Cada grupo juega round-robin                             │
│     └─ Referee: compañero del grupo que NO está en match activo│
│     └─ Scores registrados a mano en planilla                     │
│     └─ Al terminar grupo → tabla de posiciones                  │
│                                                                  │
│  6. LLAVES/KO (Live)                                           │
│     └─ Clasificados de cada grupo a llaves                     │
│     └─ Referee: jugador de misma llave no en match activo      │
│     └─ "El perdedor arbitra": quien pierde, arbitra          │
│        el siguiente partido de quien le ganó                     │
│                                                                  │
│  7. FINAL (Live)                                                │
│     └─ Último partido                                            │
│                                                                  │
│  8. CIERRE (Completed)                                         │
│     └─ Notas del organizador                                     │
│     └─ Resultados finales                                        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Diferencias Clave vs Modelo Actual

| Aspecto | Modelo Actual RallyOS | Flujo Real TT |
|---------|----------------------|---------------|
| **Estructura** | Single-elimination desde inicio | Round Robin → Llaves |
| **Grupos** | Categorías por ELO | Grupos de 3-5 jugadores |
| **Referee** | External o cualquier checked-in | Compañero del grupo que no juega |
| **Referee especial** | - | "El perdedor arbitra al ganador" |
| **Pagos** | Integración online | Transferencia + screenshot |
| **Inscripción** | Directa en app | Formulario externo + lista |
| **Scores** | En tiempo real por app | A mano en planilla, luego digital |

## Gaps Identificados

| Gap | Severidad | Descripción |
|-----|-----------|-------------|
| Round Robin Groups | CRÍTICO | No existe concepto de grupo con round-robin |
| Group Seeding | CRÍTICO | No hay forma de sembrar heads en grupos separados |
| Intra-Group Referees | CRÍTICO | Referees deben ser DEL MISMO grupo |
| Loser Referees Next | ALTA | "El perdedor arbitra el siguiente partido del ganador" |
| Manual Score Entry | MEDIA | Organizador ingresa scores a mano post-grupo |
| External Registration Link | MEDIA | Link a Google Forms, no registro directo |

## Success Criteria

- [ ] Sistema soporta creación de grupos Round Robin (3-5 jugadores)
- [ ] Sistema soporta siembra de cabezas de grupo en grupos separados
- [ ] Sistema asigna referees del MISMO grupo automáticamente
- [ ] Sistema implementa "el perdedor arbitra al ganador"
- [ ] Sistema permite registro de scores manuales post-grupo
- [ ] Sistema permite link externo de inscripción
- [ ] Flujo completo funcional para torneo amateur de tenis de mesa
