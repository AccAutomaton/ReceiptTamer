# ReceiptTamer「晨雾账簿」混合方向（历史探索）

> **状态：已否决，不代表当前 Flutter 实现。** 该稿以“墨色账簿”重构后的内容结构为
> 基线；当前实现改为保持 `ce04b3c` 原页面功能、内容与文案，仅采用晨雾视觉。请查看
> [当前真实 Flutter Golden](../morning-ledger-ce04/index.html)。

该方向保留“墨色账簿”的完整功能丰富度与信息密度，仅替换为“晨雾票夹”的视觉语言。当时仅用于设计确认，未迁移到 Flutter。

## 内容

- `board-01.html`—`board-10.html`：由原有 10 张画板机械生成，界面内容与状态覆盖保持一致。
- `compact-check.html`：360×800 紧凑视口检查。
- `hybrid.css`：加载在画板局部样式之后的混合视觉覆盖层。
- `index.html`：原方案对比与 10 张混合画板画廊。
- `rendered/`：所有可复现 PNG。

## 生成与渲染

```powershell
corepack enable
pnpm install --frozen-lockfile
node tools\generate_hybrid_design_boards.cjs
pnpm run render:design:hybrid
```

仓库的 `package.json` 与 `pnpm-lock.yaml` 固定 Playwright API 版本；渲染仍使用
本机 Chrome/Edge。生成脚本只改变样式引用和画板标题，不删除或重排原画板中的功能内容。
