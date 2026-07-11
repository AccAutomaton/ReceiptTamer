# ReceiptTamer「晨雾票夹」方向稿（历史探索）

> **状态：信息减法方案已否决，不代表当前 Flutter 实现。** 当前实现只采用其晨雾视觉，
> 页面功能、内容与文案仍以 `ce04b3c` 为基线；请查看
> [当前真实 Flutter Golden](../morning-ledger-ce04/index.html)。

这是针对“墨色账簿信息密度偏高”的独立比较稿，未迁移到 Flutter 实现。

- `index.html`：墨色账簿与晨雾票夹的视觉、信息层级对比。
- `board-01.html`：6 个 412×915 代表界面，覆盖首页、订单、中央新增、详情、编辑和设置。
- `shared.css`：清新风独立设计系统，不继承墨色账簿样式。
- `rendered/board-01.png`：可复现的清新风整板截图。
- `rendered/comparison.png`：对比页的完整截图。
- `tools/render_fresh_design.cjs`：使用本机 Chrome/Edge 的 Playwright 渲染脚本。

本稿的核心不是换色，而是渐进披露：普通用户默认只看到金额、待办和下一步，编号、OCR、文件属性、模型与版本信息仍保留在二级位置。

在安装 Node.js 20+ 与 Chrome/Edge 后，可从仓库根目录使用锁定依赖重新渲染：

```powershell
corepack enable
pnpm install --frozen-lockfile
pnpm run render:design:fresh
```
