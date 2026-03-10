/// App constants used throughout the application
class AppConstants {
  // App info
  static const String appName = '餐饮发票报销单据管理';
  static const String appTitle = 'Catering Receipt Recorder';

  // Database
  static const String databaseName = 'catering_receipts.db';
  static const int databaseVersion = 2;

  // Table names
  static const String ordersTable = 'orders';
  static const String invoicesTable = 'invoices';
  static const String invoiceOrderRelationsTable = 'invoice_order_relations';

  // Column names - Orders
  static const String colId = 'id';
  static const String colImagePath = 'image_path';
  static const String colShopName = 'shop_name';
  static const String colAmount = 'amount';
  static const String colOrderDate = 'order_date';
  static const String colMealTime = 'meal_time';
  static const String colOrderNumber = 'order_number';
  static const String colOrderId = 'order_id';
  static const String colCreatedAt = 'created_at';
  static const String colUpdatedAt = 'updated_at';

  // Column names - Invoices
  static const String colInvoiceNumber = 'invoice_number';
  static const String colInvoiceDate = 'invoice_date';
  static const String colTotalAmount = 'total_amount';
  static const String colSellerName = 'seller_name';

  // Column names - Invoice-Order Relations
  static const String colInvoiceId = 'invoice_id';

  // File storage
  static const String imagesFolder = 'receipt_images';
  static const String pdfsFolder = 'receipt_pdfs';

  // Date formats
  static const String dateFormatDisplay = 'yyyy年MM月dd日';
  static const String dateFormatDisplayWithTime = 'yyyy年MM月dd日 HH:mm';
  static const String dateFormatStorage = 'yyyy-MM-dd';
  static const String dateFormatStorageWithTime = 'yyyy-MM-dd HH:mm:ss';
  static const String dateFormatInput = 'yyyy/MM/dd';

  // Export formats
  static const String exportFormatExcel = 'Excel';
  static const String exportFormatCSV = 'CSV';
  static const String exportAll = '全部数据';
  static const String exportByDate = '按日期范围';
  static const String exportByOrder = '按订单';

  // Image quality
  static const int imageQuality = 85;

  // Pagination
  static const int pageSize = 20;

  // OCR placeholders (for when model is not integrated yet)
  static const String ocrNotAvailable = 'OCR识别功能暂未启用，请手动填写信息';

  // Error messages
  static const String errorLoadingData = '加载数据失败';
  static const String errorSavingData = '保存数据失败';
  static const String errorDeletingData = '删除数据失败';
  static const String errorPickingImage = '选择图片失败';
  static const String errorProcessingImage = '处理图片失败';
  static const String errorExporting = '导出数据失败';
  static const String errorNoData = '暂无数据';

  // Success messages
  static const String successSaved = '保存成功';
  static const String successDeleted = '删除成功';
  static const String successExported = '导出成功';

  // Empty state messages
  static const String emptyOrders = '暂无订单记录';
  static const String emptyInvoices = '暂无发票记录';
  static const String emptyOrdersDetail = '点击下方按钮添加新订单';
  static const String emptyInvoicesDetail = '点击下方按钮添加新发票';

  // Confirmation messages
  static const String confirmDelete = '确认删除';
  static const String confirmDeleteOrder = '确认删除此订单吗？\n不会删除与此订单关联的发票。';
  static const String confirmDeleteInvoice = '确认删除此发票吗？\n不会删除与此发票关联的订单。';

  // Button labels
  static const String btnAdd = '添加';
  static const String btnEdit = '编辑';
  static const String btnDelete = '删除';
  static const String btnSave = '保存';
  static const String btnCancel = '取消';
  static const String btnConfirm = '确认';
  static const String btnOCR = 'OCR识别';
  static const String btnExport = '导出';
  static const String btnSelectImage = '选择图片';
  static const String btnSelectPDF = '选择PDF';
  static const String btnTakePhoto = '拍照';
  static const String btnSelectFromGallery = '从相册选择';

  // Field labels
  static const String labelShopName = '店铺名称';
  static const String labelAmount = '金额';
  static const String labelOrderDate = '日期';
  static const String labelMealTime = '时段';
  static const String labelOrderNumber = '订单号';
  static const String labelInvoiceNumber = '发票号码';
  static const String labelInvoiceDate = '开票日期';
  static const String labelTotalAmount = '价税合计';
  static const String labelSellerName = '销售方名称';
  static const String labelRelatedOrders = '关联订单';
  static const String labelRelatedOrder = '关联订单';
  static const String labelNoOrder = '未关联订单';
  static const String labelNoOrdersSelected = '未选择订单';
  static const String labelOrdersSelected = '已选择 {} 个订单';

  // Hints
  static const String hintShopName = '请输入店铺名称';
  static const String hintAmount = '请输入金额';
  static const String hintOrderNumber = '请输入订单号';
  static const String hintInvoiceNumber = '请输入发票号码';
  static const String hintSellerName = '请输入销售方名称';

  // Screen titles
  static const String titleHome = '首页';
  static const String titleOrders = '订单管理';
  static const String titleOrderDetail = '订单详情';
  static const String titleOrderEdit = '编辑订单';
  static const String titleOrderAdd = '添加订单';
  static const String titleInvoices = '发票管理';
  static const String titleInvoiceDetail = '发票详情';
  static const String titleInvoiceEdit = '编辑发票';
  static const String titleInvoiceAdd = '添加发票';
  static const String titleExport = '数据导出';

  // Navigation labels
  static const String navHome = '首页';
  static const String navOrders = '订单';
  static const String navInvoices = '发票';
  static const String navExport = '导出';

  // Export range options
  static const String exportRangeAll = '全部数据';
  static const String exportRangeThisMonth = '本月数据';
  static const String exportRangeLastMonth = '上月数据';
  static const String exportRangeThisYear = '本年数据';
  static const String exportRangeCustom = '自定义范围';
}
