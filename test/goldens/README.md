# Android 视觉回归验收

本目录保存 ReceiptTamer「报销装订轨」的可复现 Flutter 截图资产。当前信息架构与
视觉来源是 `docs/design/reimbursement-binding-preview/`；长期行为由首页、账页、报销
流程的单元与 Widget 测试约束，视觉由本目录的真实 Golden 约束。

## 固定条件

- 固定时钟：`2026-07-10 10:24:00 +08:00`
- 视口：Android 常规 `412×915`、紧凑 `360×800`
- 主题：light、dark
- 文本缩放：`1.0`、`1.3`、`2.0`
- 设备像素比：`1.0`
- 动效：启用系统“减少动态效果”
- 字体：Tinos + Noto Serif SC，全部从仓库资产加载

`scenarios/manifest.json` 保存 31 个路由、屏幕和新增面板候选截图目标。它是覆盖计划，
不代表全部目标都已经生成 Golden。

## 当前基线

- `ledger_representative_golden_test.dart`：12 张真实首页，覆盖双视口、浅暗色和
  1.0/1.3/2.0 字号；约束三栏开票助手、最近订单纸页与雾边重排。
- `relief_shell_component_golden_test.dart`：4 张主壳组件，覆盖连续月账页、四个连续
  目的地和右侧独立 72/68dp 新增键。
- `reimbursement_check_golden_test.dart`：3 张关系检查页，覆盖常规、紧凑及暗色
  2.0× 字号下的范围摘要、范围外闭包和固定底部操作。

目前共有 19 张可比较 PNG。

## 运行

```powershell
flutter test test/goldens
flutter test --update-goldens test/goldens/ledger_representative_golden_test.dart
flutter test --update-goldens test/goldens/relief_shell_component_golden_test.dart
flutter test --update-goldens test/goldens/reimbursement_check_golden_test.dart
```

更新基线前必须先运行 `flutter test test/home_overview_test.dart
test/ledger_month_sheet_test.dart test/reimbursement_ui_flow_test.dart`，人工核对 412/360、
浅暗色和大字体截图，并删除 `test/goldens/failures/` 中的临时差异图。不得用更新 PNG
掩盖功能、路由或文案回归。
