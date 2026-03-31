# CU-09: Jugador Ve su Perfil y Estadísticas

## Actor
- Jugador autenticado

## Objetivo
Ver y editar su perfil personal y estadísticas de ELO

## Precondiciones
- Jugador tiene perfil `persons` creado
- Jugador tiene `athlete_stats` para cada sport

## Flujo Principal

### Paso 1: Jugador accede a perfil
El jugador:
1. Clic en "Mi Perfil"
2. Ve su información:
   - Nombre completo
   - Nickname
   - ELO por sport
   - Total partidos jugados
   - Historial de cambios ELO

### Paso 2: Jugador edita perfil
El jugador puede actualizar:
- first_name
- last_name
- nickname

### Paso 3: Sistema valida y guarda
El sistema:
1. UPDATE `persons` WHERE user_id = auth.uid()
2. Retorna confirmación

### Paso 4: Jugador ve historial ELO
El jugador puede ver:
- Lista de cambios de ELO con fecha
- Partidos jugados con resultados
- Tendencia de ELO (gráfico)

## Postcondiciones
- persons actualizado si hubo cambios
- No se modifica athlete_stats desde esta pantalla

## Excepciones

### E-01: Sin perfil
- Si user no tiene persons linked
- Mostrar: "Crea tu perfil de jugador"
