## 项目简介

本项目是一个用于存储餐饮发票报销单据以及记录导出的APP，主要功能：

1. **订单管理**：从手机相册中选择外卖订单截图，存储到数据库中
2. **OCR识别**：使用本地 OCR 模型识别订单截图中的店铺名称、实付款、下单时间、订单号
3. **发票管理**：选择图片或PDF作为发票存储，关联对应的外卖订单
4. **发票OCR**：识别发票的发票号码、开票日期、价税合计金额
5. **数据导出**：导出订单和发票数据为Excel文件

所有OCR识别字段均可由用户自行修正。

---

## 当前开发进度

### 已完成功能

| 功能模块 | 状态 | 说明                                         |
|---------|------|--------------------------------------------|
| 项目基础架构 | ✅ | 依赖包、入口配置、Material 3 主题、路由、数据库              |
| 数据层 | ✅ | Order/Invoice/OcrResult 模型、仓库层、服务层         |
| 状态管理 | ✅ | Riverpod StateNotifier (order/invoice/ocr) |
| UI组件库 | ✅ | 统一卡片、按钮、输入框、空状态组件                          |
| 订单管理 | ✅ | 列表、详情、编辑页面                                 |
| 发票管理 | ✅ | 列表、详情、编辑页面                                 |
| 数据导出 | ✅ | Excel导出 (订单+发票工作表)                         |
| 首页统计 | ✅ | 数据概览页面                                     |
| 分享功能 | ✅ | 图片、PDF、导出文件分享                              |
| PDF预览 | ✅ | syncfusion_flutter_pdfviewer               |
| 设置页面 | ✅ | 应用信息、存储统计、缓存清理、OCR状态                       |
| OCR引擎 | ✅ | RapidOcrAndroidOnnx (ONNX格式，内置模型)          |
| LLM推理 | ✅ | MNN框架集成 (阿里开源)                             |
| OCR+LLM识别 | ✅ | RapidOcr ONNX + Qwen3.5-0.8B-MNN 结构化提取     |

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
│   │   └── ocr_result.dart        # OCR结果模型
│   ├── repositories/
│   │   ├── order_repository.dart
│   │   └── invoice_repository.dart
│   ├── datasources/database/
│   │   ├── database_helper.dart
│   │   ├── order_table.dart
│   │   └── invoice_table.dart
│   └── services/
│       ├── image_service.dart     # 图片管理
│       ├── file_service.dart      # 文件管理
│       └── ocr_service.dart       # OCR服务接口
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
│   │   │   └── order_edit_screen.dart
│   │   ├── invoices/
│   │   │   ├── invoices_screen.dart
│   │   │   ├── invoice_detail_screen.dart
│   │   │   └── invoice_edit_screen.dart
│   │   └── export/export_screen.dart
│   └── widgets/
│       ├── common/                 # 通用组件
│       ├── order/                  # 订单相关组件
│       └── invoice/                # 发票相关组件
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
```

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
- **LLM推理**: MNN (阿里开源移动端推理框架)
- **代码位置**:
  - `android/app/src/main/cpp/` - Native C++代码
  - `android/app/src/main/jniLibs/` - MNN预编译库
  - `android/app/src/main/kotlin/.../MainActivity.kt` - Flutter MethodChannel
  - `android/app/src/main/kotlin/.../MnnEngine.kt` - MNN LLM引擎封装

### MNN框架优势

- **性能优化**: 专为移动端设计，ARM NEON优化
- **模型压缩**: 支持4-bit量化，模型体积小
- **内存效率**: 低内存占用，适合移动设备
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