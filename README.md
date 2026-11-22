# 同窝 Covey · 宠物日常 iOS 应用

围绕"人和宠物一起生活的日常"的原生 iOS 应用：记录顺手、照护安心、AI 在合适的时候帮一步。SwiftUI 实现，数据保存在本机（UserDefaults）。

## 目录

- `ios/` — 原生 iOS 应用（SwiftUI，无第三方依赖）
- `web/` — 同一产品定位的浏览器原型（无构建，localStorage）

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

## 功能

| 页面 | 内容 |
| --- | --- |
| 今日 | 照护清单（按物种自动生成：猫含清理猫砂、狗含遛弯）、一键完成/撤销、连续照顾天数、近 7 天完成率、体重概览、待办提醒、Pawly 观察、拍照/记一笔/AI 建议快捷入口 |
| 记录 | 时间线手账按天分组；筛选（照片/花费/照护/健康/日常）与搜索；照片可放大；长按删除 |
| AI 助手 | 对话式 Pawly，系统提示词注入宠物档案、近 14 天照护、最近记录、体重与待办提醒；快捷提问；「让 AI 分析」从今日页直达并自动提问；需在「我的」中配置 API |
| 宠物 | 档案编辑（名字/物种/品种/生日/体重）、体重记录、家庭成员切换（本机演示） |
| 我的 | **AI API 配置置顶**：服务商预设（DeepSeek/OpenAI/智谱/通义/自定义）、地址、Key、模型、测试连接；数据导出到文件 / 导入 / 清空 |

## AI 配置

「我的 → AI 助手设置」填服务商预设的 API 地址、Key 和模型（OpenAI 兼容 chat/completions）。原生 App 直接调用接口，不受浏览器 CORS 限制；配置仅保存在本机。

## 数据

- 全部数据存于 UserDefaults（键 `covey-state-v1`），单设备。
- 照片压缩（最长边 900px、JPEG 75%）存储；记录上限 800 条。
- 「我的 → 数据」导出 JSON 到 App 文档目录，或从文件导入恢复。

## 设计说明

UI 为重新设计：暖纸色底 + 陶土橙主色 + 卡片布局，与参考原型无代码/视觉继承关系。
