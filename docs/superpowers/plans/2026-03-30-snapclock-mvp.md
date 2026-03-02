# SnapClock MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 构建一款 iOS + watchOS 小睡辅助 App，Watch 自主检测入睡后开始计时并震动唤醒。

**Architecture:** Watch 端完全自主运行一次小睡会话（心率采集 + 入睡检测 + 倒计时 + 震动唤醒），不依赖 iPhone 连接；iPhone 端提供主 UI 和历史存储，会话结束后接收 Watch 同步的数据。每个功能点完成后立即 git commit。

**Tech Stack:** Swift 5.9+, SwiftUI, SwiftData, HealthKit (HKWorkoutSession + HKAnchoredObjectQuery), CoreMotion, WatchConnectivity, WKExtendedRuntimeSession, UserNotifications, iOS 17+ / watchOS 10+

---

## 文件结构总览

```
SnapClock/
├── SnapClock.xcodeproj
├── SnapClock/                              # iOS target
│   ├── SnapClockApp.swift
│   ├── Shared/
│   │   └── SharedTypes.swift              # 两端共享的数据类型（加入两个 target）
│   ├── Models/
│   │   └── NapSession.swift               # SwiftData 持久化模型
│   ├── Services/
│   │   ├── PhoneSessionManager.swift      # WCSession iPhone 侧（接收 Watch 数据）
│   │   └── BackupNotificationManager.swift # iPhone 备用闹钟
│   └── Views/
│       ├── HomeView.swift                 # 主页：时长选择 + 开始
│       ├── SessionActiveView.swift        # 会话中：状态镜像
│       └── SessionSummaryView.swift       # 会话结束：摘要
├── SnapClock Watch App/                   # watchOS target
│   ├── SnapClockWatchApp.swift
│   └── Services/
│       ├── HeartRateMonitor.swift         # HKWorkoutSession + 实时心率查询
│       ├── MotionMonitor.swift            # CMMotionManager + 标准差计算
│       ├── SleepDetector.swift            # 核心算法：滑动窗口入睡判断
│       ├── SleepSessionManager.swift      # 会话编排：检测→计时→震动→同步
│       ├── HapticManager.swift            # 渐强震动唤醒
│       └── WatchConnectivityManager.swift # WCSession Watch 侧
│   └── Views/
│       ├── WatchHomeView.swift            # Watch 主页：时长 ±5min + 开始
│       ├── WatchMonitoringView.swift      # 监测中：状态 + 取消
│       ├── WatchCountdownView.swift       # 倒计时：剩余时间
│       └── WatchSummaryView.swift         # 会话结束摘要
└── SnapClockTests/                        # iOS + Watch 单元测试
    ├── SleepDetectorTests.swift           # 算法全量测试
    └── MotionMonitorTests.swift           # 标准差计算测试
```

---

## Task 1：Git 初始化 + Xcode 项目创建

**Files:**
- Create: `SnapClock.xcodeproj`（通过 Xcode GUI 创建）
- Create: `.gitignore`

- [ ] **Step 1: 在终端初始化 git 仓库**

```bash
cd /Users/dragonhope/Documents/Xcode/SnapClock
git init
```

- [ ] **Step 2: 创建 .gitignore**

在 `/Users/dragonhope/Documents/Xcode/SnapClock/.gitignore` 写入：

```
# Xcode
*.xcuserstate
xcuserdata/
*.xccheckout
*.moved-aside
DerivedData/
*.hmap
*.ipa
*.dSYM.zip
*.dSYM

# Swift Package Manager
.build/
.swiftpm/

# CocoaPods（未使用，预防性忽略）
Pods/
Podfile.lock

# macOS
.DS_Store
.AppleDouble
.LSOverride
```

- [ ] **Step 3: 在 Xcode 中创建项目**

打开 Xcode → File → New → Project
- 选择模板：iOS → App
- Product Name: `SnapClock`
- Team: 选择你的 Apple ID
- Organization Identifier: 填写反向域名（如 `com.yourname`）
- Interface: SwiftUI
- Language: Swift
- Storage: None（SwiftData 后续手动加）
- **取消勾选** "Include Tests"（我们手动创建测试 target）
- 保存位置：`/Users/dragonhope/Documents/Xcode/SnapClock`（**不要**让 Xcode 再创建一层文件夹，直接选这个目录）

- [ ] **Step 4: 添加 watchOS target**

Xcode → File → New → Target
- 选择：watchOS → Watch App
- Product Name: `SnapClock Watch App`
- Bundle Identifier 会自动填为 `com.yourname.SnapClock.watchkitapp`
- Interface: SwiftUI
- Language: Swift
- 点击 Finish，弹出提示时选择 "Activate Scheme"

- [ ] **Step 5: 添加测试 target**

Xcode → File → New → Target → iOS → Unit Testing Bundle
- Product Name: `SnapClockTests`
- Target to be Tested: `SnapClock`

- [ ] **Step 6: 配置 watchOS target 的最低系统版本**

- 选中项目根节点 → 选 `SnapClock Watch App` target → General
- Deployment Info → watchOS: 设置为 10.0

- [ ] **Step 7: 首次 commit**

```bash
cd /Users/dragonhope/Documents/Xcode/SnapClock
git add .gitignore SnapClock.xcodeproj SnapClock/ "SnapClock Watch App/" SnapClockTests/
git commit -m "feat: initialize Xcode project with iOS + watchOS targets"
```

---

## Task 2：权限配置（HealthKit + CoreMotion + 通知）

**Files:**
- Modify: `SnapClock/Info.plist`
- Modify: `SnapClock Watch App/Info.plist`
- Create: `SnapClock.entitlements`（Watch target）

- [ ] **Step 1: 为 Watch target 开启 HealthKit capability**

- 选中 `SnapClock Watch App` target → Signing & Capabilities → + Capability
- 搜索并添加 **HealthKit**
- 勾选 "Health Records"（可选）和 **"Background Delivery"**

- [ ] **Step 2: 为 Watch target 的 Info.plist 添加权限描述**

在 `SnapClock Watch App/Info.plist` 中添加（右键 → Open As → Source Code）：

```xml
<key>NSHealthShareUsageDescription</key>
<string>SnapClock 需要读取心率数据来判断您何时入睡</string>
<key>NSHealthUpdateUsageDescription</key>
<string>SnapClock 需要记录一次静默锻炼会话以获取实时心率</string>
<key>NSMotionUsageDescription</key>
<string>SnapClock 需要加速度计数据来判断您的身体是否静止</string>
```

- [ ] **Step 3: 为 iOS target 开启 HealthKit capability（用于同步数据）**

- 选中 `SnapClock` target → Signing & Capabilities → + Capability → HealthKit

- [ ] **Step 4: 为 iOS target 的 Info.plist 添加权限描述**

在 `SnapClock/Info.plist` 中添加：

```xml
<key>NSHealthShareUsageDescription</key>
<string>SnapClock 显示您的睡眠会话心率摘要</string>
<key>NSHealthUpdateUsageDescription</key>
<string>SnapClock 保存您的小睡会话到健康 App</string>
```

- [ ] **Step 5: 请求通知权限准备（iOS）**

在 `SnapClock/SnapClockApp.swift` 替换为：

```swift
import SwiftUI
import UserNotifications

@main
struct SnapClockApp: App {
    init() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { _, _ in }
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}
```

- [ ] **Step 6: 在真机上编译验证权限不报错**

Run → 选择你的 iPhone → Build（⌘B）。确认编译成功，暂时忽略"ContentView not found"等 UI 错误。

- [ ] **Step 7: Commit**

```bash
git add SnapClock/ "SnapClock Watch App/" SnapClock.xcodeproj
git commit -m "feat: configure HealthKit, CoreMotion, and notification permissions"
```

---

## Task 3：共享数据类型（SharedTypes.swift）

**Files:**
- Create: `SnapClock/Shared/SharedTypes.swift`（加入 iOS + Watch 两个 target）

- [ ] **Step 1: 在 Xcode 中创建 Shared 组和文件**

- 右键 `SnapClock` 组 → New Group → 命名 `Shared`
- 右键 `Shared` → New File → Swift File → 命名 `SharedTypes.swift`
- 在弹出的 Target Membership 对话框中**同时勾选** `SnapClock` 和 `SnapClock Watch App`

- [ ] **Step 2: 写入 SharedTypes.swift**

```swift
import Foundation

// MARK: - 会话配置（iPhone 发给 Watch）

struct NapConfig: Codable {
    let napDurationSeconds: TimeInterval   // 用户设定的小睡时长（秒）
    let timeoutSeconds: TimeInterval       // 超时保护时长，默认 2700（45分钟）
    let startedAt: Date                    // iPhone 侧会话开始时间戳

    static let defaultTimeout: TimeInterval = 2700

    /// 备用通知触发延迟 = 超时保护 + 小睡时长 + 2分钟缓冲
    var backupNotificationDelay: TimeInterval {
        timeoutSeconds + napDurationSeconds + 120
    }
}

// MARK: - 会话结果（Watch 发回 iPhone）

struct NapResult: Codable {
    let sessionStartedAt: Date     // 会话开始（用户按下开始）
    let sleepDetectedAt: Date?     // 入睡时刻（nil = 超时未检测到，或手动）
    let napEndedAt: Date           // 实际唤醒时刻
    let wasManual: Bool            // 是否手动触发计时（跳过检测）
    let didTimeout: Bool           // 是否因超时自动开始计时

    /// 入睡等待时长（秒），nil 表示未检测到
    var timeToSleepSeconds: TimeInterval? {
        guard let detected = sleepDetectedAt else { return nil }
        return detected.timeIntervalSince(sessionStartedAt)
    }

    /// 实际睡眠时长（秒）
    var actualSleepSeconds: TimeInterval {
        let sleepStart = sleepDetectedAt ?? sessionStartedAt
        return napEndedAt.timeIntervalSince(sleepStart)
    }
}

// MARK: - WCSession 消息键

enum WCMessageKey {
    static let startNap = "startNap"       // iPhone → Watch，值为 NapConfig JSON
    static let cancelNap = "cancelNap"     // iPhone → Watch
    static let napResult = "napResult"     // Watch → iPhone，值为 NapResult JSON
    static let sessionState = "sessionState" // Watch → iPhone，实时状态
}

// MARK: - Watch 会话状态（实时通知 iPhone）

enum WatchSessionState: String, Codable {
    case idle
    case monitoring       // 检测中
    case sleeping         // 已入睡，倒计时中
    case completed        // 会话结束
    case timedOut         // 超时自动开始
}
```

- [ ] **Step 3: 确认 Target Membership**

在 Xcode 文件检查器（右侧 Inspector）中确认 `SharedTypes.swift` 的 Target Membership 同时勾选了两个 target。

- [ ] **Step 4: 编译两个 target 确认无报错**

⌘B 编译 iOS，再切换 Scheme 到 Watch App，⌘B 编译 Watch。

- [ ] **Step 5: Commit**

```bash
git add SnapClock/Shared/
git commit -m "feat: add shared data types for nap config, result, and WCSession messages"
```

---

## Task 4：心率监测模块（HeartRateMonitor.swift）

**Files:**
- Create: `SnapClock Watch App/Services/HeartRateMonitor.swift`

> **注意：** 此模块依赖真机运行，无法在模拟器完整测试。Build 通过后需要在真实 Watch 上验证心率数据。

- [ ] **Step 1: 在 Watch target 创建 Services 组和文件**

右键 `SnapClock Watch App` 组 → New Group `Services`
右键 `Services` → New File → Swift File → `HeartRateMonitor.swift`
Target Membership：只勾 `SnapClock Watch App`

- [ ] **Step 2: 写入 HeartRateMonitor.swift**

```swift
import Foundation
import HealthKit

/// 通过 HKWorkoutSession 获取连续高频心率（约 5 秒/次）。
/// 必须先调用 start()，心率数据通过 onHeartRateSample 回调返回。
@Observable
final class HeartRateMonitor: NSObject {

    // MARK: - Public

    /// 收到新心率样本时回调，参数为 BPM
    var onHeartRateSample: ((Double) -> Void)?
    var isRunning = false
    var lastHR: Double = 0

    // MARK: - Private

    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var anchoredQuery: HKAnchoredObjectQuery?
    private var anchor: HKQueryAnchor?

    private let heartRateType = HKQuantityType(.heartRate)
    private let bpmUnit = HKUnit.count().unitDivided(by: .minute())

    // MARK: - Lifecycle

    func requestAuthorization() async throws {
        let typesToShare: Set<HKSampleType> = [HKObjectType.workoutType()]
        let typesToRead: Set<HKObjectType> = [heartRateType]
        try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
    }

    func start() async throws {
        guard !isRunning else { return }

        let config = HKWorkoutConfiguration()
        config.activityType = .other
        config.locationType = .indoor

        let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
        let builder = session.associatedWorkoutBuilder()
        builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)

        session.delegate = self
        builder.delegate = self

        workoutSession = session
        workoutBuilder = builder

        session.startActivity(with: Date())
        try await builder.beginCollection(at: Date())

        startAnchoredQuery()
        isRunning = true
    }

    func stop() {
        anchoredQuery.map { healthStore.stop($0) }
        anchoredQuery = nil
        workoutSession?.end()
        workoutBuilder?.endCollection(withEnd: Date()) { _, _ in }
        workoutSession = nil
        workoutBuilder = nil
        isRunning = false
    }

    // MARK: - Anchored Query（每隔 ~5 秒获得新样本）

    private func startAnchoredQuery() {
        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: nil,
            anchor: anchor,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, newAnchor, _ in
            self?.anchor = newAnchor
            self?.process(samples: samples)
        }

        query.updateHandler = { [weak self] _, samples, _, newAnchor, _ in
            self?.anchor = newAnchor
            self?.process(samples: samples)
        }

        healthStore.execute(query)
        anchoredQuery = query
    }

    private func process(samples: [HKSample]?) {
        guard let quantitySamples = samples as? [HKQuantitySample] else { return }
        for sample in quantitySamples {
            let bpm = sample.quantity.doubleValue(for: bpmUnit)
            DispatchQueue.main.async { [weak self] in
                self?.lastHR = bpm
                self?.onHeartRateSample?(bpm)
            }
        }
    }
}

// MARK: - HKWorkoutSessionDelegate

extension HeartRateMonitor: HKWorkoutSessionDelegate {
    func workoutSession(_ session: HKWorkoutSession,
                        didChangeTo toState: HKWorkoutSessionState,
                        from fromState: HKWorkoutSessionState,
                        date: Date) {}

    func workoutSession(_ session: HKWorkoutSession, didFailWithError error: Error) {
        print("[HeartRateMonitor] Workout session error: \(error)")
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension HeartRateMonitor: HKLiveWorkoutBuilderDelegate {
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                        didCollectDataOf collectedTypes: Set<HKSampleType>) {}
}
```

- [ ] **Step 3: 编译 Watch target（⌘B）确认无语法错误**

预期：Build Succeeded

- [ ] **Step 4: 真机手动验证（在下一个任务完成 Watch UI 之前用临时调试视图）**

在 `SnapClockWatchApp.swift` 中临时改为：

```swift
import SwiftUI

@main
struct SnapClockWatchApp: App {
    @State private var monitor = HeartRateMonitor()
    @State private var hrText = "待机中"

    var body: some Scene {
        WindowGroup {
            VStack {
                Text("心率: \(hrText)")
                Button("开始监测") {
                    Task {
                        try? await monitor.requestAuthorization()
                        try? await monitor.start()
                        monitor.onHeartRateSample = { bpm in
                            hrText = String(format: "%.0f bpm", bpm)
                        }
                    }
                }
                Button("停止") { monitor.stop() }
            }
        }
    }
}
```

部署到真实 Apple Watch → 点击"开始监测" → 确认心率数值出现并每隔数秒更新。

- [ ] **Step 5: 恢复 SnapClockWatchApp.swift（临时内容清空，保留 @main 结构）**

```swift
import SwiftUI

@main
struct SnapClockWatchApp: App {
    var body: some Scene {
        WindowGroup {
            Text("SnapClock Watch")
        }
    }
}
```

- [ ] **Step 6: Commit**

```bash
git add "SnapClock Watch App/"
git commit -m "feat: implement HeartRateMonitor with HKWorkoutSession and anchored query"
```

---

## Task 5：动作监测模块（MotionMonitor.swift）

**Files:**
- Create: `SnapClock Watch App/Services/MotionMonitor.swift`
- Create: `SnapClockTests/MotionMonitorTests.swift`（加入 SnapClockTests target）

- [ ] **Step 1: 创建 MotionMonitor.swift**

路径：`SnapClock Watch App/Services/MotionMonitor.swift`，Target：`SnapClock Watch App`

```swift
import Foundation
import CoreMotion

/// 采集加速度计数据，每 5 秒计算三轴合力的标准差，判断身体是否静止。
/// standardDeviation < 0.02g 视为静止。
@Observable
final class MotionMonitor {

    // MARK: - Public

    /// 收到新静止度指标时回调，参数为 5 秒窗口内的加速度标准差（g）
    var onMotionSample: ((Double) -> Void)?
    var isRunning = false
    var lastStdDev: Double = 0

    // MARK: - Private

    private let manager = CMMotionManager()
    private var sampleBuffer: [Double] = []  // 合力数值缓冲（5秒内约 50 个样本）
    private var reportTimer: Timer?

    private let samplingInterval: TimeInterval = 0.1   // 100ms 一次原始采样
    private let reportingInterval: TimeInterval = 5.0  // 每 5 秒输出一次标准差

    // MARK: - Lifecycle

    func start() {
        guard !isRunning, manager.isAccelerometerAvailable else { return }
        sampleBuffer = []
        manager.accelerometerUpdateInterval = samplingInterval
        manager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let data else { return }
            let magnitude = sqrt(data.acceleration.x * data.acceleration.x
                               + data.acceleration.y * data.acceleration.y
                               + data.acceleration.z * data.acceleration.z)
            self?.sampleBuffer.append(magnitude)
        }

        reportTimer = Timer.scheduledTimer(withTimeInterval: reportingInterval, repeats: true) { [weak self] _ in
            self?.flushBuffer()
        }
        isRunning = true
    }

    func stop() {
        manager.stopAccelerometerUpdates()
        reportTimer?.invalidate()
        reportTimer = nil
        sampleBuffer = []
        isRunning = false
    }

    // MARK: - Internal

    private func flushBuffer() {
        guard !sampleBuffer.isEmpty else { return }
        let stdDev = MotionMonitor.standardDeviation(of: sampleBuffer)
        sampleBuffer = []
        lastStdDev = stdDev
        onMotionSample?(stdDev)
    }

    // MARK: - Pure Math（可单元测试）

    /// 计算数组的总体标准差。
    static func standardDeviation(of values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(values.count)
        return sqrt(variance)
    }
}
```

- [ ] **Step 2: 创建 MotionMonitorTests.swift**

路径：`SnapClockTests/MotionMonitorTests.swift`，Target：`SnapClockTests`

```swift
import XCTest
@testable import SnapClock

final class MotionMonitorTests: XCTestCase {

    func test_standardDeviation_allSameValues_returnsZero() {
        let values = [1.0, 1.0, 1.0, 1.0]
        XCTAssertEqual(MotionMonitor.standardDeviation(of: values), 0.0, accuracy: 1e-10)
    }

    func test_standardDeviation_knownValues_returnsCorrectResult() {
        // mean = 3, variance = (4+1+0+1+4)/5 = 2, stdDev = sqrt(2) ≈ 1.4142
        let values = [1.0, 2.0, 3.0, 4.0, 5.0]
        XCTAssertEqual(MotionMonitor.standardDeviation(of: values), sqrt(2.0), accuracy: 1e-10)
    }

    func test_standardDeviation_singleValue_returnsZero() {
        XCTAssertEqual(MotionMonitor.standardDeviation(of: [9.8]), 0.0)
    }

    func test_standardDeviation_staticBody_belowThreshold() {
        // 静止时加速度应约为 1g（重力），微小抖动
        let staticSamples = (0..<50).map { _ in 1.0 + Double.random(in: -0.005...0.005) }
        let stdDev = MotionMonitor.standardDeviation(of: staticSamples)
        XCTAssertLessThan(stdDev, 0.02, "静止状态下标准差应低于阈值 0.02g")
    }

    func test_standardDeviation_movingBody_aboveThreshold() {
        // 运动时加速度变化大
        let movingSamples: [Double] = [0.8, 1.5, 0.6, 1.8, 0.9, 1.4, 0.7, 1.6]
        let stdDev = MotionMonitor.standardDeviation(of: movingSamples)
        XCTAssertGreaterThan(stdDev, 0.02, "运动状态下标准差应高于阈值 0.02g")
    }
}
```

> **注意：** `MotionMonitor.standardDeviation` 是静态纯函数，通过 `@testable import SnapClock` 无法访问 Watch target 的代码。需要将 `standardDeviation` 方法临时也加到 iOS target 或抽离为 Shared 文件。最简单的做法：将 `MotionMonitorTests.swift` 加入 Watch test target 而非 iOS test target。
>
> 实际操作：Xcode → File → New → Target → watchOS → Unit Testing Bundle → 命名 `SnapClockWatchTests`，然后在 `MotionMonitorTests.swift` 的 Target Membership 中切换为 `SnapClockWatchTests`，并将 `@testable import SnapClock` 改为 `@testable import SnapClock_Watch_App`。

- [ ] **Step 3: 运行 MotionMonitor 单元测试**

Product → Test（⌘U），选择 `SnapClockWatchTests` scheme
预期：5 个测试全部通过 ✓

- [ ] **Step 4: Commit**

```bash
git add "SnapClock Watch App/Services/MotionMonitor.swift" SnapClockTests/ SnapClockWatchTests/
git commit -m "feat: implement MotionMonitor with accelerometer std-dev and unit tests"
```

---

## Task 6：入睡检测算法（SleepDetector.swift）⭐ 核心

**Files:**
- Create: `SnapClock Watch App/Services/SleepDetector.swift`（Watch target）
- Create: `SnapClockWatchTests/SleepDetectorTests.swift`（Watch test target）

- [ ] **Step 1: 创建 SleepDetector.swift**

```swift
import Foundation

// MARK: - 配置

struct SleepDetectorConfig {
    /// 心率相对降幅阈值（0.88 = 下降 12%）
    var hrDropFactor: Double = 0.88
    /// 心率绝对值上限（bpm）
    var hrAbsoluteMax: Double = 65
    /// 加速度标准差上限（g），低于此值视为静止
    var motionStdDevMax: Double = 0.02
    /// 连续满足条件多少秒后判定为入睡（秒）
    var windowDuration: TimeInterval = 180
    /// 短暂中断豁免时长（秒），期间不重置窗口
    var exemptionDuration: TimeInterval = 30
    /// 最大监测时长（秒），超过后触发超时
    var timeoutDuration: TimeInterval = 2700  // 45 分钟
}

// MARK: - 事件

enum SleepDetectorEvent {
    case sleepDetected(at: Date)
    case timedOut
}

// MARK: - 检测器

/// 纯逻辑类，无 HealthKit/CoreMotion 依赖，完全可单元测试。
/// 调用方每 5 秒喂入一次 evaluate()，检测器内部维护滑动窗口状态。
final class SleepDetector {

    let config: SleepDetectorConfig
    var onEvent: ((SleepDetectorEvent) -> Void)?

    // MARK: - 内部状态

    private var baselineHR: Double = 0
    private var sessionStartedAt: Date = .distantPast
    private var windowStartedAt: Date?      // 当前窗口起始时刻
    private var exemptionStartedAt: Date?   // 豁免开始时刻
    private var exemptionConsumed = false   // 每会话仅一次豁免
    private(set) var isSleepDetected = false
    private(set) var isTimedOut = false
    /// 当前窗口是否正在累积中（用于调试日志）
    var isWindowActive: Bool { windowStartedAt != nil }

    // MARK: - Init

    init(config: SleepDetectorConfig = SleepDetectorConfig()) {
        self.config = config
    }

    // MARK: - Session Control

    /// 在会话开始时调用，传入基准心率（会话开始时的静息心率）
    func startSession(baselineHR: Double, at time: Date) {
        self.baselineHR = baselineHR
        self.sessionStartedAt = time
        self.windowStartedAt = nil
        self.exemptionStartedAt = nil
        self.exemptionConsumed = false
        self.isSleepDetected = false
        self.isTimedOut = false
    }

    func reset() {
        windowStartedAt = nil
        exemptionStartedAt = nil
        exemptionConsumed = false
        isSleepDetected = false
        isTimedOut = false
    }

    // MARK: - Core Evaluation（每 5 秒调用一次）

    /// - Parameters:
    ///   - hr: 当前心率（bpm）
    ///   - motionStdDev: 过去 5 秒内的加速度标准差（g）
    ///   - now: 当前时刻
    func evaluate(hr: Double, motionStdDev: Double, at now: Date) {
        guard !isSleepDetected, !isTimedOut else { return }

        // 1. 超时检查
        if now.timeIntervalSince(sessionStartedAt) >= config.timeoutDuration {
            isTimedOut = true
            onEvent?(.timedOut)
            return
        }

        let conditionsMet = checkConditions(hr: hr, motionStdDev: motionStdDev)

        if conditionsMet {
            handleConditionsMet(at: now)
        } else {
            handleConditionsNotMet(at: now)
        }
    }

    // MARK: - Private

    private func checkConditions(hr: Double, motionStdDev: Double) -> Bool {
        let hrDropOK   = hr <= baselineHR * config.hrDropFactor
        let hrAbsOK    = hr < config.hrAbsoluteMax
        let motionOK   = motionStdDev < config.motionStdDevMax
        return hrDropOK && hrAbsOK && motionOK
    }

    private func handleConditionsMet(at now: Date) {
        if exemptionStartedAt != nil {
            // 从豁免中恢复
            exemptionStartedAt = nil
            // 窗口继续（windowStartedAt 未被清除）
        }

        if windowStartedAt == nil {
            windowStartedAt = now
        }

        let elapsed = now.timeIntervalSince(windowStartedAt!)
        if elapsed >= config.windowDuration {
            isSleepDetected = true
            onEvent?(.sleepDetected(at: windowStartedAt!))
        }
    }

    private func handleConditionsNotMet(at now: Date) {
        guard let windowStart = windowStartedAt else {
            // 窗口从未开始，什么都不做
            return
        }

        if exemptionStartedAt == nil && !exemptionConsumed {
            // 开始豁免计时
            exemptionStartedAt = now
            return
        }

        if let exemStart = exemptionStartedAt {
            let gapDuration = now.timeIntervalSince(exemStart)
            if gapDuration <= config.exemptionDuration {
                // 豁免期内，继续等待恢复，不重置窗口
                return
            } else {
                // 豁免超时，标记豁免已用，重置窗口
                exemptionConsumed = true
                exemptionStartedAt = nil
            }
        }

        // 重置窗口
        _ = windowStart  // 避免 unused warning
        windowStartedAt = nil
    }
}
```

- [ ] **Step 2: 创建 SleepDetectorTests.swift**

```swift
import XCTest
@testable import SnapClock_Watch_App

final class SleepDetectorTests: XCTestCase {

    // MARK: - 测试配置（缩短时长便于测试）

    var config: SleepDetectorConfig {
        var c = SleepDetectorConfig()
        c.windowDuration = 10     // 10 秒窗口（测试用）
        c.exemptionDuration = 3   // 3 秒豁免
        c.timeoutDuration = 60    // 60 秒超时
        c.hrDropFactor = 0.88
        c.hrAbsoluteMax = 65
        c.motionStdDevMax = 0.02
        return c
    }

    var detector: SleepDetector!
    let baseline: Double = 72  // 基准心率

    override func setUp() {
        detector = SleepDetector(config: config)
    }

    // MARK: - 基础满足条件：连续 10 秒触发入睡

    func test_sleepDetected_afterWindowDuration() {
        let start = Date()
        detector.startSession(baselineHR: baseline, at: start)

        var detectedAt: Date?
        detector.onEvent = { event in
            if case .sleepDetected(let at) = event { detectedAt = at }
        }

        // 喂入 12 次（每次 1 秒，共 12 秒 > 10 秒窗口）
        for i in 0..<12 {
            detector.evaluate(hr: 58, motionStdDev: 0.01, at: start.addingTimeInterval(Double(i)))
        }

        XCTAssertNotNil(detectedAt, "连续满足条件 10 秒后应触发入睡事件")
    }

    // MARK: - 心率未下降：不触发

    func test_noSleep_whenHrNotDropped() {
        let start = Date()
        detector.startSession(baselineHR: baseline, at: start)
        var detected = false
        detector.onEvent = { if case .sleepDetected = $0 { detected = true } }

        // 心率 70，基准 72，70/72 = 0.972，未达 0.88 的降幅
        for i in 0..<15 {
            detector.evaluate(hr: 70, motionStdDev: 0.01, at: start.addingTimeInterval(Double(i)))
        }

        XCTAssertFalse(detected, "心率未充分下降时不应触发入睡")
    }

    // MARK: - 心率绝对值超限：不触发

    func test_noSleep_whenHrAboveAbsoluteMax() {
        let start = Date()
        detector.startSession(baselineHR: 80, at: start)
        var detected = false
        detector.onEvent = { if case .sleepDetected = $0 { detected = true } }

        // HR 66 > 65，即使降幅满足也不触发
        for i in 0..<15 {
            detector.evaluate(hr: 66, motionStdDev: 0.01, at: start.addingTimeInterval(Double(i)))
        }

        XCTAssertFalse(detected, "心率绝对值超过 65bpm 时不应触发入睡")
    }

    // MARK: - 动作过大：不触发

    func test_noSleep_whenMotionTooLarge() {
        let start = Date()
        detector.startSession(baselineHR: baseline, at: start)
        var detected = false
        detector.onEvent = { if case .sleepDetected = $0 { detected = true } }

        for i in 0..<15 {
            detector.evaluate(hr: 58, motionStdDev: 0.05, at: start.addingTimeInterval(Double(i)))
        }

        XCTAssertFalse(detected, "动作幅度过大时不应触发入睡")
    }

    // MARK: - 中断超过豁免时长：重置窗口

    func test_windowReset_whenInterruptionExceedsExemption() {
        let start = Date()
        detector.startSession(baselineHR: baseline, at: start)
        var detected = false
        detector.onEvent = { if case .sleepDetected = $0 { detected = true } }

        // 满足 5 秒
        for i in 0..<5 {
            detector.evaluate(hr: 58, motionStdDev: 0.01, at: start.addingTimeInterval(Double(i)))
        }
        // 中断 5 秒（超过 3 秒豁免）
        for i in 5..<10 {
            detector.evaluate(hr: 75, motionStdDev: 0.05, at: start.addingTimeInterval(Double(i)))
        }
        // 再满足 10 秒（共 20 秒，但窗口已重置）
        for i in 10..<20 {
            detector.evaluate(hr: 58, motionStdDev: 0.01, at: start.addingTimeInterval(Double(i)))
        }

        // 窗口从第 10 秒重新计时，到第 20 秒刚好 10 秒，应该触发
        XCTAssertTrue(detected, "窗口重置后重新累计 10 秒应触发入睡")
    }

    // MARK: - 豁免生效：短暂中断不重置窗口

    func test_exemption_shortInterruptionDoesNotResetWindow() {
        let start = Date()
        detector.startSession(baselineHR: baseline, at: start)
        var detected = false
        detector.onEvent = { if case .sleepDetected = $0 { detected = true } }

        // 满足 7 秒
        for i in 0..<7 {
            detector.evaluate(hr: 58, motionStdDev: 0.01, at: start.addingTimeInterval(Double(i)))
        }
        // 中断 2 秒（在 3 秒豁免内）
        for i in 7..<9 {
            detector.evaluate(hr: 75, motionStdDev: 0.05, at: start.addingTimeInterval(Double(i)))
        }
        // 恢复，再满足 3 秒（总窗口时间 = 7 + 3 = 10 秒）
        for i in 9..<12 {
            detector.evaluate(hr: 58, motionStdDev: 0.01, at: start.addingTimeInterval(Double(i)))
        }

        XCTAssertTrue(detected, "短暂中断（≤豁免时长）不应重置窗口，应触发入睡")
    }

    // MARK: - 超时触发

    func test_timeout_firesAfterTimeoutDuration() {
        let start = Date()
        detector.startSession(baselineHR: baseline, at: start)
        var timedOut = false
        detector.onEvent = { if case .timedOut = $0 { timedOut = true } }

        // 一直不满足条件
        for i in 0..<65 {
            detector.evaluate(hr: 75, motionStdDev: 0.05,
                              at: start.addingTimeInterval(Double(i)))
        }

        XCTAssertTrue(timedOut, "超过 60 秒（测试配置的超时）应触发 timedOut 事件")
    }

    // MARK: - 超时后不再响应 evaluate

    func test_noEventAfterTimeout() {
        let start = Date()
        detector.startSession(baselineHR: baseline, at: start)
        var eventCount = 0
        detector.onEvent = { _ in eventCount += 1 }

        // 触发超时
        detector.evaluate(hr: 75, motionStdDev: 0.05, at: start.addingTimeInterval(61))
        let countAfterTimeout = eventCount

        // 超时后继续喂入满足条件的数据
        for i in 62..<80 {
            detector.evaluate(hr: 58, motionStdDev: 0.01, at: start.addingTimeInterval(Double(i)))
        }

        XCTAssertEqual(eventCount, countAfterTimeout, "超时后不应再触发任何事件")
    }
}
```

- [ ] **Step 3: 运行 SleepDetector 单元测试**

⌘U，选择 `SnapClockWatchTests` scheme
预期：7 个测试全部通过 ✓

如有失败，根据错误信息调整算法逻辑，直到全部通过。

- [ ] **Step 4: Commit**

```bash
git add "SnapClock Watch App/Services/SleepDetector.swift" SnapClockWatchTests/
git commit -m "feat: implement SleepDetector sliding-window algorithm with full unit tests"
```

---

## Task 7：会话编排（SleepSessionManager.swift）

**Files:**
- Create: `SnapClock Watch App/Services/SleepSessionManager.swift`

- [ ] **Step 1: 创建 SleepSessionManager.swift**

```swift
import Foundation
import WatchKit

/// 编排一次完整小睡会话：
/// 启动传感器 → 检测入睡 → 倒计时 → 震动唤醒 → 返回结果
@Observable
final class SleepSessionManager {

    // MARK: - Public State（Watch UI 绑定此状态）

    var state: WatchSessionState = .idle
    var remainingSeconds: TimeInterval = 0     // 倒计时剩余秒数
    var timeToSleepSeconds: TimeInterval = 0   // 距入睡已等待秒数（监测阶段显示）
    var lastResult: NapResult?

    // MARK: - Dependencies

    private let hrMonitor = HeartRateMonitor()
    private let motionMonitor = MotionMonitor()
    private let detector: SleepDetector
    private let haptic = HapticManager()
    var onSessionCompleted: ((NapResult) -> Void)?

    // MARK: - Internal

    private var config: NapConfig?
    private var sessionStartedAt: Date?
    private var sleepDetectedAt: Date?
    private var countdownTimer: Timer?
    private var monitoringTimer: Timer?
    private var baselineHRSamples: [Double] = []
    private var isCollectingBaseline = false

    // MARK: - Init

    init(detectorConfig: SleepDetectorConfig = SleepDetectorConfig()) {
        self.detector = SleepDetector(config: detectorConfig)
        self.detector.onEvent = { [weak self] event in
            DispatchQueue.main.async { self?.handleDetectorEvent(event) }
        }
    }

    // MARK: - Session Control

    func startSession(config: NapConfig) async throws {
        guard state == .idle else { return }
        self.config = config
        let now = Date()
        sessionStartedAt = now
        sleepDetectedAt = nil
        state = .monitoring

        try await hrMonitor.requestAuthorization()
        try await hrMonitor.start()
        motionMonitor.start()

        // 收集 30 秒基准心率
        isCollectingBaseline = true
        baselineHRSamples = []
        hrMonitor.onHeartRateSample = { [weak self] bpm in
            guard let self, self.isCollectingBaseline else { return }
            self.baselineHRSamples.append(bpm)
        }

        try await Task.sleep(for: .seconds(30))
        let baseline = baselineHRSamples.isEmpty ? 70 : baselineHRSamples.reduce(0, +) / Double(baselineHRSamples.count)
        isCollectingBaseline = false

        detector.startSession(baselineHR: baseline, at: now)

        // 启动监测定时器（每 5 秒 evaluate 一次）
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.evaluateOnce()
        }

        // 更新等待时长的显示定时器（每秒）
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] t in
            guard let self, self.state == .monitoring else { t.invalidate(); return }
            self.timeToSleepSeconds = Date().timeIntervalSince(self.sessionStartedAt ?? Date())
        }
    }

    func startManually() {
        monitoringTimer?.invalidate()
        motionMonitor.stop()
        let now = Date()
        sleepDetectedAt = now
        startCountdown(from: now, wasManual: true, didTimeout: false)
    }

    func cancelSession() {
        stopAll()
        state = .idle
    }

    // MARK: - Private

    private func evaluateOnce() {
        let hr = hrMonitor.lastHR
        let stdDev = motionMonitor.lastStdDev
        detector.evaluate(hr: hr, motionStdDev: stdDev, at: Date())
    }

    private func handleDetectorEvent(_ event: SleepDetectorEvent) {
        switch event {
        case .sleepDetected(let at):
            monitoringTimer?.invalidate()
            sleepDetectedAt = at
            startCountdown(from: at, wasManual: false, didTimeout: false)
        case .timedOut:
            monitoringTimer?.invalidate()
            let now = Date()
            sleepDetectedAt = nil
            startCountdown(from: now, wasManual: false, didTimeout: true)
        }
    }

    private func startCountdown(from sleepStart: Date, wasManual: Bool, didTimeout: Bool) {
        guard let config else { return }
        state = didTimeout ? .timedOut : .sleeping
        remainingSeconds = config.napDurationSeconds

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.remainingSeconds -= 1
            if self.remainingSeconds <= 0 {
                self.countdownTimer?.invalidate()
                self.finishSession(wasManual: wasManual, didTimeout: didTimeout)
            }
        }
    }

    private func finishSession(wasManual: Bool, didTimeout: Bool) {
        let now = Date()
        haptic.playWakeUp()

        let result = NapResult(
            sessionStartedAt: sessionStartedAt ?? now,
            sleepDetectedAt: sleepDetectedAt,
            napEndedAt: now,
            wasManual: wasManual,
            didTimeout: didTimeout
        )
        lastResult = result
        state = .completed
        stopAll()
        onSessionCompleted?(result)
    }

    private func stopAll() {
        monitoringTimer?.invalidate()
        countdownTimer?.invalidate()
        hrMonitor.stop()
        motionMonitor.stop()
    }
}
```

- [ ] **Step 2: 编译 Watch target 确认无报错（⌘B）**

- [ ] **Step 3: Commit**

```bash
git add "SnapClock Watch App/Services/SleepSessionManager.swift"
git commit -m "feat: implement SleepSessionManager orchestrating detection, countdown, and wake"
```

---

## Task 8：震动唤醒（HapticManager.swift）

**Files:**
- Create: `SnapClock Watch App/Services/HapticManager.swift`

- [ ] **Step 1: 创建 HapticManager.swift**

```swift
import WatchKit
import Foundation

/// 播放渐强震动序列唤醒用户（共 3 次，间隔 3 秒）
final class HapticManager {

    func playWakeUp() {
        let patterns: [WKHapticType] = [.notification, .directionUp, .success]
        for (index, hapticType) in patterns.enumerated() {
            let delay = Double(index) * 3.0
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                WKInterfaceDevice.current().play(hapticType)
            }
        }
    }

    func playConfirmation() {
        WKInterfaceDevice.current().play(.click)
    }
}
```

- [ ] **Step 2: 编译确认（⌘B）**

- [ ] **Step 3: Commit**

```bash
git add "SnapClock Watch App/Services/HapticManager.swift"
git commit -m "feat: implement HapticManager with graduated wake-up haptic sequence"
```

---

## Task 9：Watch Connectivity（双端通信）

**Files:**
- Create: `SnapClock Watch App/Services/WatchConnectivityManager.swift`
- Create: `SnapClock/Services/PhoneSessionManager.swift`

- [ ] **Step 1: 创建 WatchConnectivityManager.swift（Watch 侧）**

路径：`SnapClock Watch App/Services/`，Target：`SnapClock Watch App`

```swift
import Foundation
import WatchConnectivity

/// Watch 侧 WCSession：接收来自 iPhone 的 startNap/cancelNap 指令，
/// 会话结束后将 NapResult 发回 iPhone。
@Observable
final class WatchConnectivityManager: NSObject, WCSessionDelegate {

    var receivedConfig: NapConfig?
    var cancelRequested = false

    private let session = WCSession.default

    override init() {
        super.init()
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }

    // MARK: - 发送结果回 iPhone

    func sendResult(_ result: NapResult) {
        guard session.isReachable else {
            // iPhone 不在线，放入队列等待下次连接
            guard let data = try? JSONEncoder().encode(result) else { return }
            session.transferUserInfo([WCMessageKey.napResult: data])
            return
        }
        guard let data = try? JSONEncoder().encode(result) else { return }
        session.sendMessage([WCMessageKey.napResult: data], replyHandler: nil)
    }

    func sendStateUpdate(_ state: WatchSessionState) {
        guard session.isReachable else { return }
        session.sendMessage([WCMessageKey.sessionState: state.rawValue], replyHandler: nil)
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {}

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            if let data = message[WCMessageKey.startNap] as? Data,
               let config = try? JSONDecoder().decode(NapConfig.self, from: data) {
                self?.receivedConfig = config
            }
            if message[WCMessageKey.cancelNap] != nil {
                self?.cancelRequested = true
            }
        }
    }

    func session(_ session: WCSession,
                 didReceiveUserInfo userInfo: [String: Any]) {
        // iPhone 也可以通过 transferUserInfo 发指令（非实时场景）
        self.session(session, didReceiveMessage: userInfo)
    }
}
```

- [ ] **Step 2: 创建 PhoneSessionManager.swift（iPhone 侧）**

路径：`SnapClock/Services/`，Target：`SnapClock`

```swift
import Foundation
import WatchConnectivity

/// iPhone 侧 WCSession：向 Watch 发送 startNap 指令，接收 NapResult。
@Observable
final class PhoneSessionManager: NSObject, WCSessionDelegate {

    var latestResult: NapResult?
    var watchState: WatchSessionState = .idle
    var isWatchReachable = false

    private let session = WCSession.default

    override init() {
        super.init()
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }

    // MARK: - 发送指令给 Watch

    func sendStartNap(config: NapConfig) {
        guard let data = try? JSONEncoder().encode(config) else { return }
        if session.isReachable {
            session.sendMessage([WCMessageKey.startNap: data], replyHandler: nil)
        } else {
            session.transferUserInfo([WCMessageKey.startNap: data])
        }
    }

    func sendCancelNap() {
        guard session.isReachable else { return }
        session.sendMessage([WCMessageKey.cancelNap: true], replyHandler: nil)
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        DispatchQueue.main.async { self.isWatchReachable = session.isReachable }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { self.isWatchReachable = session.isReachable }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            if let data = message[WCMessageKey.napResult] as? Data,
               let result = try? JSONDecoder().decode(NapResult.self, from: data) {
                self?.latestResult = result
                self?.watchState = .completed
            }
            if let stateRaw = message[WCMessageKey.sessionState] as? String,
               let state = WatchSessionState(rawValue: stateRaw) {
                self?.watchState = state
            }
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        self.session(session, didReceiveMessage: userInfo)
    }

    // macOS 编译需要的空实现（watchOS Companion App 不需要，但协议要求）
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}
```

- [ ] **Step 3: 编译两个 target（⌘B）确认无报错**

- [ ] **Step 4: Commit**

```bash
git add "SnapClock Watch App/Services/WatchConnectivityManager.swift" SnapClock/Services/
git commit -m "feat: implement Watch Connectivity managers for both iPhone and Watch"
```

---

## Task 10：Watch UI（4 个视图）

**Files:**
- Modify: `SnapClock Watch App/SnapClockWatchApp.swift`
- Create: `SnapClock Watch App/Views/WatchHomeView.swift`
- Create: `SnapClock Watch App/Views/WatchMonitoringView.swift`
- Create: `SnapClock Watch App/Views/WatchCountdownView.swift`
- Create: `SnapClock Watch App/Views/WatchSummaryView.swift`

- [ ] **Step 1: 创建 Watch Views 组**

右键 `SnapClock Watch App` → New Group → `Views`

- [ ] **Step 2: 创建 WatchHomeView.swift**

```swift
import SwiftUI

struct WatchHomeView: View {
    @Binding var napMinutes: Int
    let onStart: () -> Void
    let onStartManual: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text("小睡时长")
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack {
                Button {
                    if napMinutes > 5 { napMinutes -= 5 }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)

                Text("\(napMinutes) 分")
                    .font(.title2.bold())
                    .frame(minWidth: 60)

                Button {
                    if napMinutes < 120 { napMinutes += 5 }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }

            Button("开始检测", action: onStart)
                .buttonStyle(.borderedProminent)
                .tint(.blue)

            Button("立即计时", action: onStartManual)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
```

- [ ] **Step 3: 创建 WatchMonitoringView.swift**

```swift
import SwiftUI

struct WatchMonitoringView: View {
    let waitingSeconds: TimeInterval
    let onCancel: () -> Void
    let onManual: () -> Void

    private var waitingText: String {
        let minutes = Int(waitingSeconds) / 60
        let seconds = Int(waitingSeconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        VStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(0.8)

            Text("检测入睡中")
                .font(.headline)

            Text("等待 \(waitingText)")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Divider()

            HStack(spacing: 12) {
                Button("手动", action: onManual)
                    .font(.caption)
                    .foregroundStyle(.blue)

                Button("取消", action: onCancel)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
    }
}
```

- [ ] **Step 4: 创建 WatchCountdownView.swift**

```swift
import SwiftUI

struct WatchCountdownView: View {
    let remainingSeconds: TimeInterval
    let timeToSleep: TimeInterval  // 入睡用时（秒）
    let isTimedOut: Bool

    private var remainingText: String {
        let total = Int(max(0, remainingSeconds))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    private var sleepLabel: String {
        if isTimedOut { return "超时自动计时" }
        let minutes = Int(timeToSleep) / 60
        let seconds = Int(timeToSleep) % 60
        return String(format: "%d分%02d秒后入睡", minutes, seconds)
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(remainingText)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()

            Text("剩余")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Divider()

            Text(sleepLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
```

- [ ] **Step 5: 创建 WatchSummaryView.swift**

```swift
import SwiftUI

struct WatchSummaryView: View {
    let result: NapResult
    let onDone: () -> Void

    private var sleepDelayText: String {
        guard let secs = result.timeToSleepSeconds else { return "未检测到" }
        let minutes = Int(secs) / 60
        return minutes > 0 ? "\(minutes) 分钟后入睡" : "不到 1 分钟入睡"
    }

    private var actualSleepText: String {
        let minutes = Int(result.actualSleepSeconds) / 60
        return "睡了 \(minutes) 分钟"
    }

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "moon.fill")
                .font(.title2)
                .foregroundStyle(.indigo)

            Text(actualSleepText)
                .font(.headline)

            Text(sleepDelayText)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button("完成", action: onDone)
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .padding(.top, 4)
        }
        .padding()
    }
}
```

- [ ] **Step 6: 更新 SnapClockWatchApp.swift（根视图 + 状态管理 + 连接 WCSession）**

```swift
import SwiftUI

@main
struct SnapClockWatchApp: App {
    @State private var sessionManager = SleepSessionManager()
    @State private var connectivity = WatchConnectivityManager()
    @State private var napMinutes: Int = 30

    var body: some Scene {
        WindowGroup {
            WatchRootView(
                sessionManager: sessionManager,
                napMinutes: $napMinutes
            )
            // 监听来自 iPhone 的 startNap 指令
            .onChange(of: connectivity.receivedConfig) { _, config in
                guard let config else { return }
                napMinutes = Int(config.napDurationSeconds / 60)
                Task {
                    try? await sessionManager.startSession(config: config)
                }
                connectivity.receivedConfig = nil  // 消费后清除
            }
            // 监听来自 iPhone 的 cancelNap 指令
            .onChange(of: connectivity.cancelRequested) { _, requested in
                if requested {
                    sessionManager.cancelSession()
                    connectivity.cancelRequested = false
                }
            }
        }
        .onAppear {
            // 会话结束后将结果发回 iPhone
            sessionManager.onSessionCompleted = { result in
                connectivity.sendResult(result)
            }
        }
    }
}

struct WatchRootView: View {
    @Bindable var sessionManager: SleepSessionManager
    @Binding var napMinutes: Int

    var body: some View {
        switch sessionManager.state {
        case .idle:
            WatchHomeView(
                napMinutes: $napMinutes,
                onStart: { Task { await startSession(manual: false) } },
                onStartManual: { Task { await startSession(manual: true) } }
            )

        case .monitoring:
            WatchMonitoringView(
                waitingSeconds: sessionManager.timeToSleepSeconds,
                onCancel: { sessionManager.cancelSession() },
                onManual: { sessionManager.startManually() }
            )

        case .sleeping, .timedOut:
            WatchCountdownView(
                remainingSeconds: sessionManager.remainingSeconds,
                timeToSleep: sessionManager.timeToSleepSeconds,
                isTimedOut: sessionManager.state == .timedOut
            )

        case .completed:
            if let result = sessionManager.lastResult {
                WatchSummaryView(result: result) {
                    sessionManager.state = .idle
                }
            }
        }
    }

    private func startSession(manual: Bool) async {
        let config = NapConfig(
            napDurationSeconds: Double(napMinutes) * 60,
            timeoutSeconds: NapConfig.defaultTimeout,
            startedAt: Date()
        )
        if manual {
            try? await sessionManager.startSession(config: config)
            sessionManager.startManually()
        } else {
            try? await sessionManager.startSession(config: config)
        }
    }
}
```

- [ ] **Step 7: 在 Watch 模拟器/真机上编译并手动验证 UI 跳转**

- 主页 → 按"开始检测"→ 进入监测中视图 ✓
- 监测中 → 按"手动"→ 进入倒计时视图 ✓
- 倒计时结束 → 进入摘要视图 ✓
- 摘要 → 按"完成"→ 返回主页 ✓

（在模拟器验证 UI 跳转，不需要真实传感器）

- [ ] **Step 8: Commit**

```bash
git add "SnapClock Watch App/"
git commit -m "feat: implement Watch UI with home, monitoring, countdown, and summary views"
```

---

## Task 11：iPhone 备用通知（BackupNotificationManager.swift）

**Files:**
- Create: `SnapClock/Services/BackupNotificationManager.swift`

- [ ] **Step 1: 创建 BackupNotificationManager.swift**

```swift
import Foundation
import UserNotifications

/// 在会话开始时注册一个兜底闹钟。
/// 触发时刻 = 超时保护上限 + 小睡时长 + 2分钟缓冲。
/// Watch 正常唤醒后调用 cancel() 取消此通知。
final class BackupNotificationManager {

    private let notificationID = "snapclock.backup.alarm"

    func schedule(for config: NapConfig) {
        let delay = config.backupNotificationDelay
        let content = UNMutableNotificationContent()
        content.title = "该醒了"
        content.body = "你的小睡时间到了"
        content.sound = .defaultCritical  // 使用关键声音，绕过静音

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(identifier: notificationID,
                                            content: content,
                                            trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [notificationID]
        )
    }
}
```

- [ ] **Step 2: 编译 iOS target（⌘B）确认无报错**

- [ ] **Step 3: Commit**

```bash
git add SnapClock/Services/BackupNotificationManager.swift
git commit -m "feat: implement BackupNotificationManager as fallback alarm for Watch session failure"
```

---

## Task 12：iPhone UI（3 个视图）

**Files:**
- Modify: `SnapClock/SnapClockApp.swift`
- Create: `SnapClock/Views/HomeView.swift`
- Create: `SnapClock/Views/SessionActiveView.swift`
- Create: `SnapClock/Views/SessionSummaryView.swift`

- [ ] **Step 1: 创建 HomeView.swift**

```swift
import SwiftUI

struct HomeView: View {
    @State private var napMinutes: Int = 30
    @State private var phoneSession = PhoneSessionManager()
    @State private var backupManager = BackupNotificationManager()
    @State private var isSessionActive = false

    private let presets = [15, 20, 25, 30, 45, 60]

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // 标题
                VStack(spacing: 4) {
                    Text("SnapClock")
                        .font(.largeTitle.bold())
                    Text("从入睡时开始计时")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 20)

                // 快捷时长选择
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                    ForEach(presets, id: \.self) { minutes in
                        Button("\(minutes) 分") {
                            napMinutes = minutes
                        }
                        .buttonStyle(.bordered)
                        .tint(napMinutes == minutes ? .blue : .secondary)
                    }
                }
                .padding(.horizontal)

                // 自定义时长
                Stepper(value: $napMinutes, in: 5...120, step: 5) {
                    Text("自定义：\(napMinutes) 分钟")
                        .font(.subheadline)
                }
                .padding(.horizontal)

                // 开始按钮
                Button {
                    startNap()
                } label: {
                    Text("开始小睡")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)

                // Watch 连接状态
                HStack {
                    Circle()
                        .fill(phoneSession.isWatchReachable ? .green : .red)
                        .frame(width: 8, height: 8)
                    Text(phoneSession.isWatchReachable ? "Apple Watch 已连接" : "Watch 未连接")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .navigationDestination(isPresented: $isSessionActive) {
                SessionActiveView(
                    phoneSession: phoneSession,
                    napMinutes: napMinutes,
                    onDismiss: { isSessionActive = false }
                )
            }
        }
        .onChange(of: phoneSession.watchState) { _, newState in
            if newState == .completed {
                isSessionActive = false
            }
        }
    }

    private func startNap() {
        let config = NapConfig(
            napDurationSeconds: Double(napMinutes) * 60,
            timeoutSeconds: NapConfig.defaultTimeout,
            startedAt: Date()
        )
        phoneSession.sendStartNap(config: config)
        backupManager.schedule(for: config)
        isSessionActive = true
    }
}
```

- [ ] **Step 2: 创建 SessionActiveView.swift**

```swift
import SwiftUI

struct SessionActiveView: View {
    @Bindable var phoneSession: PhoneSessionManager
    let napMinutes: Int
    let onDismiss: () -> Void
    @State private var backupManager = BackupNotificationManager()

    private var statusText: String {
        switch phoneSession.watchState {
        case .monitoring: return "Watch 正在检测入睡..."
        case .sleeping:   return "已入睡，倒计时中"
        case .timedOut:   return "超时自动计时中"
        case .completed:  return "小睡结束"
        case .idle:       return "等待 Watch 连接"
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: phoneSession.watchState == .monitoring ? "waveform" : "moon.fill")
                .font(.system(size: 60))
                .foregroundStyle(phoneSession.watchState == .monitoring ? .blue : .indigo)
                .symbolEffect(.pulse)

            Text(statusText)
                .font(.title3.bold())
                .multilineTextAlignment(.center)

            Text("目标：\(napMinutes) 分钟")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if phoneSession.watchState == .completed,
               let result = phoneSession.latestResult {
                NavigationLink("查看摘要") {
                    SessionSummaryView(result: result)
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer()

            Button("提前结束", role: .destructive) {
                phoneSession.sendCancelNap()
                backupManager.cancel()
                onDismiss()
            }
            .font(.subheadline)
            .padding(.bottom)
        }
        .padding()
        .navigationTitle("小睡进行中")
        .navigationBarBackButtonHidden(true)
        .onChange(of: phoneSession.watchState) { _, newState in
            if newState == .completed {
                backupManager.cancel()
            }
        }
    }
}
```

- [ ] **Step 3: 创建 SessionSummaryView.swift**

```swift
import SwiftUI

struct SessionSummaryView: View {
    let result: NapResult

    private var sleepDelayText: String {
        if result.wasManual { return "手动开始计时" }
        if result.didTimeout { return "45分钟未检测到入睡，自动开始" }
        guard let secs = result.timeToSleepSeconds else { return "未知" }
        let m = Int(secs) / 60
        let s = Int(secs) % 60
        return m > 0 ? "\(m) 分 \(s) 秒后入睡" : "\(s) 秒后入睡"
    }

    private var actualSleepText: String {
        let totalMin = Int(result.actualSleepSeconds) / 60
        let totalSec = Int(result.actualSleepSeconds) % 60
        return "\(totalMin) 分 \(totalSec) 秒"
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "moon.stars.fill")
                .font(.system(size: 70))
                .foregroundStyle(.indigo)

            VStack(spacing: 8) {
                Text("实际睡眠")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(actualSleepText)
                    .font(.title.bold())
            }

            VStack(spacing: 8) {
                Text("入睡情况")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(sleepDelayText)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(result.didTimeout ? .orange : .primary)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("本次小睡")
    }
}
```

- [ ] **Step 4: 更新 SnapClockApp.swift**

```swift
import SwiftUI
import UserNotifications

@main
struct SnapClockApp: App {
    init() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge, .criticalAlert]
        ) { _, _ in }
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}
```

- [ ] **Step 5: 在 iPhone 模拟器上运行，验证 UI 可正常显示**

Run → 选择 iPhone 模拟器（不需要真机，此步只验证 UI 不崩溃）
预期：主页正常显示，时长选择可操作

- [ ] **Step 6: Commit**

```bash
git add SnapClock/Views/ SnapClock/SnapClockApp.swift
git commit -m "feat: implement iPhone UI with home, active session, and summary views"
```

---

## Task 13：SwiftData 持久化（历史记录）

**Files:**
- Create: `SnapClock/Models/NapSession.swift`
- Modify: `SnapClock/SnapClockApp.swift`
- Modify: `SnapClock/Views/HomeView.swift`（添加上次记录显示）

- [ ] **Step 1: 创建 NapSession.swift**

路径：`SnapClock/Models/NapSession.swift`，Target：`SnapClock`

```swift
import Foundation
import SwiftData

/// SwiftData 持久化模型，存储历史小睡记录。
@Model
final class NapSession {
    var id: UUID
    var sessionStartedAt: Date
    var sleepDetectedAt: Date?
    var napEndedAt: Date
    var wasManual: Bool
    var didTimeout: Bool

    var timeToSleepSeconds: TimeInterval? {
        guard let detected = sleepDetectedAt else { return nil }
        return detected.timeIntervalSince(sessionStartedAt)
    }

    var actualSleepSeconds: TimeInterval {
        napEndedAt.timeIntervalSince(sleepDetectedAt ?? sessionStartedAt)
    }

    init(from result: NapResult) {
        self.id = UUID()
        self.sessionStartedAt = result.sessionStartedAt
        self.sleepDetectedAt = result.sleepDetectedAt
        self.napEndedAt = result.napEndedAt
        self.wasManual = result.wasManual
        self.didTimeout = result.didTimeout
    }
}
```

- [ ] **Step 2: 更新 SnapClockApp.swift（注入 modelContainer）**

```swift
import SwiftUI
import SwiftData
import UserNotifications

@main
struct SnapClockApp: App {
    init() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge, .criticalAlert]
        ) { _, _ in }
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        .modelContainer(for: NapSession.self)
    }
}
```

- [ ] **Step 3: 更新 HomeView.swift（接收并存储结果，显示上次记录）**

在 `HomeView` 的 `@State` 列表中添加：

```swift
@Environment(\.modelContext) private var modelContext
@Query(sort: \NapSession.napEndedAt, order: .reverse) private var sessions: [NapSession]
```

在 `startNap()` 结束后，在 `onChange(of: phoneSession.watchState)` 中保存：

```swift
.onChange(of: phoneSession.watchState) { _, newState in
    if newState == .completed {
        isSessionActive = false
        if let result = phoneSession.latestResult {
            let session = NapSession(from: result)
            modelContext.insert(session)
        }
    }
}
```

在主页底部（`Spacer()` 上方）添加上次记录显示：

```swift
if let last = sessions.first {
    Divider()
    VStack(spacing: 4) {
        Text("上次小睡")
            .font(.caption)
            .foregroundStyle(.secondary)
        let mins = Int(last.actualSleepSeconds) / 60
        Text("睡了 \(mins) 分钟")
            .font(.subheadline.bold())
    }
    .padding(.bottom, 8)
}
```

- [ ] **Step 4: 编译 iOS target（⌘B）确认无报错**

- [ ] **Step 5: Commit**

```bash
git add SnapClock/Models/ SnapClock/SnapClockApp.swift SnapClock/Views/HomeView.swift
git commit -m "feat: add SwiftData persistence for nap session history with last-session display"
```

---

## Task 14：端到端集成测试（真机）

**Files:** 无新文件，纯手动测试

- [ ] **Step 1: 在 iPhone + Apple Watch 真机上部署两个 App**

Xcode → Product → Run，选择你的 iPhone（Watch App 会自动同步安装到已配对的 Watch）

- [ ] **Step 2: 验证完整流程（主流程）**

```
1. 打开 iPhone App → 选择 30 分钟 → 点"开始小睡"
2. 确认 iPhone 进入"小睡进行中"页面
3. 打开 Apple Watch → 确认进入"检测入睡中"页面
4. 戴好手表，躺下闭眼 10～20 分钟
5. 确认 Watch 在检测到入睡后切换为倒计时界面
6. 等待倒计时结束（或按手动直接测试）
7. 确认 Watch 震动唤醒（3次渐强）
8. 确认 Watch 显示摘要（入睡用时 + 实际睡眠时长）
9. 确认 iPhone 收到同步结果并显示摘要
10. 确认 iPhone 主页显示"上次小睡"记录
```

- [ ] **Step 3: 验证备用通知（兜底流程）**

```
1. 开始一次小睡会话（设 5 分钟，超时设小以便测试）
2. 在 Watch 上立即取消会话
3. 等待 iPhone 备用通知弹出（= 配置的 backupNotificationDelay 秒后）
4. 确认通知到达
```

- [ ] **Step 4: 验证手动模式**

```
1. 开始会话 → Watch 显示监测中 → 点"立即计时"
2. 确认直接进入倒计时，不等待入睡检测
```

- [ ] **Step 5: 记录传感器数据（算法调优准备）**

在 `SleepSessionManager` 中临时加入 debug log：

```swift
// 在 evaluateOnce() 中添加：
print("[SnapClock] HR: \(String(format: "%.1f", hrMonitor.lastHR)) | Motion: \(String(format: "%.4f", motionMonitor.lastStdDev)) | Window: \(detector.isWindowActive ? "active" : "none")")
```

躺下真实测试，采集 Xcode Console 中的数据，根据实际心率和动作数值调整 `SleepDetectorConfig` 的阈值。

- [ ] **Step 6: 移除 debug log 并 commit**

```swift
// 移除上一步临时加入的 print 语句
```

```bash
git add "SnapClock Watch App/Services/SleepSessionManager.swift"
git commit -m "feat: complete end-to-end integration test and threshold calibration"
```

---

## 总结

**MVP 完成标准：**
- [ ] Watch 能自主检测入睡（心率 + 动作双条件）并开始倒计时
- [ ] 倒计时结束后震动唤醒（3次渐强）
- [ ] iPhone 备用通知在 Watch 失败时兜底唤醒
- [ ] 会话结果同步到 iPhone 并持久化
- [ ] iPhone 和 Watch 双端 UI 完整可用

**算法调优参考值（根据真实数据可能需要调整）：**

| 参数 | 默认值 | 调整方向 |
|---|---|---|
| `hrDropFactor` | 0.88 | 若漏判增大（如 0.90），若误判减小（如 0.85） |
| `hrAbsoluteMax` | 65 bpm | 若本人静息心率偏低则调低 |
| `motionStdDevMax` | 0.02g | 若静躺时经常中断则调大（如 0.03） |
| `windowDuration` | 180 秒 | 若检测太慢可降至 120 秒 |
| `exemptionDuration` | 30 秒 | 若翻身频繁则调大 |
