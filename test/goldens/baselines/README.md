# Golden 基线

此目录保存 16 张人工确认的 PNG：12 张首页基线覆盖双视口、浅/暗色及
1.0/1.3/2.0 字号，另有 4 张主壳材质基线覆盖 412×915、360×800 的浅/暗色 1.0
字号。首页图片展示“晨雾账簿”视觉，但内容严格沿用
`ce04b3c6457f444645a4bd6cca98d5e71707115d`：订单总数、发票总数、四项原有快捷功能
和最近订单；不包含月度账单、月份选择器或新增快捷入口。

`relief-shell-*.png` 使用测试专属订单夹具，同屏约束晨雾背景、顶部浮签、实体月份面、
实体订单卡和底部悬浮岛（含岛内同高中央新增）。它们不定义业务页面内容，只补足首页 Golden 未渲染
`MainShell` 导航材质的覆盖缺口。

使用下列命令生成或更新：

```powershell
flutter test --update-goldens test/goldens/ledger_representative_golden_test.dart
flutter test --update-goldens test/goldens/relief_shell_component_golden_test.dart
```

更新前必须先运行 `flutter test test/ui_contract`，并人工确认差异只有视觉换肤。不要提交
临时失败差异图，也不要通过更新 PNG 掩盖页面文案、内容或功能入口的变化。
