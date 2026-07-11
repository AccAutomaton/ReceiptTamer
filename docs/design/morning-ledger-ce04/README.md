# ReceiptTamer「晨雾账簿」当前 Flutter Golden

> **当前实现预览。** 页面功能、内容、文案与交互以 commit `ce04b3c` 为基线；
> 本目录只负责陈列真实 Flutter Golden，不包含 HTML 重绘的应用界面。

打开 [`index.html`](index.html) 查看预览。

## 当前覆盖

- 页面：首页，共 1 个实际 Flutter 页面。
- 视口：`412×915`（android_regular）、`360×800`（android_compact）。
- 主题：浅色、暗色。
- 文本缩放：`1.0`、`1.3`、`2.0`。
- 合计：12 个变体。

Gallery 中的图片全部通过相对路径直接引用
`test/goldens/baselines/home-*.png`，没有复制或二次加工图片。点击任一预览可打开原始
Golden。

## 边界

本 Gallery 不能被描述为“全界面预览”：目前只有首页落地了 12 张实际 Golden。旧的
`ledger-redesign`、`fresh-redesign`、`hybrid-redesign` 是保留的历史设计探索，不代表当前
Flutter 实现。

更新界面视觉后，应先人工确认差异，再按照 `test/goldens/README.md` 的说明更新 Golden；
不要为了让测试通过而无条件覆盖基线。
