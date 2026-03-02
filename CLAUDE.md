# Project Notes

## Editor Rules
- Never use Bash to check whitespace/indentation in files. Just edit the code directly using the Edit tool. If an edit fails due to whitespace mismatch, re-read the file and retry the edit.

## UI Style Guide

### Design System
- Import `Theme` from `Shared.Theme` for all colors, fonts, sizes, spacing, and radii
- NEVER hardcode Color3/font/size values inline — always reference Theme tokens
- When a needed token doesn't exist, add it to Theme.luau first, then use it

### Visual Identity (Trendy Roblox Dark Mode)
- Dark navy backgrounds with neon accent colors (blue, cyan, green, gold)
- Rounded corners on everything (10px default, 14-16px for modals/cards)
- UIStroke borders (1-2px) with Theme.Colors.border for depth
- FredokaOne for big titles/headings, GothamBold for labels/buttons, Gotham for body text
- Text strokes (black, 1-2px) on important text over colored backgrounds

### Component Patterns
- **Modals**: Dark overlay (0.4 transparency) + centered Frame with UICorner + UIStroke
- **Buttons**: TextButton + UICorner(8-10px) + UIStroke(2px border) + GothamBold
- **Cards/Rows**: Frame + UICorner(10px) + UIStroke(1.5px) on bgCard background
- **Lists**: ScrollingFrame with UIListLayout(Vertical) + UIPadding(8-12px)
- **Tabs**: Horizontal UIListLayout in a Frame, GothamBold 13px, selected=accentBlue
- **Layout**: Always use UIListLayout + UIPadding for spacing, never manual Position offsets for list items

### Spacing & Sizing Rules
- Use 8px grid: spacing should be multiples of 4 (4, 8, 12, 16, 20, 24)
- Standard button: 36px tall, large: 48px, small: 28px
- Standard row: 32px tall
- Padding inside containers: 12-20px

### Color Usage
- Backgrounds: bgDark → bgCard → bgElevated (layered depth)
- Primary actions: accentBlue
- Buy/confirm: success (green)
- Danger/close: danger or dangerDark (red)
- Currency/cash: cashGreen
- Achievements/rewards: gold or headerGold
- Always white text on colored buttons
