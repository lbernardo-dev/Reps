---
name: Pulse Aesthetic
colors:
  surface: '#f9f9fe'
  surface-dim: '#d9dade'
  surface-bright: '#f9f9fe'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f3f3f8'
  surface-container: '#ededf2'
  surface-container-high: '#e8e8ed'
  surface-container-highest: '#e2e2e7'
  on-surface: '#1a1c1f'
  on-surface-variant: '#3d4a3a'
  inverse-surface: '#2e3034'
  inverse-on-surface: '#f0f0f5'
  outline: '#6d7b68'
  outline-variant: '#bbcbb5'
  surface-tint: '#006e1c'
  primary: '#006e1c'
  on-primary: '#ffffff'
  primary-container: '#32d74b'
  on-primary-container: '#005814'
  inverse-primary: '#42e355'
  secondary: '#885200'
  on-secondary: '#ffffff'
  secondary-container: '#fd9d06'
  on-secondary-container: '#653c00'
  tertiary: '#005bc1'
  on-tertiary: '#ffffff'
  tertiary-container: '#9bbbff'
  on-tertiary-container: '#00489b'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#70ff76'
  primary-fixed-dim: '#42e355'
  on-primary-fixed: '#002204'
  on-primary-fixed-variant: '#005313'
  secondary-fixed: '#ffddbb'
  secondary-fixed-dim: '#ffb868'
  on-secondary-fixed: '#2b1700'
  on-secondary-fixed-variant: '#673d00'
  tertiary-fixed: '#d8e2ff'
  tertiary-fixed-dim: '#adc6ff'
  on-tertiary-fixed: '#001a41'
  on-tertiary-fixed-variant: '#004493'
  background: '#f9f9fe'
  on-background: '#1a1c1f'
  surface-variant: '#e2e2e7'
typography:
  large-title:
    fontFamily: Inter
    fontSize: 34px
    fontWeight: '700'
    lineHeight: 41px
    letterSpacing: 0.37px
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
  caption-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
    letterSpacing: 0px
  data-display:
    fontFamily: Inter
    fontSize: 48px
    fontWeight: '800'
    lineHeight: 52px
    letterSpacing: -1px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  margin-page: 16px
  gutter-stack: 8px
  section-gap: 24px
  card-padding: 16px
  touch-target: 44px
---

## Brand & Style
The brand personality is energetic, precise, and premium, designed specifically for the native iOS ecosystem. It targets fitness enthusiasts who value data clarity and a frictionless user experience. The design style is **Corporate / Modern** with a strong influence from Apple’s Human Interface Guidelines (HIG). It prioritizes high legibility, fluid transitions, and a "Standard" feel that makes the app feel like a first-party utility. The emotional response should be one of motivation and reliability, using whitespace to reduce cognitive load during high-intensity activities.

## Colors
This design system utilizes a high-vibrancy palette optimized for outdoor and indoor visibility. The **Primary Green** (#32D74B) is the "Active" state color, used for start buttons, completion toggles, and positive progress. The **Secondary Orange** (#FF9F0A) is reserved strictly for achievements, streaks, and metabolic milestones. The background architecture uses the iOS-standard **System Grey 6** (#F2F2F7) to create distinct grouping via contrast rather than heavy borders. All text follows a strict hierarchy of pure black for headers and a muted grey for metadata to ensure focus on key metrics.

## Typography
The typography system is built on **Inter** as a highly legible alternative that mirrors the system font's characteristics while providing excellent spacing for data-heavy views.
- **Large Titles:** Used exclusively at the top of main navigation tabs (Summary, Workouts).
- **Data Display:** A specialized heavyweight style for real-time metrics (Heart Rate, Pace) to ensure visibility at arm's length.
- **Localization:** Text containers must support a 20% expansion in width to accommodate Spanish translations. Use "Footnote" for labels that may wrap.

## Layout & Spacing
This design system follows a **Fluid Grid** model based on the 8pt grid system. 
- **Margins:** Standard horizontal padding of 16px on all screens.
- **Stacking:** Use 8px spacing between elements within a card and 24px between distinct vertical sections.
- **Mobile Adaption:** On larger iPhones (Pro Max), margins can increase to 20px, but the content container remains fluid.
- **Touch Targets:** All interactive elements must maintain a minimum 44x44px hit area, even if the visual element (like a small toggle) is smaller.

## Elevation & Depth
Depth is achieved through **Tonal Layers** rather than heavy shadows. 
- **Base Level:** System Grey (#F2F2F7) serves as the canvas.
- **Secondary Level (Cards):** Pure White (#FFFFFF) surfaces create a "lifted" appearance.
- **Shadows:** Use a single, extremely subtle ambient shadow for primary cards: `0px 4px 12px rgba(0, 0, 0, 0.05)`. 
- **Separators:** Use 0.5pt lines (#C6C6C8) for list items within a card to maintain the native iOS aesthetic.

## Shapes
The shape language is defined by "Continuous Curve" corners to match iOS hardware.
- **Primary Cards:** 16px corner radius.
- **Outer Containers:** 24px corner radius for full-width modals or bottom sheets.
- **Interactive Elements:** Buttons utilize a pill-shape (fully rounded) for primary actions to distinguish them from informational cards.
- **Selection Indicators:** Segmented controls and small chips use an 8px radius.

## Components
- **Buttons:** Primary buttons are pill-shaped, using the energetic green background with white text. Secondary buttons are ghost-style with green text.
- **Cards:** White background, 16px radius. Used for workout summaries and health metrics. Group related data using inset grouped list styles.
- **Progress Bars:** Use a 6px height with a 3px radius. The track is a 10% opacity version of the progress color.
- **Segmented Controls:** Standard iOS style; light grey track with a white sliding "thumb" to switch between "Week", "Month", and "Year" views.
- **Tab Bar:** Translucent (SF Symbols) with Primary Green active state.
- **Data Charts:** Line charts use a 3pt stroke width with a subtle gradient fill underneath. Points of interest use Secondary Orange.