# SnapClock

**Nap Peacefully — your countdown starts when you actually fall asleep.**

SnapClock is an iOS + watchOS app that detects the moment you fall asleep using Apple Watch sensors (heart rate + motion), then starts your nap countdown from that point. No more waking up early because you couldn't fall asleep fast enough.

---

## Features

- **Automatic sleep detection** — Apple Watch continuously monitors heart rate and wrist motion. Once your HR drops and movement stops, the countdown begins.
- **Smart countdown** — Based on real wall-clock time, not a simple decrement timer. Accurate even after the Watch screen turns off.
- **Manual & timeout modes** — Start the timer manually at any point, or let it auto-start after 45 minutes if sleep isn't detected.
- **Backup notification** — iPhone schedules a local notification as a safety net in case the Watch session ends unexpectedly.
- **Nap history** — Every session is saved with SwiftData. Browse past naps with quality ratings.
- **Apple Health-style detail view** — Tap any history record to see a score ring (0–100), stats grid, and a proportional sleep timeline.
- **EN / 中 language switch** — Toggle between English and Chinese at any time from the home screen.
- **Deep-space UI** — Dark navy gradient, lavender accents, breathing orb animations.

---

## Requirements

| Component | Minimum Version |
|-----------|----------------|
| iPhone    | iOS 17          |
| Apple Watch | watchOS 10 (Series 7 or later) |
| Xcode     | 15+             |
| Swift     | 5.9+            |

> HealthKit authorization is required on Apple Watch for heart rate access.
> Motion & Fitness permission is required for accelerometer data.

---

## How It Works

### Sleep Detection Algorithm

1. **Baseline collection (30 s)** — On session start, the Watch samples heart rate for 30 seconds to establish a personal baseline BPM.
2. **Sliding window evaluation (every 5 s)** — A 180-second sliding window tracks HR samples and wrist-motion standard deviation.
3. **Sleep trigger conditions** (all three must hold for one full window):
   - HR has dropped ≥ 12% from baseline
   - HR is below 65 bpm
   - Wrist motion std-dev < 0.02 g
4. **30-second exemption** — The first 30 seconds after session start are ignored to avoid false positives from lying down.
5. **45-minute timeout** — If sleep is not detected within 45 minutes, the countdown starts automatically.

### Countdown

The Watch stores the sleep-detected timestamp and calculates `remainingSeconds = endDate.timeIntervalSinceNow` on every timer tick. This means the countdown stays accurate regardless of background throttling or screen-off periods.

### iPhone ↔ Watch Communication

- **iPhone → Watch**: `startNap` (NapConfig JSON) and `cancelNap` via WatchConnectivity, with `transferUserInfo` fallback when Watch is not reachable.
- **Watch → iPhone**: real-time `sessionState` updates (monitoring / sleeping / timedOut / completed) and final `NapResult` on session end.

---

## Project Structure

```
SnapClock/
├── SnapClock/                  # iPhone target
│   ├── SnapClockApp.swift      # App entry, TabView root, SwiftData container
│   ├── HomeView.swift          # Main screen: duration picker, start button
│   ├── SessionActiveView.swift # Live session screen with breathing orb
│   ├── SessionSummaryView.swift# Post-session result screen
│   ├── NapHistoryView.swift    # Scrollable history list
│   ├── NapDetailView.swift     # Apple Health-style session detail
│   ├── NapSession.swift        # SwiftData model + NapQuality enum
│   ├── PhoneSessionManager.swift # WCSession iPhone side
│   ├── BackupNotificationManager.swift
│   └── SharedTypes.swift       # NapConfig, NapResult, WCMessageKey (shared)
│
└── SnapClockWatch Watch App/   # watchOS target
    ├── SnapClockWatchApp.swift # Watch entry, state routing
    ├── SleepSessionManager.swift # Session orchestration
    ├── SleepDetector.swift     # Sliding-window sleep detection algorithm
    ├── HeartRateMonitor.swift  # HKWorkoutSession + HKAnchoredObjectQuery
    ├── MotionMonitor.swift     # CMMotionManager, 5-s std-dev
    ├── HapticManager.swift     # Escalating wake haptics
    ├── WatchConnectivityManager.swift
    ├── WatchHomeView.swift
    ├── WatchMonitoringView.swift
    ├── WatchCountdownView.swift
    └── WatchSummaryView.swift
```

---

## Installation

1. Clone the repository.
2. Open `SnapClock/SnapClock.xcodeproj` in Xcode.
3. Set your development team in **Signing & Capabilities** for both the iPhone and Watch targets.
4. Select your iPhone + paired Apple Watch as the run destination.
5. Build & run (`⌘R`). Grant HealthKit and Motion permissions when prompted on the Watch.

> **Note:** `SharedTypes.swift` is shared between both targets. If Xcode does not include it automatically, add it to both targets manually in the File Inspector.

---

## Quality Rating System

| Badge | Label | Criteria |
|-------|-------|----------|
| 优 / S | Deep | Sleep detected, fell asleep in < 10 min |
| 良 / A | Good | Sleep detected, fell asleep in 10–20 min |
| 中 / B | Fair | Timed out or fell asleep after 20+ min |
| 手 / M | Manual | Manual timer start |

Score (0–100) formula: `90 − 2 × max(0, minutesToSleep − 3)`, clamped to `[30, 95]`.

---

## License

Personal use only. Not distributed on the App Store.
