# Discard (SwiftUI, iOS 17+)

Seven scoreboards: Hearts, Cribbage, High-Low-Jack, War, Spades, Oh Hell, Euchre. 2-8 players each.

## Build in Nyxian
1. Create a new SwiftUI/Swift project in Nyxian.
2. Copy every file in `Sources/` into the project's source folder (keep App.swift as the @main entry; delete Nyxian's template @main file).
3. Use `Info.plist` values if Nyxian's generated plist differs (bundle id, display name).
4. Build the IPA, sign with Signulous, install with Feather.

Only plain SwiftUI is used: no macros, no third-party packages, no #Preview. APIs newer than iOS 16:
navigationDestination(item:), onChange with two parameters, topBarTrailing (all iOS 17).

## Notes
- Data is saved to Documents/cardscores.json.
- Nothing here has been compiled or run on a device.

## Credits
App icon: artwork from [Icons8](https://icons8.com) when available at build time, otherwise the MIT-licensed
[Bootstrap Icons](https://icons.getbootstrap.com) spade. The release notes record which one was used.

## Credits (v1.5)
- Leather texture: "Brown Leather" by Rob Tuytel, [Poly Haven](https://polyhaven.com/a/brown_leather), CC0. Fetched and tinted Rosewater during the build.
- Palette: Catppuccin Latte.
