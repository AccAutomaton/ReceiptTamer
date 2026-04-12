# 发票导出增强设计文档

## 概述

为报销材料导出中的发票导出功能增加以下增强功能：
1. 超过5个订单的省略显示
2. 发票备注选项

## 需求详情

### 1. 超过5个订单省略显示

当一张发票关联超过5个订单时，订单时间标签按餐次省略显示：
- 显示前5个餐次（完整日期+餐时格式）
- 第5个之后显示"...等共计x个订单"

**格式说明**：
- 单日多餐格式：`2026年03月20日早餐、午餐、晚餐`
- 多日格式：用 `|` 分隔不同日期，每个日期内用 `、` 分隔餐时

**示例**：
- 3个订单（3月20日早餐、午餐、晚餐）：`2026年03月20日早餐、午餐、晚餐`
- 5个订单（3月20日三餐 + 3月21日早餐、午餐）：`2026年03月20日早餐、午餐、晚餐|2026年03月21日早餐、午餐`
- 8个订单（3月20日三餐 + 3月21日三餐 + 3月22日早餐、午餐）：`2026年03月20日早餐、午餐、晚餐|2026年03月21日早餐、午餐、晚餐|...等共计8个订单`

### 2. 发票备注选项

**适用场景**：
- **报销材料导出**的发票导出部分（`ExportOptionsScreen`）
- **首页直接发票导出**（`InvoiceQuickSelectScreen`）

**交互流程**：
1. 用户勾选"为发票添加备注"选项
2. 弹出对话框让用户输入备注文本
3. 输入后在选项旁显示备注内容（可点击修改）
4. 导出时将备注添加到发票标签中

**显示规则**：
- 只勾选备注：显示 `备注内容`
- 只勾选时间标签：显示 `订单时间标签`
- 两个都勾选：显示 `备注内容|订单时间标签`

### 3. UI 设计

#### 报销材料导出（ExportOptionsScreen）- 分组布局

发票导出选项仅在勾选"发票"导出项后显示，作为独立分组：

```
┌─────────────────────────────────────────────┐
│ ☑ 发票                                      │
│    发票信息汇总文档                    [PDF] │
├─────────────────────────────────────────────┤
│ 发票导出选项                                 │
│ ┌─────────────────────────────────────────┐ │
│ │ ○ 发票中标注订单时间                     │ │
│ │ ○ 为发票添加备注  **备注内容**          │ │
│ └─────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

**视觉设计**：
- 分组标题："发票导出选项"，使用较小的灰色文字
- 分组容器：使用浅色背景的卡片包裹选项
- 备注内容：使用主题色高亮显示，支持点击修改
- 禁用状态：未勾选"发票"时，整个分组不显示

#### 首页直接发票导出（InvoiceQuickSelectScreen）- 扩展筛选区域

在现有的筛选区域（顶部搜索框下方）添加备注选项，保持与"显示订单时间标签"选项相同的布局风格：

```
┌─────────────────────────────────────────────┐
│ [搜索框]                                    │
│                                             │
│ ☑ 显示订单时间标签    [日期筛选按钮]        │
│ ☐ 为发票添加备注  **备注内容**              │
└─────────────────────────────────────────────┘
```

**视觉设计**：
- 备注选项与时间标签选项在同一行区域，垂直排列
- 勾选备注后弹出输入对话框，输入后显示备注内容
- 备注内容使用主题色高亮，点击可修改

## 技术设计

### 数据结构变更

在 `InvoiceExportItem` 中添加备注字段：

```dart
class InvoiceExportItem {
  final Invoice invoice;
  final List<Order> orders;
  final String? remark; // 新增：发票备注

  const InvoiceExportItem({
    required this.invoice,
    required this.orders,
    this.remark,
  });

  // 修改 timeLabel getter，支持省略显示和备注
  String get fullLabel {
    final parts = <String>[];
    if (remark != null && remark!.isNotEmpty) {
      parts.add(remark!);
    }
    final timeLabel = truncatedTimeLabel; // 使用省略版本
    if (timeLabel.isNotEmpty) {
      parts.add(timeLabel);
    }
    return parts.join('|');
  }

  // 新增：省略后的时间标签
  String get truncatedTimeLabel {
    // 最多显示5个餐次，超出显示省略
  }
}
```

### UI 组件变更

在 `ExportOptionsScreen` 中添加：

```dart
// 新增状态变量
bool _addInvoiceRemark = false;
String? _invoiceRemarkContent;

// 新增方法：显示备注输入对话框
Future<void> _showRemarkInputDialog() async {
  // 弹出对话框，输入备注
  // 输入后更新 _invoiceRemarkContent
}

// 新增方法：处理备注点击（修改）
void _handleRemarkTap() {
  _showRemarkInputDialog();
}
```

### 文件修改清单

| 文件 | 修改内容 |
|------|---------|
| `invoice_export_service.dart` | `InvoiceExportItem` 添加 remark 字段，修改 timeLabel 逻辑实现省略显示 |
| `export_options_screen.dart` | 添加发票导出选项分组、备注输入对话框、状态变量 |
| `invoice_quick_select_screen.dart` | 添加备注选项、备注输入对话框、状态变量，传递备注参数到导出服务 |
| `invoice.dart` | 无需修改（备注不存储在发票数据中） |

### 省略显示算法

```dart
String get truncatedTimeLabel {
  if (orders.isEmpty) return '';

  // 收集所有餐次信息
  final allMealEntries = <String>[];
  for (final order in orders) {
    final date = order.orderDate ?? '';
    final mealTime = order.mealTime ?? '';
    if (date.isEmpty || mealTime.isEmpty) continue;
    allMealEntries.add('$date|$mealTime');
  }

  if (allMealEntries.isEmpty) return '';

  // 排序后取前5个
  allMealEntries.sort(/* 按日期、餐时排序 */);
  final displayEntries = allMealEntries.take(5).toList();

  // 构建显示文本
  // ...

  // 如果超过5个，添加省略提示
  if (allMealEntries.length > 5) {
    // "...等共计x个订单"
  }
}
```

## 实现步骤

1. 修改 `InvoiceExportItem.timeLabel` 实现，支持超过5个订单的省略显示
2. 在 `ExportOptionsScreen` 添加发票导出选项分组UI
3. 实现备注输入对话框和状态管理
4. 修改 `InvoiceExportService.generateInvoicePdf` 接受备注参数
5. 测试各场景：只备注、只时间标签、两者都勾选、超过5个订单

## 测试场景

### 报销材料导出（ExportOptionsScreen）

| 场景 | 预期结果 |
|------|---------|
| 发票关联1个订单 | 正常显示完整时间标签 |
| 发票关联5个订单 | 正常显示5个餐次 |
| 发票关联8个订单 | 显示前5个餐次 + "...等共计8个订单" |
| 只勾选时间标签 | 显示订单时间标签 |
| 只勾选备注 | 显示备注内容 |
| 两者都勾选 | 显示"备注内容|时间标签" |
| 点击备注内容 | 弹出对话框可修改 |
| 未勾选发票 | 不显示发票导出选项分组 |

### 首页直接发票导出（InvoiceQuickSelectScreen）

| 场景 | 预期结果 |
|------|---------|
| 默认状态 | 显示"显示订单时间标签"和"为发票添加备注"两个选项 |
| 勾选备注后 | 弹出输入对话框，输入后显示备注内容 |
| 点击备注内容 | 弹出对话框可修改 |
| 导出时勾选时间标签 | 发票显示订单时间标签 |
| 导出时勾选备注 | 发票显示备注内容 |
| 导出时两者都勾选 | 发票显示"备注内容|时间标签" |