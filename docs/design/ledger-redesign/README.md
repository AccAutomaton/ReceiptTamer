# ReceiptTamer「墨色账簿」设计预览（历史探索）

> **状态：已否决，不代表当前 Flutter 实现。** 当前方案保持 `ce04b3c` 的页面功能、
> 内容与文案，仅采用晨雾视觉；请查看[当前真实 Flutter Golden](../morning-ledger-ce04/index.html)。

这套画板曾作为 Flutter 全量视觉迁移前的设计稿，覆盖 28 个路由、已保存文件页、中央新增面板，以及关键媒体预览和维护弹层，现仅保留用于追溯设计过程。

## 设计语言

- **票据白** `#F4F5F2`：主画布与浅色模式基础。
- **复写纸** `#E7EAE6`：分组、选中和弱层级背景。
- **墨黑** `#151A1C`：主文字与关键操作。
- **石墨** `#5A6265`：辅助文字和非关键数据。
- **财务青** `#1D7074`：导航、关联、成功与可操作状态。
- **印泥红** `#A94C44`：只用于危险或不可逆操作。

标题使用 Noto Serif SC，正文使用 Noto Sans SC/MiSans，编号使用 Courier Prime。票据撕边只出现在月度汇总、导出结果等关键位置，列表主体保持稳定、低成本的实色台账面。

## 画板目录

1. `board-01.html`：全局框架与首页
2. `board-02.html`：订单流程
3. `board-03.html`：发票流程
4. `board-04.html`：媒体与识别
5. `board-05.html`：开票助手与分享导入
6. `board-06.html`：完整报销材料导出
7. `board-07.html`：快捷导出与结果
8. `board-08.html`：设置与信息
9. `board-09.html`：数据清理
10. `board-10.html`：维护弹层

附录 `compact-check.html` 使用 360×800 视口复核首页、台账列表、编辑底栏与暗色危险弹层。

## 渲染

画板使用本地字体和 HTML/CSS 绘制，不依赖网络资源。仓库通过
`package.json` 与 `pnpm-lock.yaml` 固定渲染依赖；安装 Node.js 20+ 与
Chrome/Edge 后，在仓库根目录运行：

```powershell
corepack enable
pnpm install --frozen-lockfile
pnpm run render:design:ledger
```

渲染结果写入 `docs/design/ledger-redesign/rendered/`。渲染脚本会在画板数量不是 10 张时失败，防止漏页。

## 评审口径

- 每个核心界面必须拥有完整的 412×915 手机框，而不是只出现于流程图或弹层缩略图。
- 弹层必须叠在真实来源页面上。
- 浅色覆盖完整路径；暗色至少覆盖首页、列表、编辑、媒体预览和危险操作。
- 画板确认前不迁移 Flutter 页面，避免长期并存两套视觉。
