## 项目简介

本项目是一个用于存储餐饮发票报销单据以及记录导出的APP，主要功能：

1. **订单管理**：从手机相册中选择外卖订单截图，存储到数据库中
2. **OCR识别**：使用本地 OCR 模型识别订单截图中的店铺名称、实付款、下单时间、订单号
3. **发票管理**：选择图片或PDF作为发票存储，关联对应的外卖订单
4. **发票OCR**：识别发票的发票号码、开票日期、价税合计金额
5. **数据导出**：导出报销材料（用餐证明PDF、发票PDF、用餐明细Excel）

所有OCR识别字段均可由用户自行修正。

---

## 当前开发进度

### 已完成功能

| 功能模块      | 状态 | 说明                                                      |
|-----------|----|---------------------------------------------------------|
| 项目基础架构    | ✅  | 依赖包、入口配置、Material 3 主题、路由、数据库                           |
| 数据层       | ✅  | Order/Invoice/OcrResult/InvoiceOrderRelation 模型、仓库层、服务层 |
| 状态管理      | ✅  | Riverpod StateNotifier (order/invoice/ocr)              |
| UI组件库     | ✅  | 统一卡片、按钮、输入框、空状态、月份选择器、存储环形图                             |
| 订单管理      | ✅  | 列表、详情、编辑页面、月份分组、快速滚动                                    |
| 发票管理      | ✅  | 列表、详情、编辑页面、月份分组                                         |
| 发票-订单关联   | ✅  | 一对多关系（一张发票关联多个订单）、双向选择器、关联计数显示                          |
| 用餐证明导出    | ✅  | PDF格式、订单截图2x2排版、金额分摊                                    |
| 发票导出      | ✅  | PDF格式、2张/页、自动旋转、时间标签选项                                  |
| 用餐明细导出    | ✅  | Excel格式、按日期/餐时分类、金额分摊、汇总行                               |
| 发票金额分摊    | ✅  | 按订单金额比例分摊、精确无舍入误差                                       |
| 首页统计      | ✅  | 数据概览页面                                                  |
| 分享功能      | ✅  | 图片、PDF、导出文件分享                                           |
| PDF预览     | ✅  | syncfusion_flutter_pdfviewer                            |
| 设置页面      | ✅  | 应用信息、存储统计、缓存清理、OCR状态                                    |
| OCR引擎     | ✅  | RapidOcrAndroidOnnx (ONNX格式，内置模型)                       |
| LLM推理     | ✅  | MNN框架集成 (阿里开源)                                          |
| OCR+LLM识别 | ✅  | RapidOcr ONNX + Qwen3.5-0.8B-MNN 结构化提取                  |
| 应用更新      | ✅  | 基于 GitHub Release 的检查更新与下载安装                            |

### 待完善功能

无

---

## 项目结构

```
lib/
├── main.dart                      # 应用入口
├── app.dart                       # 根组件
├── core/
│   ├── constants/
│   │   └── app_constants.dart     # 常量定义
│   ├── theme/
│   │   └── app_theme.dart         # Material 3 主题
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
│   │   └── app_version.dart             # 应用版本模型
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
│       └── update_service.dart          # 应用更新服务
├── presentation/
│   ├── providers/
│   │   ├── order_provider.dart
│   │   ├── invoice_provider.dart
│   │   └── ocr_provider.dart
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
│   │   │   ├── export_screen.dart            # 导出主页面
│   │   │   └── export_options_screen.dart    # 导出选项页面
│   │   └── settings/
│   │       ├── settings_screen.dart
│   │       └── info_screen.dart
│   └── widgets/
│       ├── common/                 # 通用组件
│       │   ├── app_button.dart
│       │   ├── app_card.dart
│       │   ├── app_text_field.dart
│       │   ├── empty_state.dart
│       │   ├── month_range_picker.dart
│       │   └── storage_ring_chart.dart
│       ├── order/                  # 订单相关组件
│       │   ├── order_card.dart
│       │   ├── order_image_preview.dart
│       │   ├── invoice_selector_card.dart
│       │   ├── month_group.dart
│       │   ├── month_section_header.dart
│       │   └── month_fast_scroll_bar.dart
│       ├── invoice/                # 发票相关组件
│       │   ├── invoice_card.dart
│       │   ├── invoice_image_preview.dart
│       │   ├── order_selector_card.dart
│       │   ├── invoice_month_group.dart
│       │   └── invoice_month_section_header.dart
│       └── main_shell.dart         # 主导航外壳
└── router/
    └── app_router.dart

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
│   └── MnnEngine.kt                # MNN LLM引擎封装
└── libs/
    └── OcrLibrary-1.3.0-release.aar # OCR库 (含内置模型)

assets/models/
└── qwen3.5-0.8b.mnn/               # Qwen3.5-0.8B MNN模型
    ├── llm_config.json             # 模型配置
    ├── llm.mnn                     # 模型结构
    ├── llm.mnn.weight              # 模型权重 (~450MB)
    └── tokenizer.txt               # 分词器

tools/
└── generate_icons.py               # 从SVG生成各分辨率PNG图标
```

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
- 关联时自动解除订单与原发票的关联（确保一对一约束）

### 发票金额分摊算法

当一张发票关联多个订单时，需要将发票金额按比例分摊到各订单：

```
分摊金额 = (订单金额 / 订单总额) × 发票金额
```

**特点**：
- 保证所有分摊金额之和精确等于发票总额（无舍入误差）
- 按订单ID排序，确定性调整余数
- 每个分摊金额不超过订单实际支付金额

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
- **支持**：图片格式（自动旋转）、PDF格式（提取首页）

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

## OCR集成说明

### 识别流程

OCR识别采用两阶段流程：
1. **RapidOcrAndroidOnnx OCR**: 使用ONNX Runtime进行文字检测和识别
2. **Qwen3.5-0.8B-MNN LLM**: 对OCR结果进行结构化提取，输出JSON格式数据

### 模型文件

| 文件 | 用途 | 位置 |
|------|------|------|
| `ch_PP-OCRv3_det_infer.onnx` | 文本检测模型 | OcrLibrary AAR内置 |
| `ch_PP-OCRv3_rec_infer.onnx` | 文本识别模型 | OcrLibrary AAR内置 |
| `ch_ppocr_mobile_v2.0_cls_infer.onnx` | 文本方向分类 | OcrLibrary AAR内置 |
| `ppocr_keys_v1.txt` | 字符字典 | OcrLibrary AAR内置 |
| `qwen3.5-0.8b.mnn/` | Qwen3.5-0.8B MNN模型 | `assets/models/` |

### Android原生集成

- **OCR引擎**: RapidOcrAndroidOnnx (基于ONNX Runtime)
- **LLM推理**: MNN 3.4.1 (阿里开源移动端推理框架)
- **代码位置**:
  - `android/app/src/main/cpp/` - Native C++代码
  - `android/app/src/main/jniLibs/` - MNN预编译库
  - `android/app/src/main/kotlin/.../MainActivity.kt` - Flutter MethodChannel
  - `android/app/src/main/kotlin/.../MnnEngine.kt` - MNN LLM引擎封装

### MNN框架优势

- **性能优化**: 专为移动端设计，ARM NEON优化
- **模型压缩**: 支持4-bit量化，模型体积小
- **内存效率**: 低内存占用，适合移动设备
- **Qwen3.5支持**: 3.4.1新增Linear Attention算子，支持Qwen3.5系列模型
- **资源管理**: 内置Executor，自动管理计算资源
- **预期性能**: 5-15 tokens/sec (相比llama.cpp的1.27 tokens/sec提升5-10倍)

### LLM Prompt模板

**订单提取:**
```
从以下OCR文本中提取订单信息，以JSON格式返回：
{shopName, amount, orderTime, orderNumber}

OCR文本：
[识别结果]
```

**发票提取:**
```
从以下OCR文本中提取发票信息，以JSON格式返回：
{invoiceNumber, invoiceDate, totalAmount}

OCR文本：
[识别结果]
```

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