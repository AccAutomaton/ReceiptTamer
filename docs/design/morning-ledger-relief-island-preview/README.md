# ReceiptTamer「晨雾浮签 · 实体层与悬浮岛」设计基准

> IMPLEMENTED · FLUTTER VISUAL BASELINE

本方向已迁移到 Flutter。HTML/SVG 画板继续作为设计基准，真实实现以 `lib/core/theme/`、`lib/presentation/widgets/common/` 与 `test/goldens/baselines/` 为准。

- 页面功能、内容、文案和操作边界严格以 Commit `ce04b3c6457f444645a4bd6cca98d5e71707115d` 为基线。
- 四张画板沿用上一版 12 个手机状态；`compact-check.html` 额外覆盖三个 360×800 状态。
- 内容区使用完全不模糊、`opacity: 1` 的实体层；列表和字段文字不会置于滤镜或整体透明容器中。
- 仅右上操作组、返回按钮、面板、对话框和底部导航属于浮控件：背景不透明度为 92%–94%，模糊半径不超过 12px。
- 底部导航改为与屏幕四周留距的悬浮岛；中央新增与四个目的地保持同一垂直基线，不再越出岛面；浅色、暗色、危险确认和紧凑视口均单独验收。

打开 `index.html` 查看已迁移 Flutter、上一版 mid-bold 与本设计基准的对照。`rendered/` 中的 PNG 由 `tools/render_morning_ledger_relief_island.cjs` 确定性生成。

安装 Node.js 20+ 与 Chrome/Edge 后，在仓库根目录使用锁定依赖重新渲染：

    corepack enable
    pnpm install --frozen-lockfile
    pnpm run render:design:relief-island

渲染器同时检查新旧手机 DOM 等价、滤镜白名单与半径、浮层背景透明度、所有手机元素的计算透明度、悬浮岛实际边距、中央新增同高约束、暗色/危险状态，以及图片和页面运行错误。
