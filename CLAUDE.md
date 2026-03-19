# Project Notes

## Tech Stack
- **Runtime**: Roblox Luau (type-annotated Lua)
- **UI Framework**: React (Roact-like, v17.2.1 from `Packages.React`)
- **Rendering**: ReactRoblox (maps React components to Roblox Instances)
- **Data**: ProfileStore (community library wrapping DataStore)
- **Monetization**: MarketplaceService (GamePasses + DevProducts)
- **Remotes**: RemoteEvent/RemoteFunction via `Shared.Remotes`

## Project Structure
```
src/
├── client/
│   ├── init.client.luau          # Entry point
│   ├── services/                 # ChatTags, DialogService, ImageService, MusicService, etc.
│   └── ui/
│       ├── App.luau              # Root React component, all state management
│       ├── components/           # 25+ UI screens/modals (MenuScreen, PuzzleBoard, RoomLobbyScreen, etc.)
│       └── hooks/                # usePuzzleState, useDrag, useTimer, etc.
├── server/
│   ├── init.server.luau          # Initializes all handlers
│   ├── data/                     # ProfileService (DataStore wrapper), LeaderboardService
│   ├── handlers/                 # PuzzleHandler, MonetizationHandler, RoomManager, DailyRewardsHandler, etc.
│   ├── services/                 # TitleService, TableStatusService
│   └── cafe/                     # TableManager (multiplayer seating)
├── shared/                       # Config & types used by both client and server
│   ├── Theme.luau                # Design tokens (colors, fonts, sizes, spacing, radii, z-index)
│   ├── Remotes.luau              # Remote creation & lookup helpers
│   ├── MonetizationConfig.luau   # GamePass & DevProduct catalog (VIP, AllImages, Expert, PuzzleAssist)
│   ├── ProgressionConfig.luau    # XP rewards, par times, min times, difficulty config
│   ├── PuzzleGenerator.luau      # Procedural puzzle edge generation
│   ├── ImageCatalog.luau         # 500+ images across 10 packs; getById(), getAll()
│   ├── PuzzlePacks.luau          # Pack metadata (Landscapes, Animals, Brainrots, etc.)
│   ├── ShopItems.luau            # Cosmetics (board skins, confetti, snap effects)
│   └── RoomTypes.luau            # Multiplayer room types & constants
└── workspace/                    # In-game objects, cafe tables, NPCs
```

## Key Patterns

### State Flow
- `App.luau` owns all state (`gameState`: "walking" → "menu" → "playing" → "complete" / multiplayer equivalents)
- State passed to child components as props; callbacks bubble actions up
- Exported `ComponentNameProps` types define all props for each component

### Server Handlers
- Each handler has an `Init()` function called from `init.server.luau`
- Access remotes via `Remotes.GetEvent("Name")` / `Remotes.GetFunction("Name")`
- Access player data via `ProfileService.GetData(player)` — returns mutable table
- GamePass checks: `pcall(function() return MarketplaceService:UserOwnsGamePassAsync(userId, passId) end)`

### Multiplayer Rooms
- Rooms stored in-memory on server (not persisted)
- States: "lobby" → "playing" → "complete"
- Virtual canvas: 1200x800 for viewport-independent coordinates
- Snap threshold: 25 units; claims expire after 10 seconds

## Editor Rules
- **Indentation**: All `.luau` files use **tabs** for indentation (not spaces). The Read tool displays tabs as spaces, so never trust the visual indentation from Read output when constructing Edit strings.
- **Always use the Edit tool directly** to modify `.luau` files. Never use Python scripts or Bash workarounds for file edits.
- **Unicode escapes**: Luau files use `\u{XXXX}` syntax for unicode (e.g., `\u{2713}` for checkmark, `\u{1F512}` for lock). These are literal backslash sequences in the source, not the rendered characters.

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
