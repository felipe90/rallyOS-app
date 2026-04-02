# SPEC-DOM-04: Tournament Format Configuration (Sport-Agnostic)

## Purpose

Definir la configuración que hace que RallyOS sea **sport-agnostic**. Cada sport/tournament define su formato mediante configuración, no mediante código hardcodeado.

---

## Core Principle

> **RallyOS es sport-agnostic por diseño.** Ninguna asunción sobre un deporte específico debe estar hardcodeada. Todo debe ser configurable.

---

## Tournament Format Configuration

### Location

La configuración vive en `sports.scoring_config` como JSONB, con la siguiente estructura extendida:

```json
{
  "type": "standard",
  "points_per_set": 11,
  "best_of_sets": 5,
  "win_by_2": true,
  "deuce_at": 10,
  
  "tournament_format": {
    "enabled": true,
    "structure": "ROUND_ROBIN_THEN_KNOCKOUT",
    "referee_mode": "INTRA_GROUP",
    "loser_referees_winner": true,
    "group_size": { "min": 3, "max": 5 },
    "advancement_count": 2,
    "has_third_place": false,
    "manual_score_entry": true
  }
}
```

### Tournament Structure Options

```typescript
type TournamentStructure = 
  | 'KNOCKOUT_ONLY'           // Single elimination desde el inicio
  | 'ROUND_ROBIN_ONLY'        // Solo grupos, no hay KO
  | 'ROUND_ROBIN_THEN_KNOCKOUT'  // Grupos → KO (TT, Badminton)
  | 'SWISS_THEN_KNOCKOUT'    // Swiss → KO (Chess, algunos padel)
  | 'AMERICANO'              // Padel Americano - todos con todos, sin grupos
  | 'MEXICAN'                // Padel Mexicano - grupos → KO
  | 'LEAGUE'                 // Todos contra todos, sin eliminación
  | 'CUSTOM';                // Configuración custom
```

### Referee Mode Options

```typescript
type RefereeMode = 
  | 'NONE'           // No hay referees (Americano, social)
  | 'EXTERNAL'       // Umpires profesionales (Tennis, Badminton pro)
  | 'INTRA_GROUP'    // Compañeros del mismo grupo (TT amateur)
  | 'ROTATING'       // Rotan entre compañeros de grupo (algunos Padel)
  | 'SELF'           // Self-refereed con challenge (algunos formatos)
  | 'ORGANIZER';     // Solo el organizador puede arbitrar
```

---

## Config by Sport Type

### Table Tennis (Amateur)

```json
{
  "tournament_format": {
    "enabled": true,
    "structure": "ROUND_ROBIN_THEN_KNOCKOUT",
    "referee_mode": "INTRA_GROUP",
    "loser_referees_winner": true,
    "group_size": { "min": 3, "max": 5 },
    "advancement_count": 2,
    "has_third_place": false,
    "manual_score_entry": true
  }
}
```

### Padel Americano

```json
{
  "tournament_format": {
    "enabled": true,
    "structure": "AMERICANO",
    "referee_mode": "NONE",
    "loser_referees_winner": false,
    "no_groups": true,
    "rotate_partners": true,
    "points_per_match": 32,
    "manual_score_entry": false
  }
}
```

### Tennis (Amateur/Club)

```json
{
  "tournament_format": {
    "enabled": true,
    "structure": "KNOCKOUT_ONLY",
    "referee_mode": "ORGANIZER",
    "loser_referees_winner": false,
    "has_third_place": true,
    "manual_score_entry": false
  }
}
```

### Badminton (Pro/Amateur)

```json
{
  "tournament_format": {
    "enabled": true,
    "structure": "ROUND_ROBIN_THEN_KNOCKOUT",
    "referee_mode": "EXTERNAL",
    "loser_referees_winner": false,
    "group_size": { "min": 4, "max": 6 },
    "advancement_count": 2,
    "has_third_place": true,
    "manual_score_entry": false
  }
}
```

---

## Rules by Configuration

### Rule Activation Matrix

| Config | INTRA_GROUP | NONE | EXTERNAL | ROTATING |
|--------|-------------|-------|----------|----------|
| Referee debe ser del mismo grupo | ✅ | N/A | N/A | ⚠️ |
| El perdedor arbitra al ganador | ✅ | ❌ | ❌ | ❌ |
| Rotación de partners | ❌ | ❌ | ❌ | ✅ |
| Manual score entry | ✅ | ❌ | ❌ | ⚠️ |

---

## Implementation Notes

### Default Configuration

Cada sport nuevo en `sports` DEBE tener un `tournament_format` por defecto que puede ser override por el organizador del torneo.

### Override at Tournament Level

El organizador PUEDE override del sport config a nivel tournament:

```typescript
interface TournamentOverrides {
  structure?: TournamentStructure;      // Override de sport
  referee_mode?: RefereeMode;          // Override de sport
  loser_referees_winner?: boolean;     // Override de sport
  group_size?: { min: number; max: number };  // Override de sport
}
```

### Validation Rules

1. Si `structure = 'KNOCKOUT_ONLY'`, no se crean `round_robin_groups`
2. Si `structure = 'AMERICANO'`, no hay grupos, se usa sistema de rotación
3. Si `referee_mode = 'NONE'`, no se crean `referee_assignments`
4. Si `referee_mode = 'INTRA_GROUP'`, SE CREAN grupos implícitamente

---

## Agnosticity Checklist

Para cada feature implementada, verificar:

- [ ] ¿Esta feature aplica a TODOS los sports o solo a uno?
- [ ] ¿Se puede disable/configurar esta feature?
- [ ] ¿El default funciona para sports desconocidos?
- [ ] ¿Hay algún trigger/RPC que asuma un sport específico?

Si la respuesta a cualquiera es "solo a uno" o "asuma", hacer la feature configurable.
