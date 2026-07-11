# Android 视觉回归验收

本目录保存 ReceiptTamer「晨雾账簿」的可复现截图验收资产。页面内容、文案、功能、
路由和交互入口以提交
`ce04b3c6457f444645a4bd6cca98d5e71707115d` 为不可变基线；本目录只允许验证颜色、
材质、字体、圆角、间距、阴影和动效等视觉换肤结果。

设计预览只提供“晨雾账簿”的视觉参考，不是页面内容来源。若预览稿与 `ce04b3c`
不同，应保留 `ce04b3c` 的界面内容。长期源契约位于 `test/ui_contract/`，会阻止页面
文案、功能源文件或路由被视觉改造意外修改。

## 固定条件

- 内容与功能基线：`ce04b3c6457f444645a4bd6cca98d5e71707115d`
- 固定时钟：`2026-07-10 10:24:00 +08:00`
- 视口：Android 常规 `412×915`、紧凑 `360×800`
- 主题：light、dark
- 文本缩放：`1.0`、`1.3`、`2.0`
- 设备像素比：`1.0`（Golden 文件按逻辑像素输出，避免主机缩放差异）
- 动效：测试中启用系统“减少动态效果”
- 字体：只使用仓库内随应用分发的字体

`scenarios/manifest.json` 是 30 个核心截图目标的清单：28 个既有 GoRouter 路由、
非 GoRouter 的 `SavedFilesScreen`，以及 `ce04b3c` 原有的中央添加底部面板。该面板
只包含原来的“添加订单”和“添加发票”两个入口及其原文案，不加入分享导入等新内容。

manifest 描述的是待覆盖场景，不代表 30 个场景都已经生成 Flutter Golden。新增截图
状态时，只能从 `ce04b3c` 已存在的页面状态中选择；不得借截图清单引入月度账单首页、
额外列表加载机制、改写后的状态标签或新的页面操作。

## 目录

- `fixtures/ledger_visual_fixtures.dart`：固定时钟、脱敏订单/发票及运行时生成的匿名
  PNG/PDF 媒体；文件名沿用历史命名，不表示页面采用墨色账簿的信息结构。
- `harness/ledger_golden_harness.dart`：统一视口、主题、文本缩放、语言和动效设置。
- `scenarios/manifest.json`：以 `ce04b3c` 为内容基线的 30 个截图目标及覆盖矩阵。
- `baselines/`：16 张晨雾账簿 Flutter Golden；其中首页 12 张覆盖双视口×浅暗色×
  1.0/1.3/2.0，主壳材质 4 张覆盖双视口×浅暗色×1.0。
- `manifest_contract_test.dart`：保证场景数、既有路由和矩阵不会静默缺失。
- `ledger_representative_golden_test.dart`：渲染真实 `HomeScreen`；首页仍显示原有的
  订单总数、发票总数、快捷功能和最近订单。
- `relief_shell_component_golden_test.dart`：使用确定性测试夹具同屏渲染真实晨雾背景、
  订单标题、两枚顶部浮签、月份实体面、三张实体卡和底部导航岛，专门约束首页 Golden
  尚未覆盖的 54/51dp 岛内同高中央新增与主壳材质。

## 运行

```powershell
# 验证 manifest、夹具和现有 Golden
flutter test test/goldens

# 仅在人工确认“只改变视觉”后更新代表性基线
flutter test --update-goldens test/goldens/ledger_representative_golden_test.dart

# 仅更新双视口×浅暗色的 4 张主壳材质基线
flutter test --update-goldens test/goldens/relief_shell_component_golden_test.dart
```

不要在普通修复中无条件更新 Golden。更新前应同时确认：

1. `test/ui_contract/` 仍通过，页面内容和功能源没有变化；
2. 截图中的文案与 `ce04b3c` 一致；
3. 像素差异仅来自晨雾账簿视觉。

CI 应执行第一条命令，且不使用 `--update-goldens`。

## 当前接入边界

现有 12 张首页 Golden 直接渲染真实 `HomeScreen`，订单和发票仓库由测试 Provider
覆盖。首页内容保持 `ce04b3c` 的结构，不包含墨色重构曾提出的月度账单、月份选择器或
月度统计。另有 4 张主壳组件 Golden 使用测试专属内容夹具，不代表新增页面业务内容；
它们只验证 `LiquidGlassBackground`、实体层、顶部浮签和 `GlassNavigationBar` 的组合材质。

其余 manifest 场景仍有文件、PackageInfo、分享、模型下载、更新、备份和系统权限服务在
页面内直接构造或依赖 MethodChannel。为了保持测试不联网且不修改业务源，本目录暂未用
全局 mock 强行生成这些页面的 Golden。相关服务未来具备可覆盖测试边界后，可复用同一
harness；接入过程仍不得改变 `ce04b3c` 页面内容。
