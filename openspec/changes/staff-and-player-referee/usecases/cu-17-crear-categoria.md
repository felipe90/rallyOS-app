# CU-17: Crear Categoría en Torneo

## Actor
Organizador del torneo

## Objetivo
Crear una categoría dentro de un torneo existente con configuración específica.

## Precondiciones
- Usuario autenticado
- Usuario es ORGANIZER del torneo
- Torneo en status DRAFT o REGISTRATION

## Flujo Principal

### 17.1 Crear categoría con ELO ranges

1. Organizador abre panel del torneo
2. Organizador navega a "Categorías"
3. Organizador hace clic en "Nueva Categoría"
4. Organizador ingresa:
   - Nombre (ej: "Primera Categoría")
   - Modalidad: SINGLES o DOUBLES
   - ELO mínimo (ej: 900)
   - ELO máximo (ej: 1200)
   - Puntos por set (opcional, hereda del deporte)
   - Mejores de sets (opcional, hereda del deporte)
5. Organizador guarda
6. Sistema valida constraints
7. Sistema inserta en `categories`

**Resultado**: Categoría creada con rango de ELO.

### 17.2 Crear categoría "Abierta" (sin ELO)

1. Organizador crea categoría
2. Organizador deja ELO mínimo y máximo en NULL
3. Sistema acepta (categoría abierta a todos)
4. Sistema muestra: "Categoría abierta (sin límite de ELO)"

**Resultado**: Categoría sin restricciones de ELO.

## Flujos Alternativos

### 17.3 Categoría en torneo LIVE
- GIVEN torneo en status LIVE
- WHEN Organizador intenta crear categoría
- THEN sistema rechaza con error "No se pueden crear categorías durante el torneo"

### 17.4 Rango de ELO invertido
- GIVEN ELO mínimo = 1200, ELO máximo = 900
- WHEN Organizador intenta guardar
- THEN sistema rechaza con error "ELO mínimo no puede ser mayor al máximo"

### 17.5 Rango de ELO se superpone con categoría existente
- GIVEN torneo tiene categoría con rango 900-1100
- WHEN Organizador crea categoría con rango 1000-1200
- THEN sistema MUESTRA warning: "Rangos superpuestos"
- AND permite crear si Organizador confirma

### 17.6 Categoría sin nombre
- GIVEN Organizador deja nombre vacío
- WHEN intenta guardar
- THEN sistema rechaza con error "Nombre es requerido"

## Postcondiciones
- Categoría creada en `categories`
- Visible para registro de jugadores
- Puede recibir entries
