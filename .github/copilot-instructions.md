# Copilot Instructions

## Project

**UnplannedTravel** is an iOS travel itinerary planning app. The `ios-new/` directory contains the active rewrite in SwiftUI + SwiftData. The `ios-old/` sibling directory holds the prior UIKit + Firebase implementation and serves as a domain reference — do not modify it.

## Build & Test

From the `UnplannedTravel/` directory:

```bash
# Build for simulator
xcodebuild -project UnplannedTravel.xcodeproj -scheme UnplannedTravel \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Run all tests
xcodebuild test -project UnplannedTravel.xcodeproj -scheme UnplannedTravel \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Run a single unit test (Swift Testing)
xcodebuild test -project UnplannedTravel.xcodeproj -scheme UnplannedTravelTests \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:UnplannedTravelTests/UnplannedTravelTests/testName
```

Prefer opening `UnplannedTravel.xcodeproj` in Xcode for day-to-day development.

## Architecture

The app is built with **SwiftUI** for the UI layer and **SwiftData** for persistence. The entry point is `UnplannedTravelApp.swift`, which configures the `ModelContainer`. Views receive the model context via `@Environment(\.modelContext)` and query data with `@Query`.

Test targets:
- `UnplannedTravelTests` — unit tests using the **Swift Testing** framework (`@Test` macro, `#expect(...)`)
- `UnplannedTravelUITests` — UI tests using **XCTest** / `XCUIApplication`

## Domain Model

The app manages travel **Plans** (`Plan`), each composed of ordered **Etapas** (stages). The canonical stage taxonomy (from `disenyo/05_tipos_etapas.txt`):

| Category | Types |
|---|---|
| Vuelo | — |
| Hotel | — |
| Transporte | Coche / Coche de alquiler, Taxi, Bus, Tren, Metro, Barco |
| Food & Drink | Restaurante, Pub & Bar, Café |
| Ocio | Cine, Teatro, Concierto, Nightlife (VidaNocturna) |
| Actividad | Visita guiada / Tour, Museo, Compras, Reunión / Trabajo, Deporte, Actividad |

When implementing new stage types, mirror this taxonomy exactly. Refer to the corresponding Swift model files in `ios-old/UnplannedTravel/UnplannedTravel/` (e.g., `Vuelo.swift`, `Hotel.swift`) for field-level domain reference — the data shape, Spanish field names, and cost/address sub-models are all authoritative.

## Conventions

- **Language**: Domain entity and field names use Spanish (`etapa`, `vuelo`, `coste`, `fecha_inicio`, `notas`, etc.). UI strings should be localisable from the start.
- **Code style**: 4-space indentation, LF line endings, UTF-8, no trailing whitespace (enforced by `.editorconfig`).
- **SwiftData models**: Declared with `@Model final class`. Keep models in separate files, one type per file, matching the naming pattern from the old codebase (`Plan.swift`, `Vuelo.swift`, etc.).
- **Persistence**: Use SwiftData (`@Model`, `ModelContainer`, `modelContext`). Do not introduce Firebase or any other backend without discussion — the old Firebase dependency is intentionally dropped.
- **Old code reference only**: Files in `ios-old/` are read-only domain reference. The old stack (UIKit, `Eureka`, `XCGLogger`, `FirebaseDatabase`) is not used in the new app.
