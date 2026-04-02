# Delta for Security - Staff & Referee RLS

## MODIFIED Requirements

### Requirement: tournament_staff RLS

**Previously**: RLS básico para ORGANIZER y EXTERNAL_REFEREE.

**New Description**: El sistema DEBE implementar RLS estratificada para `tournament_staff` según rol y status.

#### Scenario: Organizer puede ver staff del torneo
- GIVEN un torneo
- WHEN usuario con rol ORGANIZER consulta tournament_staff
- THEN retorna todos los registros del torneo

#### Scenario: Organizer puede insertar staff
- GIVEN un torneo donde el usuario es ORGANIZER
- WHEN inserta un nuevo registro en tournament_staff
- THEN el registro se crea exitosamente

#### Scenario: Organizer puede actualizar staff
- GIVEN un torneo con staff existente
- WHEN ORGANIZER actualiza el registro (status, role)
- THEN la actualización succeede

#### Scenario: Organizer puede eliminar staff
- GIVEN un torneo con staff existente
- WHEN ORGANIZER elimina el registro
- THEN la eliminación succeede (si no hay constraints activos)

#### Scenario: Usuario no staff no puede ver staff
- GIVEN un torneo donde el usuario no es staff
- WHEN usuario intenta consultar tournament_staff
- THEN recibe 0 registros

### Requirement: matches referee_id RLS

**Previously**: `referee_id` solo podía ser usuario en tournament_staff.

**New Description**: El sistema DEBE permitir que `referee_id` sea cualquier usuario que:
1. Tenga status ACTIVE en tournament_staff, O
2. Tenga `PLAYER_REFEREE` activo Y esté checked-in Y no juegue el match

#### Scenario: Organizer asigna EXTERNAL_REFEREE
- GIVEN Match con status SCHEDULED
- AND UsuarioA es EXTERNAL_REFEREE ACTIVE del torneo
- WHEN ORGANIZER asigna UsuarioA como referee
- THEN el assignment succeede

#### Scenario: Organizer asigna PLAYER_REFEREE
- GIVEN Match con status SCHEDULED
- AND JugadorC es PLAYER_REFEREE ACTIVE y checked-in
- AND JugadorC no está en entry_a ni entry_b
- WHEN ORGANIZER asigna JugadorC como referee
- THEN el assignment succeede

#### Scenario: PLAYER_REFEREE no puede ser asignado a match donde juega
- GIVEN Match con entry_a = JugadorA, entry_b = JugadorB
- AND JugadorA es PLAYER_REFEREE ACTIVE
- WHEN ORGANIZER intenta asignar JugadorA como referee
- THEN el sistema rechaza con error "Jugador participa en este match"

### Requirement: scores update RLS

**Previously**: Solo referee_id o ORGANIZER podían actualizar scores.

**New Description**: Para actualizar scores, el usuario DEBE cumplir AL MENOS una de:
1. Ser referee_id del match Y match.status = 'LIVE'
2. Tener rol ORGANIZER en el torneo
3. Tener rol EXTERNAL_REFEREE ACTIVE Y estar asignado al match
4. Tener rol PLAYER_REFEREE ACTIVE Y estar asignado al match

#### Scenario: Asignado PLAYER_REFEREE ingresa score
- GIVEN Match con status LIVE
- AND UsuarioA es PLAYER_REFEREE asignado como referee
- WHEN UsuarioA actualiza scores
- THEN el update succeede

#### Scenario: No-asignado intenta ingresar score
- GIVEN Match con status LIVE
- AND UsuarioA es PLAYER_REFEREE del torneo pero NO asignado al match
- WHEN UsuarioA intenta actualizar scores
- THEN el sistema rechaza con error "No tienes permiso para este match"
