---
name: Vibrant Monolith
colors:
  surface: '#131313'
  surface-dim: '#131313'
  surface-bright: '#3a3939'
  surface-container-lowest: '#0e0e0e'
  surface-container-low: '#1c1b1b'
  surface-container: '#201f1f'
  surface-container-high: '#2a2a2a'
  surface-container-highest: '#353534'
  on-surface: '#e5e2e1'
  on-surface-variant: '#bbcabf'
  inverse-surface: '#e5e2e1'
  inverse-on-surface: '#313030'
  outline: '#86948a'
  outline-variant: '#3c4a42'
  surface-tint: '#4edea3'
  primary: '#4edea3'
  on-primary: '#003824'
  primary-container: '#10b981'
  on-primary-container: '#00422b'
  inverse-primary: '#006c49'
  secondary: '#adc6ff'
  on-secondary: '#002e6a'
  secondary-container: '#0566d9'
  on-secondary-container: '#e6ecff'
  tertiary: '#95d3ba'
  on-tertiary: '#003829'
  tertiary-container: '#71af97'
  on-tertiary-container: '#004231'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#6ffbbe'
  primary-fixed-dim: '#4edea3'
  on-primary-fixed: '#002113'
  on-primary-fixed-variant: '#005236'
  secondary-fixed: '#d8e2ff'
  secondary-fixed-dim: '#adc6ff'
  on-secondary-fixed: '#001a42'
  on-secondary-fixed-variant: '#004395'
  tertiary-fixed: '#b0f0d6'
  tertiary-fixed-dim: '#95d3ba'
  on-tertiary-fixed: '#002117'
  on-tertiary-fixed-variant: '#0b513d'
  background: '#131313'
  on-background: '#e5e2e1'
  surface-variant: '#353534'
typography:
  headline-lg:
    fontFamily: Geist
    fontSize: 48px
    fontWeight: '700'
    lineHeight: '1.1'
    letterSpacing: -0.02em
  headline-lg-mobile:
    fontFamily: Geist
    fontSize: 32px
    fontWeight: '700'
    lineHeight: '1.2'
  headline-md:
    fontFamily: Geist
    fontSize: 24px
    fontWeight: '600'
    lineHeight: '1.3'
  body-lg:
    fontFamily: Geist
    fontSize: 18px
    fontWeight: '400'
    lineHeight: '1.6'
  body-md:
    fontFamily: Geist
    fontSize: 16px
    fontWeight: '400'
    lineHeight: '1.5'
  label-sm:
    fontFamily: JetBrains Mono
    fontSize: 12px
    fontWeight: '500'
    lineHeight: '1.0'
    letterSpacing: 0.05em
  label-xs:
    fontFamily: JetBrains Mono
    fontSize: 10px
    fontWeight: '500'
    lineHeight: '1.0'
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 8px
  gutter: 24px
  margin: 32px
  container-max: 1280px
---

## Brand & Style
This design system is built for high-performance environments where clarity and technical precision are paramount. It adopts a **Hard-Edge Minimalism** aesthetic, characterized by high-contrast interfaces, solid surfaces, and a strict rejection of organic effects like gradients or blurs. 

The personality is authoritative, energetic, and digital-native. It targets developers, data analysts, and technical power users who require an interface that feels like a precision instrument. By utilizing deep obsidian backgrounds contrasted with hyper-saturated emerald and electric tones, the UI evokes a sense of "cyber-industrial" efficiency.

## Colors
The palette is rooted in a "Deep Dark" philosophy. The primary background is a pure obsidian to maximize the perceived luminosity of the accent colors.

- **Primary (Emerald):** Used for "Success" states, primary call-to-actions, and active progress indicators.
- **Secondary (Electric Blue):** Used for links, information callouts, and secondary interactive states.
- **Surfaces:** UI elements sit on solid charcoal tiles. There are no semi-transparent layers.
- **Borders:** All interactive and container elements use a 1px solid border to define structure against the dark void.

## Typography
The system uses a dual-font approach to emphasize technicality. **Geist** provides a clean, modern grotesque feel for all prose and headings, ensuring high legibility. **JetBrains Mono** is utilized for labels, metadata, and data points to reinforce the "code-like" precision of the brand.

Headlines should be set with tight letter spacing and minimal line height to create a dense, impactful visual block. Labels are always uppercase with slight tracking to maintain readability at very small sizes.

## Layout & Spacing
The layout follows a strict **8px square grid** system. All components, padding, and margins must be multiples of 8. 

- **Grid:** Use a 12-column fluid grid for desktop with 24px gutters.
- **Margins:** Page-level margins are 32px on desktop and 16px on mobile.
- **Logic:** Vertical rhythm is maintained by using consistent 16px or 32px gaps between logical sections. Elements should be aligned to the grid edges to maintain the "monolithic" structured feel.

## Elevation & Depth
Depth is communicated through **Tonal Stacking** and **1px Borders** rather than shadows.
- **Level 0 (Background):** Obsidian (#0A0A0A).
- **Level 1 (Cards/Containers):** Charcoal (#171717) with a 1px border (#262626).
- **Level 2 (Popovers/Modals):** Charcoal (#171717) with a 1px border using the Primary Emerald or Secondary Blue to indicate focus.

Shadows are entirely disabled. Visual "lift" is achieved by increasing the border brightness or changing the background of a component to a slightly lighter neutral grey.

## Shapes
The design system utilizes **ROUND_EIGHT** (0.5rem / 8px) as the base radius. This softens the brutalist aesthetic slightly, making the interface feel modern and intentional rather than purely "retro-terminal."

- **Standard:** 8px (Buttons, Inputs, Cards).
- **Large:** 16px (Main containers, Modals).
- **Extra Large:** 24px (Large section blocks).

## Components

### Buttons
- **Primary:** Solid Emerald (#10B981) background with Obsidian text. No border.
- **Secondary:** Transparent background with a 1px Electric Blue (#3B82F6) border and Blue text.
- **Hover States:** Increase border thickness to 2px or shift background color to a higher luminosity.

### Inputs & Fields
- **Default:** Charcoal background, 1px #262626 border. 
- **Active/Focus:** 1px Emerald border. Text remains high-contrast white.
- **Labels:** Always use JetBrains Mono in uppercase, positioned 8px above the field.

### Cards
- Solid #171717 background.
- 1px border in #262626. 
- For "Featured" cards, the top border can be highlighted with a 2px Emerald or Blue stroke.

### Lists & Data Tables
- Rows are separated by 1px solid #262626 lines.
- Hovering over a row changes the background from Obsidian to Charcoal.
- Use JetBrains Mono for all numerical data within tables.

### Chips & Status
- **Success:** Solid Emerald background, Obsidian text, 8px radius.
- **System/Info:** Solid Blue background, White text.
- **Inactive:** #262626 background, #737373 text.