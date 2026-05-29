---
name: High-Performance Fitness System
colors:
  surface: '#fcf8fb'
  surface-dim: '#dcd9dc'
  surface-bright: '#fcf8fb'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f6f3f5'
  surface-container: '#f0edef'
  surface-container-high: '#eae7ea'
  surface-container-highest: '#e4e2e4'
  on-surface: '#1b1b1d'
  on-surface-variant: '#3f4a3c'
  inverse-surface: '#303032'
  inverse-on-surface: '#f3f0f2'
  outline: '#6f7a6b'
  outline-variant: '#becab9'
  surface-tint: '#006e1c'
  primary: '#006b1b'
  on-primary: '#ffffff'
  primary-container: '#1f862d'
  on-primary-container: '#f7fff1'
  inverse-primary: '#79dc77'
  secondary: '#006e1c'
  on-secondary: '#ffffff'
  secondary-container: '#60fe6c'
  on-secondary-container: '#00731d'
  tertiary: '#a23060'
  on-tertiary: '#ffffff'
  tertiary-container: '#c24978'
  on-tertiary-container: '#fffbff'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#94f990'
  primary-fixed-dim: '#79dc77'
  on-primary-fixed: '#002204'
  on-primary-fixed-variant: '#005312'
  secondary-fixed: '#70ff76'
  secondary-fixed-dim: '#42e355'
  on-secondary-fixed: '#002204'
  on-secondary-fixed-variant: '#005313'
  tertiary-fixed: '#ffd9e2'
  tertiary-fixed-dim: '#ffb0c8'
  on-tertiary-fixed: '#3e001d'
  on-tertiary-fixed-variant: '#86194a'
  background: '#fcf8fb'
  on-background: '#1b1b1d'
  surface-variant: '#e4e2e4'
typography:
  large-title:
    fontFamily: Inter
    fontSize: 34px
    fontWeight: '700'
    lineHeight: 41px
    letterSpacing: 0.37px
  title-1:
    fontFamily: Inter
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 34px
    letterSpacing: 0.36px
  title-2:
    fontFamily: Inter
    fontSize: 22px
    fontWeight: '700'
    lineHeight: 28px
    letterSpacing: 0.35px
  title-3:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 25px
    letterSpacing: 0.38px
  headline:
    fontFamily: Inter
    fontSize: 17px
    fontWeight: '600'
    lineHeight: 22px
    letterSpacing: -0.41px
  body:
    fontFamily: Inter
    fontSize: 17px
    fontWeight: '400'
    lineHeight: 22px
    letterSpacing: -0.41px
  callout:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 21px
    letterSpacing: -0.32px
  subheadline:
    fontFamily: Inter
    fontSize: 15px
    fontWeight: '400'
    lineHeight: 20px
    letterSpacing: -0.24px
  footnote:
    fontFamily: Inter
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 18px
    letterSpacing: -0.08px
  caption-1:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
    letterSpacing: 0px
  large-title-mobile:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 38px
    letterSpacing: 0.37px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  margin-page: 1rem
  gutter-grid: 0.75rem
  stack-sm: 0.25rem
  stack-md: 0.5rem
  stack-lg: 1rem
  element-height-md: 2.75rem
---

## Brand & Style

The design system is engineered for elite fitness tracking, blending the disciplined rigor of athletic training with the fluid, premium feel of native iOS environments. The aesthetic is **Modern Corporate** with a heavy emphasis on high-performance utility. It evokes a sense of "quiet energy"—reliable and professional, but powered by a vibrant, high-visibility core.

The target audience consists of dedicated athletes and health-conscious professionals who value efficiency and data clarity. The UI prioritizes high-density information without clutter, utilizing significant white space to allow key performance metrics to breathe. Every transition should feel instantaneous and every surface should feel purposeful, avoiding unnecessary decorative elements in favor of functional precision.

## Colors

The palette is anchored by a high-contrast primary green. To ensure WCAG AA compliance on light backgrounds, the primary brand color is deepened to `#248A30` for text and interactive iconography, while the signature `#32D74B` is reserved for large graphical elements like progress bars and decorative accents where contrast is less critical.

The neutral palette follows Apple’s system gray hierarchy, providing a familiar depth for iOS users:
- **System Background:** Pure white (`#FFFFFF`) for primary surfaces.
- **Secondary Background:** Light gray (`#F2F2F7`) for grouped list backgrounds and inset cards.
- **Tertiary Background:** (`#E5E5EA`) for subtle dividers and inactive states.
- **Labels:** Primary text at `#000000`, Secondary text at `#8E8E93`.

Semantic colors (Error, Warning, Success) strictly follow iOS system defaults to maintain user intuition and safety during intense physical activity.

## Typography

The typography system utilizes Inter to replicate the systematic, utilitarian feel of San Francisco while providing a slightly more modern, geometric touch. 

**Hierarchical Rules:**
- **Large Titles:** Use for main screen entry points. When scrolling, these should transition into standard titles within the Navigation Bar.
- **Emphasized Body:** Use `headline` weight (600) for secondary metadata that requires quick scanning (e.g., heart rate digits, weights, or reps).
- **Localization:** Component layouts must allow for 30% text expansion. Avoid fixed-width labels; use flexible boxes that wrap or truncate with ellipses only when necessary. Ensure "Title 3" is used for exercise names to accommodate longer Spanish descriptions like "Levantamiento de pesas."

## Layout & Spacing

This design system employs a **Fixed Grid** model aligned with standard iOS safe areas. 
- **Margins:** A standard 16pt (1rem) side margin is applied to all primary views.
- **Grid:** A 2-column grid is used for Stat Cards on dashboard views, with a 12pt (0.75rem) gutter.
- **Rhythm:** An 4pt-based incremental scale drives all spacing. 
- **Adaptive Reflow:** On iPad/Desktop, Workout Cards expand into a 3-column grid, while Stat Cards transition to a horizontal rail to maximize data visualization without stretching content excessively.

## Elevation & Depth

Visual hierarchy is established through **Tonal Layers** and subtle **Ambient Shadows**. 

- **Level 0 (Base):** System background (`#FFFFFF`).
- **Level 1 (Cards):** Workout and Stat cards use a white surface with a very soft, diffused shadow (0px 4px 12px, 5% opacity black). This provides a "lift" that suggests interactability without breaking the clean aesthetic.
- **Level 2 (Modals/Overlays):** Standard iOS sheets with a backdrop blur (Material Thin) to maintain context of the underlying workout data.
- **Exercise Rows:** These are flat, separated by 0.5pt hair-line dividers (`#C6C6C8`) to mimic the native iOS "Simple List" style, prioritizing high-speed vertical scanning.

## Shapes

The design system uses a **Rounded** (0.5rem) corner radius for primary UI elements like input fields and small buttons. Larger containers like Workout Cards use `rounded-xl` (1.5rem) to create a friendly, premium container feel that matches the hardware curves of modern iPhones. Progress bars and Segmented Controls utilize the "Pill-shaped" (Full Round) style to emphasize their fluid, continuous nature.

## Components

- **Workout Cards:** Elevated containers with a 24pt corner radius. They feature a bold Title 2 header, an "Emphasized Body" stat row (Duration, Calories), and a primary green call-to-action button.
- **Exercise Rows:** 44pt minimum height. Icon on the left (rounded square background), Exercise Name (Headline weight), and a trailing chevron or "check" action. Ensure the text area is flexible to support Spanish text expansion.
- **Stat Cards:** 1:1 aspect ratio containers in a 2-column grid. Large "Title 1" centered value with a "Caption 1" label underneath.
- **Segmented Controls:** Native iOS appearance. Full-width of the container with a sliding selection indicator. Used for switching between Day/Week/Month views.
- **Progress Bars:** Thin (4pt to 6pt height), fully rounded. The track uses Tertiary Background color, while the fill uses the Primary Green. For "danger" zones or heart rate peaks, the fill may swap to Semantic Error red.
- **Buttons:** Primary buttons are solid green with white text. Secondary buttons use a light gray fill with green text. All buttons maintain a 10pt (0.625rem) internal padding to ensure legibility across all languages.