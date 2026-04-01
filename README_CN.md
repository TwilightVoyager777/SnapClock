# SnapClock 安心午睡

**从你真正入睡的那一刻开始计时。**

SnapClock 是一款 iPhone + Apple Watch 联动的睡眠计时应用。通过 Apple Watch 的心率和腕部运动传感器检测你的入睡时刻，倒计时从检测到入睡后才正式开始。再也不会因为迟迟睡不着而浪费你的午睡时间。

---

## 功能特性

- **自动入睡检测** — Apple Watch 持续监测心率与腕部运动。当心率下降、动作停止后，倒计时自动启动。
- **精准倒计时** — 基于真实时间戳计算剩余时间，而非单纯逐秒递减。即使表盘熄屏，计时依然准确。
- **手动与超时模式** — 可随时手动开始计时；若 45 分钟内未检测到入睡，倒计时自动启动。
- **备用通知** — iPhone 侧设置本地通知作为兜底闹钟，防止 Watch 会话意外中断。
- **小睡记录** — 每次会话通过 SwiftData 持久化，支持查看历史记录与质量评分。
- **Apple 健康风格详情页** — 点击任意历史记录查看评分圆环（0–100）、统计卡片、睡眠时间轴。
- **中英文切换** — 随时在主页右上角切换中文 / English 界面。
- **深空睡眠风格 UI** — 深海军蓝渐变背景、薰衣草紫色调、呼吸动画光晕。

---

## 系统要求

| 设备 | 最低版本 |
|------|---------|
| iPhone | iOS 17 |
| Apple Watch | watchOS 10（Series 7 或更新） |
| Xcode | 15+ |
| Swift | 5.9+ |

> 使用前需在 Apple Watch 上授权 HealthKit（心率读取）和运动与健身（加速度计）权限。

---

## 工作原理

### 入睡检测算法

1. **基准采集（30 秒）** — 会话开始后，Watch 采集 30 秒心率样本，计算个人基准 BPM。
2. **滑动窗口评估（每 5 秒）** — 180 秒滑动窗口持续追踪心率样本与腕部运动标准差。
3. **入睡触发条件**（三项同时满足，持续一整个窗口）：
   - 心率较基准下降 ≥ 12%
   - 心率低于 65 bpm
   - 腕部运动标准差 < 0.02 g
4. **30 秒豁免期** — 会话开始后最初 30 秒不参与判断，避免躺下时的误触发。
5. **45 分钟超时保护** — 若 45 分钟内未检测到入睡，倒计时自动开始。

### 倒计时机制

Watch 在入睡检测时记录时间戳，每次 Timer 触发时通过 `endDate.timeIntervalSinceNow` 实时计算剩余时间。无论系统节流还是表盘熄屏，倒计时始终与真实时间一致。

### iPhone ↔ Watch 通信

- **iPhone → Watch**：`startNap`（NapConfig JSON）和 `cancelNap`，通过 WatchConnectivity 发送，Watch 离线时自动切换 `transferUserInfo` 队列。
- **Watch → iPhone**：每次状态变化（检测中 / 已入睡 / 超时 / 完成）实时推送 `sessionState`；会话结束后发送完整 `NapResult`。

---

## 项目结构

```
SnapClock/
├── SnapClock/                       # iPhone 端
│   ├── SnapClockApp.swift           # App 入口，TabView 根视图，SwiftData 容器
│   ├── HomeView.swift               # 主页：时长选择、开始按钮
│   ├── SessionActiveView.swift      # 会话进行中：呼吸光晕动画
│   ├── SessionSummaryView.swift     # 会话结束：本次结果
│   ├── NapHistoryView.swift         # 历史记录列表
│   ├── NapDetailView.swift          # Apple 健康风格会话详情
│   ├── NapSession.swift             # SwiftData 模型 + NapQuality 枚举
│   ├── PhoneSessionManager.swift    # WCSession iPhone 端
│   ├── BackupNotificationManager.swift # 备用本地通知
│   └── SharedTypes.swift            # NapConfig / NapResult / WCMessageKey（双端共享）
│
└── SnapClockWatch Watch App/        # watchOS 端
    ├── SnapClockWatchApp.swift      # Watch 入口，状态路由
    ├── SleepSessionManager.swift    # 会话编排主控
    ├── SleepDetector.swift          # 滑动窗口入睡检测算法
    ├── HeartRateMonitor.swift       # HKWorkoutSession + HKAnchoredObjectQuery
    ├── MotionMonitor.swift          # CMMotionManager，5 秒标准差
    ├── HapticManager.swift          # 递进震动唤醒
    ├── WatchConnectivityManager.swift
    ├── WatchHomeView.swift
    ├── WatchMonitoringView.swift
    ├── WatchCountdownView.swift
    └── WatchSummaryView.swift
```

---

## 安装与运行

1. 克隆本仓库。
2. 用 Xcode 打开 `SnapClock/SnapClock.xcodeproj`。
3. 在 **Signing & Capabilities** 中为 iPhone 和 Watch 两个 Target 分别设置开发者团队。
4. 选择 iPhone + 已配对 Apple Watch 作为运行目标。
5. `⌘R` 编译运行，在 Watch 上按提示授权 HealthKit 和运动权限。

> **提示**：`SharedTypes.swift` 需同时属于两个 Target。若 Xcode 未自动添加，请在 File Inspector 中手动勾选两端的 Target Membership。

---

## 质量评分说明

| 徽章 | 标签 | 判断条件 |
|------|------|---------|
| 优 / S | 深度 | 检测到入睡，且不到 10 分钟入睡 |
| 良 / A | 良好 | 检测到入睡，10–20 分钟内入睡 |
| 中 / B | 一般 | 超时自动开始，或超过 20 分钟才入睡 |
| 手 / M | 手动 | 手动开始计时 |

评分公式（0–100）：`90 − 2 × max(0, 入睡分钟数 − 3)`，结果限制在 `[30, 95]`。

---

## 许可

本项目供个人使用，未在 App Store 发布。
