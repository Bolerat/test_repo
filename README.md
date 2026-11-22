# 同窝 Covey · 宠物日常应用

围绕"人和宠物一起生活的日常"的原生应用：记录顺手、AI 在合适的时候帮一步。iOS（SwiftUI）与 Android（Kotlin + Jetpack Compose）同步开发，数据保存在本机。

## 目录

- `ios/` — iOS 应用（SwiftUI，无第三方依赖）
- `android/` — Android 应用（Kotlin + Compose，debug 包名 `com.bolerat.covey`）

## iOS 运行

需要 Xcode 26+。

```bash
cd ios
xcodegen                       # 生成 Covey.xcodeproj（仓库已包含生成结果，可跳过）
open Covey.xcodeproj
```

选择 iPhone 模拟器（如 iPhone 17）运行，或：

```bash
xcodebuild -project Covey.xcodeproj -scheme Covey \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

## Android 运行

需要 JDK 17+ 与 Android SDK（platform 34）。

```bash
cd android
ANDROID_HOME=$HOME/Library/Android/sdk ~/gradle-8.9/bin/gradle assembleDebug
# 产物：android/app/build/outputs/apk/debug/app-debug.apk
```

## 功能

| 页面 | 内容 |
| --- | --- |
| 今日 | 宠物名片头图（头像进度环=今日记录数）、连续记录天数、近 7 天记录数、7 天内待办提醒、体重概览、Pawly 观察、拍照/记一笔/AI 建议快捷入口 |
| 记录 | 时间线手账按天分组；筛选（照片/花费/健康/笔记）与搜索；照片可放大；可删除 |
| AI 助手 | 对话式 Pawly，系统提示词注入宠物档案、近 14 天记录概况、最近记录、体重与待办提醒；语气可在设置中选择（温暖陪伴/活泼俏皮/简洁利落/冷静专业）；快捷提问；「让 AI 分析」从今日页直达并自动提问 |
| 宠物 | 档案编辑（名字/物种/品种/生日/体重）、体重记录、家庭成员切换（本机演示） |
| 设置 | **AI API 配置置顶**：服务商预设（DeepSeek/OpenAI/智谱/通义/自定义）、地址、Key、模型、语气、测试连接；Pawly 提醒开关；宠物与亲友入口；Pawly 的记忆说明；数据导出/导入/清空 |

## AI 配置

「设置 → AI 助手」填服务商预设的 API 地址、Key 和模型（OpenAI 兼容 chat/completions），并选择 AI 语气。原生 App 直接调用接口；配置仅保存在本机，新版本不会覆盖已有配置。

## 数据

- 全部数据存于本机（iOS 用 UserDefaults、Android 用 SharedPreferences，键均为 `covey-state-v1`，JSON 结构一致，逐字段容错解码），单设备。
- 照片压缩后存储；记录有上限。
- 设置里可导出 JSON / 导入恢复 / 清空。

## 设计说明

UI 为重新设计：暖纸色底 + 陶土橙主色 + 卡片布局，与参考原型无代码/视觉继承关系。
