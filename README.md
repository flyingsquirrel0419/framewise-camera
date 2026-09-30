# Framewise

A real-time, on-device composition guide camera for iPhone. Point the camera at a
person, an object or a landscape, and Framewise shows where the subject is, where it
would frame better, and one short instruction to get there.

- **On-device only.** Uses Vision's built-in models (human body, face landmarks,
  attention and objectness saliency) and CoreMotion. No server and no paid API. Frames never leave the phone.
- **CompositionKit** (`Packages/CompositionKit`) is a pure-Swift engine with no UIKit
  dependency: scene classification → subject resolution → multi-candidate scoring
  (thirds, headroom, looking room, edge tension, balance, negative space, symmetry-aware
  centering, horizon) → temporal stabilization (EMA, target hysteresis,
  optimal-state hysteresis, tip debouncing). It is unit-tested on Linux and macOS.
- **App** (`App/`): SwiftUI + AVFoundation. Camera, Vision, Composition glue,
  Components, Views and String Catalog localization (English and Korean, following
  the system language).

## Build

```sh
brew install xcodegen
xcodegen generate
open Framewise.xcodeproj
```

Requires Xcode 16+ and iOS 17+. To check the engine alone, run `swift test --package-path Packages/CompositionKit`.

CI builds an **unsigned** Release IPA on every push. Tagged builds (`v*`) attach
it to a GitHub Release. Re-sign it with your own identity before installing on a device.
