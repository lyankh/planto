<!-- Badges -->
<p align="center">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-FA7343?style=for-the-badge&logo=swift&logoColor=white">
  <img alt="SwiftUI" src="https://img.shields.io/badge/SwiftUI-1575F9?style=for-the-badge&logo=swift&logoColor=white">
  <img alt="iOS" src="https://img.shields.io/badge/iOS-000000?style=for-the-badge&logo=apple&logoColor=white">
</p>

<h1 align="center">🌿 Planto</h1>
<p align="center">A minimal SwiftUI app to help you care for your plants.<br/>
Track watering schedules, room location, and light needs — with gentle local notifications.</p>

---

## ✨ Features
- Add and manage multiple plants
- Set room, light, watering schedule, and water amount
- Local notifications via `UserNotifications`
- Persistent storage using `@AppStorage` (JSON-encoded)
- Clean SwiftUI UI with glass-style components

---

## 🧠 Architecture (MVVM)
Planto/
├─ App/                # Entry point (PlantoApp.swift)
├─ Models/             # Data models & enums (Plant.swift)
├─ ViewModels/         # State & logic (PlantsStore.swift)
├─ Services/           # Helpers (NotificationManager.swift)
└─ Views/              # UI
├─ Root/            # ContentView
├─ Start/           # StartPage
├─ List/            # MyPlantsView
│  └─ Components/   # GlassCard, ProgressSection, PlantRow, EmptyHintView, AllDoneToast
└─ Sheets/          # PlantEditorSheet

---

## 🪴 Preview  
> _“Your plants deserve care — and you deserve a reminder that feels gentle, not robotic.”_ 🌤️
<img src="Simulator Screenshot - iPhone 17 - 2025-10-30 at 14.43.23.png" width="250">
<img src="Simulator Screenshot - iPhone 17 - 2025-10-30 at 14.43.40.png" width="250">
<img src="Simulator Screenshot - iPhone 17 - 2025-10-30 at 14.45.24.png" width="250">
<img src="Simulator Screenshot - iPhone 17 - 2025-10-30 at 14.45.32.png" width="250">
<img src="Simulator Screenshot - iPhone 17 - 2025-10-30 at 14.45.38.png" width="250">

