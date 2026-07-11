# ReceiptTamer「晨雾编目 · 骑缝索引」方向预览

> EXPLORATION · NOT CURRENT FLUTTER
>
> STATUS: REJECTED — 用户不接受“一屏一张连续大卡”的感受。后续方向见
> `../morning-ledger-relief-island-preview/index.html`。

本目录只用于确认“比当前晨雾稿更激进、但不回到此前大重构”的视觉力度，尚未迁移到 Flutter。

- 页面功能、内容、文案和操作边界严格以 Commit ce04b3c6457f444645a4bd6cca98d5e71707115d 为基线。
- 允许改变排版节奏、卡片组织、视觉层级和导航材质，不新增、删减或改写任何页面信息。
- 唯一视觉签名是每屏最多一枚“骑缝索引签”；不使用撕边、纸纹、印章、玻璃卡或常驻动画。
- 四张画板各包含三个 412×915 手机框；compact-check.html 额外验证三个 360×800 状态。

打开 index.html 查看总览；rendered 目录中的 PNG 由 tools/render_morning_ledger_mid_bold.cjs 确定性生成。

安装 Node.js 20+ 与 Chrome/Edge 后，在仓库根目录使用锁定依赖重新渲染：

    corepack enable
    pnpm install --frozen-lockfile
    pnpm run render:design:mid-bold
