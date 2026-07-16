## 项目简介

本项目是一个用于存储餐饮发票报销单据以及记录导出的APP，主要功能：

1. **订单管理**：从手机相册中选择外卖订单截图，存储到数据库中
2. **AI 识别**：用户可选择本地 MNN 模型或 OpenAI-compatible 云端模型识别订单截图中的店铺名称、实付款、下单时间、订单号
3. **发票管理**：选择图片或PDF作为发票存储，关联对应的外卖订单
4. **发票 AI 识别**：识别发票的发票号码、开票日期、价税合计金额
5. **数据导出**：导出报销材料（用餐证明PDF、发票PDF、用餐明细Excel）

所有 AI/OCR 识别字段均可由用户自行修正。

---

## 功能模块

| 功能模块      | 状态 | 说明                                                      |
|-----------|----|---------------------------------------------------------|
| 项目基础架构    | ✅  | 依赖包、入口配置、Material 3 主题、路由、数据库                           |
| 数据层       | ✅  | Order/Invoice/OcrResult/InvoiceOrderRelation 模型、仓库层、服务层 |
| 状态管理      | ✅  | Riverpod StateNotifier (order/invoice/ocr)              |
| UI组件库     | ✅  | `AppCard`、按钮、字段与状态标签使用扁平不透明填充和等宽细描边；顶栏、导航、Sheet 与 Dialog 仅在需要区分悬浮层级时使用有界高实色模糊 |
| 报销装订轨视觉系统 | ✅ | 全局 Tinos + Noto Serif SC 衬线体系、扁平控件、连续四栏导航、独立新增侧键、连续月账页、浅暗色与减少动态效果支持 |
| 订单管理      | ✅  | “订单列表”按月连续纸页、组内粘性月份栏、日期侧栏与 hairline 行，支持月份/关系筛选后直接恢复全部，保留搜索、详情编辑和发票关联流程 |
| 发票管理      | ✅  | “发票列表”按月连续纸页、组内粘性月份栏与批量关联订单统计，支持月份/关系筛选后直接恢复全部，保留详情编辑和订单关联流程 |
| 发票-订单关联   | ✅  | 一对多关系（一张发票关联多个订单）、双向选择器、关联计数显示                          |
| 用餐证明导出    | ✅  | 保留原订单选择与导出流程；PDF格式、订单截图2x2排版、金额分摊、自动保存到Download/ReceiptTamer |
| 发票导出      | ✅  | 保留原发票选择与导出流程；PDF格式、2张/页、PDFium位图化渲染、字体兜底、自动旋转、时间标签选项、自动保存到Download/ReceiptTamer |
| 用餐明细导出    | ✅  | 保留原导出选项与结果流程；Excel格式、按日期/餐时分类、金额分摊、汇总行、自动保存到Download/ReceiptTamer |
| 发票金额分摊    | ✅  | 按订单金额比例分摊、精确无舍入误差                                       |
| 首页工作台    | ✅  | 开票助手以印章图标、数字摘要和行动箭头组成无整高分隔线的三等分主入口；用餐证明/发票导出小卡与最近订单长纸页共用外层滚动，按 `createdAt` 展示最新 10 条订单，“查看更多”切换到订单主导航，不建立报销周期 |
| 完整报销流程  | ✅  | 进入“报销”即按订单选择，也可通过屏幕水平居中的紧凑菜单切为按发票，菜单副标题说明同票联动方式；日期仅作可选筛选，账页日期栏继承整行底色并与勾选栏以细线分隔，同票订单自动联动，联动变化以状态栏下方的低饱和纸签提示且只统计本次增减，随后复用原导出选项生成三类材料 |
| 开票助手      | ✅  | 默认全部日期；按店铺聚合未关联发票订单，并可批量预选订单新建发票及写入关联 |
| 分享功能      | ✅  | 保留原图片/PDF分享导入、批量处理和导出文件分享流程与文案 |
| PDF预览     | ✅  | syncfusion_flutter_pdfviewer                            |
| 设置        | ✅  | 从主导航移出，由首页齿轮进入；整合模型、存储、清理、备份、隐私、开源、版本、更新与应用信息 |
| 数据清理      | ✅  | 保留原订单/发票清理、级联选择、确认、执行与结果流程，仅由主题提供珊瑚色危险语义 |
| OCR引擎     | ✅  | RapidOcrAndroidOnnx (ONNX格式，内置模型)                       |
| LLM推理     | ✅  | 本地 MNN 或 OpenAI-compatible 云端模型                         |
| OCR + LLM 识别 | ✅  | 本地 OCR 文本提取 + LLM 结构化；多模态云端模型可直接识别图片       |
| 应用更新      | ✅  | 基于 GitHub Release 的检查更新与下载安装、APK保存到Download/ReceiptTamer |
| 数据备份与还原  | ✅  | 备份所有数据到zip包、覆盖/增量还原、版本兼容性检查、自动保存到Download/ReceiptTamer |

---

## 项目结构

```
lib/
├── main.dart                      # 应用入口
├── app.dart                       # 根组件
├── core/
│   ├── constants/
│   │   └── app_constants.dart     # 常量定义
│   ├── models/
│   │   └── ledger_month_summary.dart # 数据层只读月份汇总（非持久化模型）
│   ├── theme/
│   │   ├── app_theme.dart         # 晨雾账簿 Material 3 浅色/暗色主题
│   │   └── app_design_tokens.dart # 色板、字体、圆角、动效和玻璃表面 token
│   └── utils/
│       └── date_formatter.dart    # 日期格式化
├── data/
│   ├── models/
│   │   ├── order.dart             # 订单模型
│   │   ├── invoice.dart           # 发票模型
│   │   ├── ocr_result.dart        # OCR结果模型
│   │   ├── ocr_text_block.dart    # OCR文本块模型
│   │   ├── invoice_order_relation.dart  # 发票-订单关联模型
│   │   ├── daily_meal_details.dart      # 每日用餐明细模型
│   │   ├── meal_proof_item.dart         # 用餐证明项模型
│   │   ├── app_version.dart             # 应用版本模型
│   │   └── backup_metadata.dart         # 备份元数据模型
│   ├── repositories/
│   │   ├── order_repository.dart
│   │   └── invoice_repository.dart
│   ├── datasources/database/
│   │   ├── database_helper.dart
│   │   ├── order_table.dart
│   │   ├── invoice_table.dart
│   │   └── invoice_order_relation_table.dart  # 发票-订单关联表
│   └── services/
│       ├── image_service.dart           # 图片管理
│       ├── file_service.dart            # 文件管理
│       ├── ocr_service.dart             # OCR服务接口
│       ├── llm_service.dart             # LLM服务接口
│       ├── pdf_service.dart             # PDF处理服务
│       ├── invoice_export_service.dart   # 发票PDF导出
│       ├── meal_proof_export_service.dart # 用餐证明PDF导出
│       ├── meal_details_export_service.dart # 用餐明细Excel导出
│       ├── invoice_proration_util.dart   # 发票金额分摊工具
│       ├── update_service.dart          # 应用更新服务
│       ├── backup_service.dart          # 备份服务
│       └── cleanup_service.dart         # 数据清理服务
├── presentation/
│   ├── providers/
│   │   ├── order_provider.dart
│   │   ├── invoice_provider.dart
│   │   ├── ocr_provider.dart
│   │   ├── export_provider.dart           # 按订单导出的选择与同票联动状态
│   │   ├── invoice_export_provider.dart   # 按发票导出的选择状态
│   │   ├── invoice_assistant_provider.dart
│   │   ├── home_overview_provider.dart      # 首页统计与最近订单只读投影
│   │   ├── reimbursement_provider.dart      # 旧日期闭包子路由的进程内兼容状态
│   │   └── cleanup_provider.dart        # 清理状态管理
│   ├── screens/
│   │   ├── home/home_screen.dart
│   │   ├── orders/
│   │   │   ├── orders_screen.dart
│   │   │   ├── order_detail_screen.dart
│   │   │   ├── order_edit_screen.dart
│   │   │   └── invoice_selector_screen.dart  # 发票选择器
│   │   ├── invoices/
│   │   │   ├── invoices_screen.dart
│   │   │   ├── invoice_detail_screen.dart
│   │   │   ├── invoice_edit_screen.dart
│   │   │   └── order_selector_screen.dart    # 订单选择器
│   │   ├── export/
│   │   │   ├── reimbursement_screen.dart     # 双依据报销选择账页与导出记录入口
│   │   │   ├── reimbursement_check_screen.dart # 旧日期范围检查兼容页面
│   │   │   ├── export_screen.dart            # 旧发票选择兼容页面
│   │   │   ├── export_options_screen.dart    # 报销材料导出选项
│   │   │   ├── order_export_screen.dart
│   │   │   ├── meal_proof_order_select_screen.dart
│   │   │   ├── invoice_quick_select_screen.dart
│   │   │   └── saved_files_screen.dart       # 已保存文件
│   │   ├── invoice_assistant/
│   │   │   └── invoice_assistant_screen.dart
│   │   ├── share/
│   │   │   └── share_target_screen.dart
│   │   ├── settings/
│   │   │   ├── settings_screen.dart
│   │   │   ├── model_management_screen.dart
│   │   │   ├── storage_management_screen.dart
│   │   │   ├── release_history_screen.dart
│   │   │   ├── info_screen.dart
│   │   │   └── data_cleanup_screen.dart       # 清理模式选择页面
│   │   └── cleanup/
│   │       ├── order_cleanup_screen.dart  # 订单清理页面
│   │       └── invoice_cleanup_screen.dart # 发票清理页面
│   └── widgets/
│       ├── common/                 # 通用组件
│       │   ├── app_button.dart
│       │   ├── app_card.dart
│       │   ├── app_text_field.dart
│       │   ├── empty_state.dart
│       │   ├── glass_surface.dart
│       │   ├── glass_navigation_bar.dart
│       │   ├── glass_alert_dialog.dart
│       │   ├── glass_bottom_sheet.dart
│       │   ├── liquid_glass_background.dart
│       │   ├── ledger_month_sheet.dart       # 连续月账纸页与扁平账行
│       │   ├── scroll_edge_fog.dart           # 滚动视口上下雾边
│       │   ├── date_range_picker.dart
│       │   ├── syncfusion_month_range_picker.dart
│       │   └── storage_ring_chart.dart
│       ├── order/                  # 订单相关组件
│       │   ├── order_ledger_row.dart
│       │   ├── order_card.dart
│       │   ├── order_image_preview.dart
│       │   ├── invoice_selector_card.dart
│       │   ├── month_group.dart
│       │   ├── month_section_header.dart
│       │   └── month_fast_scroll_bar.dart
│       ├── invoice/                # 发票相关组件
│       │   ├── invoice_ledger_row.dart
│       │   ├── invoice_card.dart
│       │   ├── invoice_image_preview.dart
│       │   ├── order_selector_card.dart
│       │   ├── invoice_month_group.dart
│       │   └── invoice_month_section_header.dart
│       ├── settings/               # 设置相关组件
│       │   └── backup_dialog.dart  # 备份对话框
│       └── main_shell.dart         # 主导航外壳
└── router/
    └── app_router.dart

assets/
└── docs/
    ├── privacy_policy.md          # 隐私政策 Markdown 文档
    └── open_source.md             # 开源信息 Markdown 文档

docs/design/
├── fresh-redesign/                 # 晨雾视觉探索稿，不作为页面内容基线
├── hybrid-redesign/                # 历史混合方案，不作为页面内容基线
├── ledger-redesign/                # 历史墨色账簿方案，不作为页面内容基线
├── morning-ledger-ce04/            # 历史 ce04 首页 Golden Gallery
├── morning-ledger-mid-bold-preview/ # 已否决的“单张连续归档页”候选稿
├── morning-ledger-relief-island-preview/ # 已确认并迁移的“晨雾浮签·实体层与悬浮岛”设计基准
├── reimbursement-binding-preview/  # 已确认并迁移 Flutter 的整体信息架构基准
└── reimbursement-export-mode-preview/ # 已确认并迁移的报销双依据选择高保真基准

android/app/src/main/
├── cpp/
│   ├── CMakeLists.txt              # NDK编译配置
│   ├── mnn-jni.cpp                 # MNN JNI绑定代码
│   └── mnn_llm.hpp                 # MNN LLM接口定义
├── jniLibs/arm64-v8a/
│   ├── libMNN.so                   # MNN核心库
│   ├── libMNN_Express.so           # MNN Expression库
│   ├── libllm.so                   # MNN LLM推理库
│   └── libc++_shared.so            # C++运行时
├── kotlin/.../
│   ├── MainActivity.kt             # Flutter MethodChannel处理
│   ├── MnnEngine.kt                # MNN LLM引擎封装
│   └── DownloadHelper.kt           # 下载目录文件保存工具
└── libs/
    └── OcrLibrary-1.3.0-release.aar # OCR库 (含内置模型)

filesDir/
└── qwen3.5-0.8b/                   # 用户下载或导入的 Qwen3.5-0.8B MNN 模型
    ├── llm_config.json             # 模型配置
    ├── llm.mnn                     # 模型结构
    ├── llm.mnn.weight              # 模型权重
    └── tokenizer.txt               # 分词器

package.json                        # 设计渲染脚本与锁定的 playwright-core 依赖
pnpm-lock.yaml                      # Node.js 设计工具依赖锁文件

tools/
├── generate_icons.py               # 从SVG生成各分辨率PNG图标
├── render_design_boards.cjs        # 确定性渲染历史墨色画板
├── render_fresh_design.cjs         # 渲染晨雾视觉探索稿
├── generate_hybrid_design_boards.cjs
├── render_hybrid_design.cjs
├── render_morning_ledger_mid_bold.cjs # 渲染已否决的连续归档页候选
├── generate_morning_ledger_relief_island_preview.cjs
├── render_morning_ledger_relief_island.cjs # 渲染实体层与悬浮岛候选画板
├── render_reimbursement_binding_preview.cjs # 渲染“报销装订轨”整体画板
└── render_reimbursement_export_mode_preview.cjs # 渲染报销双依据选择画板
```

---

## 报销装订轨视觉与性能边界

### 页面内容与功能基线

- `docs/design/reimbursement-binding-preview/` 与 `reimbursement-export-mode-preview/` 已升级为当前信息架构与报销选择页视觉基准；旧 `ce04b3c` 哈希冻结契约已退役，导航、快捷任务、双依据报销选择、连续账页、衬线字体和雾边等长期语义由业务单元测试、Widget 测试与真实 Golden 共同约束，不再保留迁移期的源码字符串冻结测试。
- 主导航连续呈现“首页—订单—发票—报销”。新增不再打断导航，作为右侧同高收件侧键打开“新增”；待处理分享资料可从该入口恢复，添加订单和添加发票仍使用原录入路由。
- “设置”移出主导航，由首页顶栏齿轮进入。模型、存储、数据清理、备份还原、隐私、开源、版本更新、GitHub 和隐藏日志导出能力继续保留。
- 首页顶部装订目录保留三条独立任务：开票助手使用整行主入口，以柔和印章图标、标题与两行强调数字、“查看未关联订单”及行动箭头组成和上方统计同宽的三栏；栏间仅使用短票据虚线，不绘制整高表格分隔。用餐证明导出与发票导出并列为两张小卡，报销材料只从连续主导航进入，不在首页重复。下方“最近订单”按 `createdAt` 展示最新 10 条订单；“查看更多”切换到订单主导航并同步底栏选中态。
- 完整报销进入页面即默认“按订单导出”，顶栏中央以无背景、无边框的正文墨色下拉切换“按发票导出”。两种依据都使用连续月份账页；未关联记录不可选，按订单时同一张发票下的订单自动联动，按发票时自动带入其全部关联订单。同票联动提示位于系统状态栏下方，使用低饱和扁平纸签；提示数量取操作前后选中集合的差值并排除用户直接操作项，不累计此前联动项。全选、反选、可清除的日期筛选、金额统计与固定“下一步”栏继续保留。日期只过滤当前清单，不定义报销范围；最终范围始终由本次勾选确定，不创建或持久化报销批次。
- 材料生成页接收显式的发票与订单 ID，默认开启用餐证明 PDF、发票 PDF 和用餐明细 XLSX；现有生成、逐项错误保留与 Download/ReceiptTamer 归档能力继续复用。“导出记录”作为报销页轻量入口按生成日期浏览归档，不从旧文件伪造报销范围。旧日期闭包检查路由暂留作兼容，但不再是主导航流程。

### 视觉系统

- `AppPalette` 继续使用晨雾白 `#EEF5F2`、归档白 `#FCFEFD`、正文墨青 `#193335`、石墨青 `#52686A`、装订深青 `#2B716C`、薄荷与珊瑚语义；浅色和暗色均由 Material `ColorScheme` 提供，应用使用 `ThemeMode.system`。
- `AppTypography` 的所有 UI 角色统一以 Tinos 处理拉丁字符和数字，以 Noto Serif SC 回退中文；金额保留等宽数字特性。MiSans、Noto Sans SC 与 Courier Prime 资产仍为 PDF 或兼容路径保留，但不再作为 UI 主字体。
- 首页目录卡与最近资料卡保持 12–14dp 间隔并共用单一外层滚动；订单和发票按月使用 `LedgerMonthSheet` 连续纸页、日期侧栏与 hairline 分隔，不再逐行创建圆角阴影卡片。每个月份账页的四个外角统一为 16dp，内部记录仍以直线连续相接；月份标题在各自 `SliverMainAxisGroup` 内粘性停靠，并在该月末行完全离开后由下一月推走。总结内容上下各保留 28dp 雾边安全区，外轮廓以前景描边确保圆角完整。月份快速跳转先按条目权重预定位，再以真实锚点校准未构建的远端 Sliver；右侧轨只侵入半个命中宽度，账页右缘与轨道保留 4dp 间隔，不重复计算页边距。
- 主导航在 412dp 视口使用左右 14dp、底部 12dp、高 72dp 的四等分玻璃岛，右侧以 8dp 间隔放置 72dp 扁平新增键；360dp 时为左右 12dp、底部 10dp、高 68dp 与 68dp 新增键。所有交互满足至少 48dp 命中区，并遵循减少动态效果设置。
- `AppBar` 与 `ScrollEdgeFog` 共用页面纸色，标题栏下方不再出现异色横带。雾边只使用 `Stack`、`IgnorePointer`、实体保护区和线性渐变，不使用 `BackdropFilter` 或 `ShaderMask`：滚动内容在固定顶控件下方淡入，在固定导航、操作栏或批选栏上方完成渐隐，控件占位内不再透出列表；没有固定底控件时只显示顶部雾边。主导航按实际高度、安全区和 8dp 间隔确定淡出落点，`FloatingOverlayLayout` 则按实测控件高度自动放置雾边与保护区。
- `AppEntityTokens` 统一管理不透明填充与等宽细描边；按钮、卡片、输入框、导航和弹层不绘制顶部高光、底部厚脊、按压下沉或实体阴影，顶栏 `AppIconButton` 仅保留透明背景与透明边框的 48dp 命中区。实时模糊只用于有界的 floating/navigation/sheet/dialog 表面，sigma 不超过 12，并由圆角裁剪与局部 `RepaintBoundary` 限制。

### 数据层查询优化

- `DatabaseHelper` 复用同一个数据库打开 Future，避免冷启动期间并发初始化同一数据库。
- 订单和发票 DAO 保留默认排序、日期过滤、关键词组合及 `limit` / `offset` 边界；新增按 `createdAt` 排序的最近收录查询、轻量月份汇总和批量按 ID 读取。raw SQL 的 offset-only 请求使用 SQLite 合法的 `LIMIT -1 OFFSET n`。
- 发票—订单关系按最多 500 个 ID 分块批量查询关联 ID 和数量；`order_id` 唯一索引将关系强制为“一张发票可含多笔订单、每笔订单至多一张发票”。首页关联状态、发票月份摘要、订单/发票报销选择及兼容闭包均使用批量 API，避免逐行数据库往返。
- `LedgerMonthSummary`、`HomeOverview`、`ExportState`、`InvoiceExportState` 和兼容的 `ReimbursementState` 都是只读或进程内投影，不写入数据库。订单与发票 UI 仍是长列表虚拟化，不把性能测试中的“40 条一页”声明为产品分页规则。
- `test/performance/ledger_sqlite_performance_test.dart` 使用 1,000 条订单、500 张发票和 36 个月的真实 SQLite 夹具，包含 40 条一页的查询工作负载、月份汇总、连续筛选和分块关系查询；其中“40 条”是 DAO 性能测试参数，不是当前 UI 的分页行为。

### 设计预览与回归资产

- `docs/design/ledger-redesign/`、`fresh-redesign/`、`hybrid-redesign/` 与 `morning-ledger-*` 保存历史探索或前代视觉，不再作为当前页面验收标准。
- `docs/design/reimbursement-binding-preview/` 是已迁移的整体信息架构基准；`reimbursement-export-mode-preview/` 补充已迁移的报销一级页面，覆盖默认按订单、下拉展开与按发票三种状态。迁移后的首页三入口重排、透明顶栏操作、可取消的双列表月份筛选、报销双依据选择与组内粘性月份栏，以本节说明、真实 Flutter、Widget 测试和 Golden 为最终验收标准；HTML 大字体画板只用于策略说明。
- HTML 设计画板统一使用根目录 `package.json` 与 `pnpm-lock.yaml` 锁定的 `playwright-core`，配合本机 Chrome/Edge 渲染；脚本不再读取用户目录下的 Codex runtime。干净 checkout 先执行 `pnpm install --frozen-lockfile`，再使用对应的 `pnpm run render:design:*` 命令。
- Flutter 视觉以 `test/goldens/baselines/` 中的 19 张真实 Golden 为准：12 张首页覆盖 412×915、360×800、浅色、暗色及 1.0/1.3/2.0 文本缩放；4 张主壳组件覆盖双视口浅暗色下的连续账页、四栏导航和独立新增键；3 张关联检查页覆盖常规、紧凑和暗色 2.0× 字号状态。
- `test/goldens/scenarios/manifest.json` 是后续路由截图计划，不代表所有场景已生成；实际可比较 Golden 数量以上述基线文件为准。
- Golden 使用固定时钟、脱敏夹具、仓库字体和减少动态效果设置，不依赖用户数据或远程资源。新增或更新基线前必须人工核对差异，不得在普通修复中无条件执行 `--update-goldens`。
- 真实组件回归覆盖浅暗色提示文字、导航小字和状态标签至少 `4.5:1` 的对比度、`AppIconButton` 与收件键至少 `48dp` 的命中与语义区域，以及系统减少动态效果下的零时长选择动画。
- SQLite 性能测试与 x86_64 profile 报告只验证数据查询或测试流程。迁移后的 1,738 帧模拟器回归为 build p90/p99 `1.58/2.992ms`、raster p90/p99 `6.275/8.973ms`、慢帧比例 `0.23%`，流程目标通过；`docs/performance/profile-x86-emulator.json` 仍明确为 `certified: false`。认证 harness 直接使用 `kProfileMode`、`device_info_plus.isPhysicalDevice` 与 `Abi.current()` 核验构建模式、物理设备和实际进程 ABI，并强制采集月份快速滚动帧；调用方不能通过 `dart-define` 自报认证条件。只有中档 ARM64 真机 profile mode 结果才可用于正式性能认证，当前不作该声明。

### 兼容性边界

本轮信息架构与视觉迁移调整了主导航、首页内容、设置入口及完整报销步骤。随后的一对多约束修复将数据库从版本 1 升至版本 2：启动时清理同一订单的重复发票关联，保留最近更新/收录的发票，并为 `order_id` 建立唯一索引。备份包格式和应用版本号不变；版本 1 的覆盖还原会自动迁移，增量还原会按同一规则归一化关联。报销双依据清单只新增 Riverpod 进程内选择状态，不新增数据字段；金额分摊公式、备份还原逻辑和导出文件归档方式均未改变。

---

## 数据模型关系

### 发票-订单一对多关系

```
┌─────────────┐                     ┌─────────────┐
│   Invoice   │─────── 1:N ────────>│    Order    │
├─────────────┤                     ├─────────────┤
│ id          │                     │ id          │
│ invoice_num │    一张发票可以      │ shop_name   │
│ total_amount│    关联多个订单      │ amount      │
│ ...         │    但一个订单只能    │ order_date  │
└─────────────┘    关联一张发票      │ meal_time   │
                                    │ ...         │
                                    └─────────────┘
```

- **一张发票** 可关联多个订单
- **一个订单** 只能关联一张发票
- 通过 `invoice_order_relations` 中间表实现
- `order_id` 唯一索引在 SQLite 层强制约束，普通写入、批量写入和恢复数据都不能绕过
- 关联时以事务替换原关系；版本 1 的非法重复数据升级时保留最近更新/收录的发票

### 发票金额分摊算法

当一张发票关联多个订单时，需要将发票金额按比例分摊到各订单：

```
分摊金额 = (订单金额 / 订单总额) × 发票金额
```

**特点**：
- 保证所有分摊金额之和精确等于发票总额（无舍入误差）
- 按订单ID排序，确定性调整余数
- 每个分摊金额不超过订单实际支付金额
- 用餐证明和用餐明细生成前会再次检测跨发票重复订单，发现异常即停止导出，避免重复计入

---

## 导出功能说明

### 用餐证明PDF

生成订单截图汇总文档，用于报销凭证：

- **格式**：A4纸，每页4张订单截图（2×2排版）
- **内容**：日期、餐时、实付金额、发票金额、订单截图
- **排序**：按日期升序，同日期按早餐→午餐→晚餐排序
- **金额**：支持发票金额分摊显示

### 发票PDF

生成发票图片/PDF汇总文档：

- **格式**：A4纸，每页2张发票
- **内容**：发票图片（自动旋转为横向）、时间标签
- **时间标签**：显示关联订单的日期和餐时（可选）
- **支持**：图片格式（自动旋转）、PDF格式（PDFium渲染首页后位图化嵌入）
- **字体兜底**：PDFium渲染时优先使用PDF嵌入字体；对声明但未嵌入的常见发票字体会按单张PDF受控预加载兜底字体，随后继续处理 pdfrx/PDFium 报告的缺失字体，将宋体/印刷体标题/Courier New/Arial等映射到 Noto Serif SC、Courier Prime、Arimo 等可随App分发的字体；正式楷体标题仍使用 LXGW ZhenKai GB

### 用餐明细Excel

生成每日用餐明细表格：

| 日期 | 早餐实付 | 早餐发票 | 午餐实付 | 午餐发票 | 晚餐实付 | 晚餐发票 | 实付总额 | 发票总额 |
|------|---------|---------|---------|---------|---------|---------|---------|---------|
| 2026年03月20日 | 15.00 | 15.00 | 25.00 | 25.00 | 0.00 | 0.00 | 40.00 | 40.00 |
| 总计 | ... | ... | ... | ... | ... | ... | ... | ... |

- **分组**：按日期、餐时分类
- **金额**：支持发票金额分摊
- **选项**：可忽略无用餐记录的日期

---

## 文件存储说明

### 自动保存目录

导出的报销材料、备份数据会自动保存到系统的公共下载目录，并按日期分类：

```
/storage/emulated/0/Download/ReceiptTamer/
├── materials/                    # 报销材料
│   └── YYYYMMDD/                 # 按日期分类
│       ├── 用餐证明_YYYYMMDD_HHMM.pdf
│       ├── 发票_YYYYMMDD_HHMM.pdf
│       └── 用餐明细_YYYYMMDD_HHMM.xlsx
└── backup/                       # 备份数据
    └── YYYYMMDD/                 # 按日期分类
        └── ReceiptTamer_Backup_YYYY-MM-DD.zip
```

### 存储策略

| Android 版本 | 存储方式 | 权限需求 |
|-------------|---------|---------|
| Android 10+ | MediaStore API | 无需权限 |
| Android 9及以下 | 传统文件操作 | WRITE_EXTERNAL_STORAGE |

### 保存的文件类型

| 文件类型 | 文件名格式 | 保存位置 |
|---------|-----------|---------|
| 用餐证明PDF | `用餐证明_YYYYMMDD_HHMM.pdf` | `materials/YYYYMMDD/` |
| 发票PDF | `发票_YYYYMMDD_HHMM.pdf` | `materials/YYYYMMDD/` |
| 用餐明细Excel | `用餐明细_YYYYMMDD_HHMM.xlsx` | `materials/YYYYMMDD/` |
| 备份文件 | `ReceiptTamer_Backup_YYYY-MM-DD.zip` | `backup/YYYYMMDD/` |

**特点**：
- 文件按日期自动分类存储
- Android 10+ 的归档列表按 `MediaStore.RELATIVE_PATH` 精确匹配当前目录；父目录只显示日期文件夹，不重复展示子目录文件
- 完整报销、用餐证明快捷导出与发票快捷导出均先写入临时文件，再仅复制一次到 `materials/YYYYMMDD/`；无论成功或失败都会清理临时文件
- 文件可在系统文件管理器中直接查看
- 成功导出后自动跳转到文件管理器的目标目录，点击"查看"按钮可再次跳转

---

## OCR 集成说明

### 识别流程

AI 识别按用户设置路由：
1. **未设置**: OCR 入口提示用户前往设置选择本地模型或云端模型。
2. **本地 MNN**: 仅在 `filesDir/qwen3.5-0.8b` 中的必需文件完整时可启用；用户选择本地模型后会立即后台预加载，应用启动时若仍选择本地模型也会自动预加载，关闭本地模型会取消/释放加载中的 LLM；识别时使用 RapidOcrAndroidOnnx 进行文字检测和识别，再用 Qwen3.5-0.8B-MNN 做结构化提取。
3. **云端文本模型**: 仅在端点和模型名称已配置时可启用；外部模型初始默认选择 Xiaomi MiMo，也可切换 Deepseek 或其它 OpenAI 风格接口，每个提供商的端点、模型、API key、多模态开关和 extra_body 会独立保存；预置提供商会自动填充端点和关闭思考模式的 extra_body，Xiaomi MiMo 首次默认开启多模态，并在填写 API key 后从 `/v1/models` 获取模型列表，401 会提示 API Key 错误；先本地 OCR/PDF 文本提取，再调用 OpenAI-compatible Chat Completions。
4. **云端多模态模型**: 图片订单/发票直接以 base64 data URL 传入 `image_url` content part；PDF 发票仍走文本提取路径。

### 模型文件

| 文件 | 用途 | 位置 |
|------|------|------|
| `ch_PP-OCRv3_det_infer.onnx` | 文本检测模型 | OcrLibrary AAR内置 |
| `ch_PP-OCRv3_rec_infer.onnx` | 文本识别模型 | OcrLibrary AAR内置 |
| `ch_ppocr_mobile_v2.0_cls_infer.onnx` | 文本方向分类 | OcrLibrary AAR内置 |
| `ppocr_keys_v1.txt` | 字符字典 | OcrLibrary AAR内置 |
| `qwen3.5-0.8b/` | Qwen3.5-0.8B MNN模型 | `filesDir/`，在线逐文件下载（可选 hf-mirror/Hugging Face，跳过已验证文件并保留取消后的部分下载）或从 ZIP 导入 |

### Android原生集成

- **OCR引擎**: RapidOcrAndroidOnnx (基于ONNX Runtime)
- **LLM推理**: 本地 MNN 3.4.1 或用户配置的 OpenAI-compatible 云端模型
- **代码位置**:
  - `android/app/src/main/cpp/` - Native C++代码
  - `android/app/src/main/jniLibs/` - MNN预编译库
  - `android/app/src/main/kotlin/.../MainActivity.kt` - Flutter MethodChannel
  - `android/app/src/main/kotlin/.../MnnEngine.kt` - MNN LLM引擎封装

### Android ABI 与 AVD 运行说明

- MNN LLM native runtime 当前仅随 `arm64-v8a` 打包。
- 普通 `flutter run` 或 Android Studio 在 x86_64 AVD 上可能传入 `android-x64`；这种情况下构建只打印警告，不中止，应用应能启动，但运行时会按 `applicationInfo.nativeLibraryDir` 判断当前安装 ABI 并跳过 MNN 加载。
- 如需在 x86_64 AVD 上通过 ARM64 translation 测试 MNN，需要先执行 `flutter build apk --debug --target-platform android-arm64`，再使用 `adb install -r build/app/outputs/flutter-apk/app-debug.apk` 安装，并用 `adb shell am start -n com.acautomaton.receipt.tamer/.MainActivity` 启动，必要时再 `flutter attach`。
- 不要仅用 `Build.SUPPORTED_ABIS.contains("arm64-v8a")` 判断能否加载 MNN；x86_64 AVD 的设备 ABI 列表可能包含 arm64，但 x86_64 进程不能混加载 arm64 so。

### MNN框架优势

- **性能优化**: 专为移动端设计，ARM NEON优化
- **模型压缩**: 支持4-bit量化，模型体积小
- **内存效率**: 低内存占用，适合移动设备
- **Qwen3.5支持**: 3.4.1新增Linear Attention算子，支持Qwen3.5系列模型
- **资源管理**: 内置Executor，自动管理计算资源
- **预期性能**: 5-15 tokens/sec (相比llama.cpp的1.27 tokens/sec提升5-10倍)

---

## 构建与运行

```bash
# 开发调试
flutter run

# 构建发布版本
flutter build apk
flutter build ipa
```

---

## 应用更新发布规范

应用通过 GitHub Release 实现检查更新功能，发布新版本时需遵循以下规范。

### GitHub Release 格式约定

| 字段 | 格式要求 | 示例 |
|------|---------|------|
| tag_name | `v` + 版本号 | `v1.0.0` |
| name | 版本标题 | `ReceiptTamer v1.0.0` |
| body | 更新说明（Markdown格式） | 见下方示例 |
| assets | APK安装包 | `app-release.apk` |

### 发布流程

1. **更新版本号**
   ```yaml
   # pubspec.yaml
   version: 1.0.1+2  # 版本号+构建号
   ```

2. **构建APK**
   ```bash
   flutter build apk --release
   ```

3. **创建Git标签**
   ```bash
   git tag v1.0.1
   git push origin v1.0.1
   ```

4. **创建GitHub Release**
   - 进入仓库的 Releases 页面
   - 点击 "Draft a new release"
   - 选择标签 `v1.0.1`
   - 填写标题和更新说明
   - 上传构建的APK文件 (`build/app/outputs/flutter-apk/app-release.apk`)
   - 发布

### 更新说明示例

```markdown
## 新功能
- 添加XXX功能

## 优化
- 优化XXX体验

## 修复
- 修复XXX问题

## 注意事项
- 如有重要提示请在此说明
```

### 配置项

GitHub 仓库配置位于 `lib/core/constants/app_constants.dart`：

```dart
// GitHub Release Configuration
static const String githubOwner = 'AccAutomaton';  // GitHub 用户名
static const String githubRepo = 'ReceiptTamer';  // 仓库名
```

### 注意事项

1. **版本号格式**: 必须使用语义化版本号 (Semantic Versioning)，如 `v1.0.0`、`v1.1.0`、`v2.0.0`
2. **APK文件**: Release 中必须包含 `.apk` 文件，否则应用无法下载更新
3. **更新说明**: `body` 字段会在更新对话框中显示，建议填写清晰的更新内容
4. **API限制**: GitHub API 未认证请求限制 60次/小时/IP，一般足够使用

---

## 备份功能说明

### 备份包结构

备份文件为zip格式，包含以下内容：

```
backup.zip
├── manifest.json          # 备份元数据
├── database/
│   └── receipt_tamer.db   # 数据库文件
├── images/                # 图片目录
│   └── *.jpg, *.png...
└── pdfs/                  # PDF目录
    └── *.pdf
```

### manifest.json 结构

```json
{
  "version": "1.0",
  "app_version": "0.5.2",
  "database_version": 2,
  "backup_time": "2026-03-27T10:30:00Z",
  "order_count": 50,
  "invoice_count": 30,
  "image_count": 80,
  "pdf_count": 30
}
```

### 还原模式

**覆盖还原**：
- 清除所有现有数据后还原备份
- 适用于数据迁移或设备更换

**增量还原**：
- 保留现有数据，与备份数据叠加
- 旧备份若含同一订单的多张发票关联，只导入最近更新/收录的那一张

### 版本兼容性

| 情况 | 处理方式 |
|------|---------|
| 备份数据库版本 > 当前版本 | 拒绝还原，提示更新应用 |
| 备份数据库版本 < 当前版本，应用版本相同 | 执行数据库升级后还原 |
| 备份数据库版本 < 当前版本，应用版本不同 | 警告后执行数据库升级再还原 |
| 备份数据库版本 == 当前版本，应用版本不同 | 警告后允许还原 |

---
