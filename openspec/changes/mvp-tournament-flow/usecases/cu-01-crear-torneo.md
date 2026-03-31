# CU-01: Organizador Crea Torneo

## Actor
- Usuario autenticado con rol ORGANIZER

## Objetivo
Crear un nuevo torneo en el sistema

## Precondiciones
- Usuario está autenticado
- Existe al menos un sport en el sistema

## Flujo Principal

### Paso 1: Usuario inicia creación
El usuario accede al formulario de creación de torneo y completa:
- Nombre del torneo
- Sport (de la lista de sports disponibles)
- ¿Habilitar hándicap? (boolean)
- ¿Usar differential ELO? (boolean)
- Fee amount (0 para torneos gratis, >0 para pago)

### Paso 2: Sistema valida datos
El sistema verifica:
- Nombre no está vacío
- Sport existe en la base de datos
- Fee amount es >= 0

### Paso 3: Sistema crea torneo
El sistema:
1. INSERT en `tournaments` con status = 'DRAFT'
2. INSERT en `tournament_staff` con role = 'ORGANIZER' vinculado al usuario

### Paso 4: Confirmación
El sistema muestra confirmación con:
- ID del torneo creado
- Enlace al tournament dashboard

## Postcondiciones
- Torneo existe en estado DRAFT
- Usuario es ORGANIZER del torneo

## Excepciones

### E-01: Sport no existe
- Sistema muestra error: "El sport seleccionado no existe"
- Vuelve al formulario

### E-02: Nombre duplicado
- Sistema muestra error: "Ya existe un torneo con este nombre"
- Vuelve al formulario

## Notas
- El trigger `trg_tournament_created_assign_organizer` maneja automáticamente la creación del staff
