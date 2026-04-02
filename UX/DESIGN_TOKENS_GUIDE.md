# Guía de Design Tokens para RallyOS

Los "Design Tokens" (Tokens de Diseño) son los átomos de tu UI. Son variables agnósticas que representan decisiones de diseño (colores, espaciados, tipografías, bordes) en lugar de valores duros (Magic Numbers).

## El Problema ("Magic Numbers")
Sin tokens, un desarrollador escribe esto:
```css
.card {
  padding: 16px; 
  background-color: #F4F5F7;
  border-radius: 8px;
}
.button {
  padding: 15px; /* Inconsistencia humana */
  background-color: #F4F6F8; /* Inconsistencia humana */
  border-radius: 10px;
}
```
Esto genera una interfaz desprolija. Cuando el equipo crece, tienes 40 grises distintos y 15 tamaños de margen.

## La Solución (Design Tokens)
Centralizar las variables y prohibir el uso de píxeles o valores Hexadecimales en los componentes.

```javascript
// theme.js (Los Tokens)
export const tokens = {
  spacing: {
    sm: 8,
    md: 16,
    lg: 24,
  },
  colors: {
    surface_bg: '#F4F5F7',
    primary: '#1E40AF',
  },
  radii: {
    card: 8,
    button: 12,
  }
}
```

Uso en código:
```jsx
// React Native / Expo
<View style={{ 
  padding: tokens.spacing.md, 
  backgroundColor: tokens.colors.surface_bg,
  borderRadius: tokens.radii.card 
}}>
```

## Nomenclatura Estricta (Escala Semántica)
Un buen sistema de tokens no nombra a los colores por lo que son, sino **por lo que hacen**.

❌ **Mal (Físico)**: `color: tokens.blue_500` - ¿Qué pasa si la marca cambia a rojo en el futuro?
✅ **Bien (Semántico)**: `color: tokens.colors.brand_primary` - Tu código nunca cambia, solo cambias el diccionario del Token de atrás.

## Herramientas para React Native / Expo
En vez de escribir tu propio sistema de Tokens desde cero, el estándar en 2026 para React Native es usar uno de estos dos motores que obligan a usar Tokens:

1. **NativeWind**: TailwindCSS portado a React Native. Usa las clases predefinidas de Tailwind (que en el fondo son Tokens). Ej: `p-4` (padding: 16px), `bg-zinc-800`.
2. **Tamagui**: Un motor de estilos unificado para Web y Native enfocado al rendimiento que te obliga a crear un `tamagui.config.ts` gigante lleno de tus tokens. Es la opción más escalable para SaaS B2B pesados.
