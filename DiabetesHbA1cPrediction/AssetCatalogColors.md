# Asset Catalog Color Definitions

If you prefer using Xcode's Asset Catalog (Assets.xcassets) instead of the
programmatic hex definitions, create the following Color Sets.

Each color has a Light and Dark appearance variant.

## How to Add in Xcode

1. Open **Assets.xcassets** in your project
2. Right-click → **New Color Set**
3. Name it exactly as shown below (matches `Color("Name")` calls in code)
4. In the Attributes Inspector, set **Appearances** to "Any, Dark"
5. Enter the hex values for each appearance

---

## Primary Brand Colors

| Color Set Name   | Light Mode   | Dark Mode    | Usage                               |
|------------------|-------------|-------------|---------------------------------------|
| Primary          | #0B7A6F     | #2DD4BF     | Headers, nav bar, primary buttons     |
| PrimaryLight     | #99F6E4     | #134E4A     | Subtle highlights, selected states    |
| PrimaryDark      | #0F766E     | #5EEAD4     | Pressed states, emphasis              |

## Semantic Health Colors

| Color Set Name   | Light Mode   | Dark Mode    | Usage                               |
|------------------|-------------|-------------|---------------------------------------|
| InRange          | #15803D     | #4ADE80     | Normal readings, positive trends      |
| Caution          | #B45309     | #FBBF24     | Attention needed, trending high       |
| Critical         | #DC2626     | #F87171     | Out of range, urgent                  |
| Planned          | #4F46E5     | #A5B4FC     | Future/planned meals                  |

## Background & Surface Colors

| Color Set Name      | Light Mode   | Dark Mode    | Usage                            |
|---------------------|-------------|-------------|-----------------------------------|
| Background          | #FAFAFA     | #111827     | Main app background               |
| Surface             | #FFFFFF     | #1F2937     | Cards, elevated surfaces           |
| SurfaceSecondary    | #F3F4F6     | #1A2332     | Grouped table background           |

## Text Colors

| Color Set Name   | Light Mode   | Dark Mode    | Usage                               |
|------------------|-------------|-------------|---------------------------------------|
| TextPrimary      | #111827     | #F9FAFB     | Main body text, values               |
| TextSecondary    | #6B7280     | #9CA3AF     | Labels, descriptions                  |
| TextTertiary     | #9CA3AF     | #6B7280     | Timestamps, footnotes                 |

## Border & Divider Colors

| Color Set Name   | Light Mode   | Dark Mode    | Usage                               |
|------------------|-------------|-------------|---------------------------------------|
| Border           | #E5E7EB     | #374151     | Input borders, card outlines          |
| Divider          | #F3F4F6     | #1F2937     | List separators                       |

---

## Color Palette Visual Summary

### Light Mode
```
Background:  ██ #FAFAFA  (warm off-white, less clinical than pure white)
Surface:     ██ #FFFFFF  (cards pop slightly above background)
Primary:     ██ #0B7A6F  (calming teal — trust + health, WCAG AA)
In Range:    ██ #15803D  (clear green — positive, WCAG AA)
Caution:     ██ #B45309  (warm amber — attention without alarm, WCAG AA)
Critical:    ██ #DC2626  (clear red — reserved for genuine urgency, WCAG AA)
Planned:     ██ #4F46E5  (soft indigo — future/hypothetical, WCAG AA)
```

### Dark Mode
```
Background:  ██ #111827  (deep blue-gray, easier on eyes than pure black)
Surface:     ██ #1F2937  (subtle elevation)
Primary:     ██ #2DD4BF  (lighter teal for dark backgrounds)
In Range:    ██ #4ADE80  (brighter green for dark contrast)
Caution:     ██ #FBBF24  (brighter amber)
Critical:    ██ #F87171  (softer red — less harsh at night)
Planned:     ██ #A5B4FC  (lighter indigo)
```
