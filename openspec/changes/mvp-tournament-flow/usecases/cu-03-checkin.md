# CU-03: Organizador Confirma Asistencia

## Actor
- Organizador del torneo

## Objetivo
Confirmar que los jugadores registrados efectivamente asisten al torneo

## Precondiciones
- Torneo está en estado CHECK_IN
- Entries existen en estado CONFIRMED

## Flujo Principal

### Paso 1: Organizador abre check-in
El organizador:
1. Accede al panel del torneo
2. Ve la lista de entries confirmadas
3. Inicia el proceso de check-in

### Paso 2: Organizador confirma jugadores
Para cada jugador/equipo, el organizador:
1. Verifica identidad (opcional)
2. Marca como "Presente" o "Ausente"

### Paso 3: Sistema registra asistencia
El sistema:
- Si "Presente": UPDATE `checked_in_at` con timestamp actual
- Si "Ausente": UPDATE status a 'CANCELLED'
- INSERT en `community_feed` (ENTRY_CANCELLED si ausentes)

### Paso 4: Reporte
El sistema muestra:
- Total confirmados
- Total ausentes
- Lista de entries listas para bracket

## Postcondiciones
- Entries tienen `checked_in_at` set o status = 'CANCELLED'
- Tournament puede avanzar a estado LIVE

## Excepciones

### E-01: Insuficientes entries
- Si menos de 2 entries confirmadas
- Sistema muestra: "Se necesitan al menos 2 entries para generar bracket"

### E-02: Tournament no en CHECK_IN
- Sistema muestra: "El torneo debe estar en CHECK_IN para confirmar asistencia"
