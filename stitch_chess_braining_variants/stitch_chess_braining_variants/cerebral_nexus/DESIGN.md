---
name: Cerebral Nexus
colors:
  surface: '#131315'
  surface-dim: '#131315'
  surface-bright: '#39393b'
  surface-container-lowest: '#0e0e10'
  surface-container-low: '#1c1b1d'
  surface-container: '#201f21'
  surface-container-high: '#2a2a2c'
  surface-container-highest: '#353437'
  on-surface: '#e5e1e4'
  on-surface-variant: '#bac9cc'
  inverse-surface: '#e5e1e4'
  inverse-on-surface: '#313032'
  outline: '#849396'
  outline-variant: '#3b494c'
  surface-tint: '#00daf3'
  primary: '#c3f5ff'
  on-primary: '#00363d'
  primary-container: '#00e5ff'
  on-primary-container: '#00626e'
  inverse-primary: '#006875'
  secondary: '#ebb2ff'
  on-secondary: '#520072'
  secondary-container: '#b600f8'
  on-secondary-container: '#fff6fc'
  tertiary: '#aaffc8'
  on-tertiary: '#00391f'
  tertiary-container: '#00ee92'
  on-tertiary-container: '#00673c'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#9cf0ff'
  primary-fixed-dim: '#00daf3'
  on-primary-fixed: '#001f24'
  on-primary-fixed-variant: '#004f58'
  secondary-fixed: '#f8d8ff'
  secondary-fixed-dim: '#ebb2ff'
  on-secondary-fixed: '#320047'
  on-secondary-fixed-variant: '#74009f'
  tertiary-fixed: '#56ffa8'
  tertiary-fixed-dim: '#00e38b'
  on-tertiary-fixed: '#002110'
  on-tertiary-fixed-variant: '#00522f'
  background: '#131315'
  on-background: '#e5e1e4'
  surface-variant: '#353437'
typography:
  display-lg:
    fontFamily: Montserrat
    fontSize: 48px
    fontWeight: '800'
    lineHeight: 52px
    letterSpacing: -0.02em
  display-mobile:
    fontFamily: Montserrat
    fontSize: 32px
    fontWeight: '800'
    lineHeight: 36px
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Montserrat
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
    letterSpacing: 0.02em
  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-caps:
    fontFamily: Geist
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.1em
  mono-ui:
    fontFamily: Geist
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  base: 4px
  xs: 8px
  sm: 16px
  md: 24px
  lg: 32px
  xl: 48px
  container-margin: 20px
  gutter: 12px
---

## Brand & Style
The design system embodies a "Futuristic Cerebral" aesthetic, positioning chess not as a dusty board game, but as a high-stakes, high-tech mental sport. The brand personality is competitive, intellectual, and high-energy, targeting players who view strategic thinking as a superpower.

The visual style is a fusion of **Minimalism** and **Glassmorphism**, set against a deep obsidian void. The UI utilizes sharp precision, translucent surfaces, and vibrant light-emission effects to simulate a holographic tactical interface. Every interaction should feel like engaging with a quantum computer: fast, precise, and visually reactive.

## Colors
This design system utilizes a high-contrast dark mode palette to reduce eye strain during deep focus while allowing vibrant accents to pop.

- **Primary (Electric Blue):** Used for standard tactical actions, navigation, and primary buttons. It represents the "logic" of the game.
- **Secondary (Cyber Purple):** Reserved for "Braining" rounds and specialized mental power-ups. It represents the "limit-break" state of the user's mind.
- **Tertiary (Emerald Green):** Used for success states, energy replenishment, and active power-ups.
- **Neutral (Obsidian):** The background is a true-black variant (#0A0A0C) to maximize the "glowing" effect of the primary accents.
- **Surface:** Semi-transparent grays with blue tints are used for glass layers.

## Typography
Typography is sharp and technical. **Montserrat** is used for high-impact display moments and headlines to convey strength and modernity. **Inter** provides high legibility for body copy and instructions. **Geist** is introduced for labels and technical data (like move notations and timers) to reinforce the developer-centric, high-tech aesthetic.

Headlines should utilize "All-Caps" for section headers to create a sense of urgency and authority. Body text should maintain generous line heights to ensure readability against dark backgrounds.

## Layout & Spacing
The design system uses a **Fluid Grid** model optimized for mobile-first interaction. The layout rhythm is based on a 4px baseline shift to ensure mathematical precision in element alignment.

- **Mobile:** 4-column grid with 20px side margins and 12px gutters.
- **Components:** Elements use "Safe Area" padding to avoid interference with edge-to-edge gestures.
- **The Board:** The chess board is always a fixed aspect ratio square, centered vertically, with a "Glow Margin" of 16px to allow for active-piece lighting effects.

## Elevation & Depth
Elevation is expressed through **Glassmorphism** and **Light-Emission** rather than traditional shadows.

1.  **Level 0 (Base):** Obsidian background (#0A0A0C).
2.  **Level 1 (Panels):** Semi-transparent obsidian with a 20px backdrop blur and a 1px stroke (Opacity: 10% White).
3.  **Level 2 (Active Cards):** Glass layer with a subtle primary-colored inner glow (inner-shadow) to indicate the surface is "powered on."
4.  **Level 3 (Modals):** High-blur backdrop (40px) with a distinctive 1px Electric Blue border.

Depth is accentuated by "Light Leaks"—subtle, out-of-focus gradients of purple and blue positioned behind the primary glass panels to create a sense of three-dimensional space.

## Shapes
The shape language is aggressive and architectural. While corners are "Soft" (0.25rem), the overall silhouette remains structured. 

- **Standard Buttons:** Small corner radius (4px) to maintain a sharp, technical look.
- **Interactive Nodes:** Hexagonal or octagonal subtle clipping for specialized "Power-up" buttons to distinguish them from standard UI.
- **Avatars:** Strictly square with a 1px glowing border.

## Components

- **Action Buttons:** Primary buttons feature a solid Electric Blue fill with black text. Secondary buttons are "Ghost" style with an Electric Blue border and a subtle outer glow (0px 0px 8px).
- **Brain-Mode Chips:** Small indicators with a Cyber Purple pulse animation, indicating active cerebral boosts.
- **Holographic Cards:** Used for player profiles and match stats. These utilize heavy backdrop blur and top-down linear gradient strokes.
- **Input Fields:** Bottom-border only, turning Electric Blue with a neon glow when focused.
- **The Chess Board:** Dark-themed squares (Deep Gray and Obsidian). The "Active Piece" is highlighted with a 2px Emerald Green stroke.
- **Move List:** A scrolling list using the `mono-ui` font style, with the current move highlighted in Cyber Purple.