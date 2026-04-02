# CU-16: Crear Deporte

## Actor
Administrador de plataforma / Sistema

## Objetivo
Crear un nuevo deporte en el sistema con sus configuraciones por defecto.

## Precondiciones
- Para admin: Usuario autenticado con rol admin de plataforma
- Para seed: Sistema inicializándose

## Flujo Principal

### 16.1 Admin crea deporte via Edge Function

1. Admin abre panel de administración de deportes
2. Admin ingresa:
   - Nombre del deporte (ej: "Tennis")
   - Sistema de puntuación: POINTS o GAMES
   - Puntos por set por defecto (ej: 11)
   - Mejores de sets por defecto (ej: 3)
3. Admin hace clic en "Crear"
4. Sistema valida:
   - Nombre único (no existe otro deporte)
   - Valores numéricos válidos (> 0)
5. Sistema ejecuta `create_sport()` via Edge Function
6. Sistema inserta en tabla `sports`
7. Sistema retorna éxito

**Resultado**: Deporte creado y disponible para torneos.

### 16.2 Seed de deportes por defecto

1. Sistema ejecuta migrations
2. Migration inserta registros default en `sports`:
   - Padel (POINTS, 11, 5)
   - Tennis (GAMES, 6, 3)
   - Pickleball (POINTS, 11, 3)
   - Squash (POINTS, 11, 5)
   - Badminton (GAMES, 21, 3)

**Resultado**: Deportes base disponibles.

## Flujos Alternativos

### 16.3 Nombre de deporte duplicado
- GIVEN deporte "Padel" ya existe
- WHEN admin intenta crear "Padel"
- THEN sistema rechaza con error "Deporte ya existe"

### 16.4 Valores inválidos
- GIVEN admin ingresa puntos_por_set = 0
- WHEN admin intenta crear deporte
- THEN sistema rechaza con validación "Puntos por set debe ser mayor a 0"

### 16.5 Usuario no-admin intenta crear
- GIVEN usuario regular (no admin)
- WHEN intenta ejecutar `create_sport()`
- THEN Edge Function rechaza con error 403

## Postcondiciones
- Registro creado en `sports` table
- Deporte visible para usuarios autenticados
- Audit log generado
