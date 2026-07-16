import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/log_config.dart';
import '../../core/services/log_service.dart';
import '../../data/models/order.dart';
import '../../data/repositories/invoice_repository.dart';
import '../../data/repositories/order_repository.dart';
import 'invoice_provider.dart' as invoice_providers;
import 'order_provider.dart' as order_providers;

const _unset = Object();

/// 一次报销流程在应用进程内的临时状态。
///
/// 这里不创建或持久化“报销批次”。日期范围只有在用户进入报销流程并
/// 主动选择后才存在，退出流程时可直接重置。
class ReimbursementState {
  const ReimbursementState({
    this.startDate,
    this.endDate,
    this.rangeOrders = const [],
    this.unlinkedOrders = const [],
    this.invoiceIds = const {},
    this.outOfRangeOrderIds = const {},
    this.closureOrderIds = const {},
    this.closureOrders = const [],
    this.closureAccepted = false,
    this.isLoading = false,
    this.errorMessage,
  });

  final DateTime? startDate;
  final DateTime? endDate;

  /// 用户所选日期范围内的订单。
  final List<Order> rangeOrders;

  /// 范围内尚未关联发票、因而会阻断完整材料生成的订单。
  final List<Order> unlinkedOrders;

  /// 范围内订单涉及的全部发票 ID。
  final Set<int> invoiceIds;

  /// 与同一发票关联、但业务日期落在所选范围外的订单 ID。
  final Set<int> outOfRangeOrderIds;

  /// 为保持发票关系完整而需要一同导出的订单 ID 闭包。
  final Set<int> closureOrderIds;

  /// 闭包内可读取到的订单，供金额汇总和后续材料生成使用。
  final List<Order> closureOrders;

  /// 用户是否已明确接受把区间外关联订单纳入本次报销。
  final bool closureAccepted;
  final bool isLoading;
  final String? errorMessage;

  bool get hasRange => startDate != null && endDate != null;

  double get totalAmount =>
      closureOrders.fold(0, (total, order) => total + order.amount);

  bool get canContinue =>
      hasRange &&
      !isLoading &&
      errorMessage == null &&
      rangeOrders.isNotEmpty &&
      unlinkedOrders.isEmpty &&
      (outOfRangeOrderIds.isEmpty || closureAccepted);

  ReimbursementState copyWith({
    Object? startDate = _unset,
    Object? endDate = _unset,
    List<Order>? rangeOrders,
    List<Order>? unlinkedOrders,
    Set<int>? invoiceIds,
    Set<int>? outOfRangeOrderIds,
    Set<int>? closureOrderIds,
    List<Order>? closureOrders,
    bool? closureAccepted,
    bool? isLoading,
    Object? errorMessage = _unset,
  }) {
    return ReimbursementState(
      startDate: startDate == _unset ? this.startDate : startDate as DateTime?,
      endDate: endDate == _unset ? this.endDate : endDate as DateTime?,
      rangeOrders: rangeOrders ?? this.rangeOrders,
      unlinkedOrders: unlinkedOrders ?? this.unlinkedOrders,
      invoiceIds: invoiceIds ?? this.invoiceIds,
      outOfRangeOrderIds: outOfRangeOrderIds ?? this.outOfRangeOrderIds,
      closureOrderIds: closureOrderIds ?? this.closureOrderIds,
      closureOrders: closureOrders ?? this.closureOrders,
      closureAccepted: closureAccepted ?? this.closureAccepted,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage == _unset
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class ReimbursementNotifier extends Notifier<ReimbursementState> {
  int _requestVersion = 0;

  @override
  ReimbursementState build() => const ReimbursementState();

  OrderRepository get _orderRepository =>
      ref.read(order_providers.orderRepositoryProvider);

  InvoiceRepository get _invoiceRepository =>
      ref.read(invoice_providers.invoiceRepositoryProvider);

  /// 以任意起止日期建立本次报销的关系闭包。
  Future<void> initializeRange(DateTime start, DateTime end) async {
    final normalizedStart = DateTime(start.year, start.month, start.day);
    final normalizedEnd = DateTime(end.year, end.month, end.day);
    final requestVersion = ++_requestVersion;

    if (normalizedStart.isAfter(normalizedEnd)) {
      state = ReimbursementState(
        startDate: normalizedStart,
        endDate: normalizedEnd,
        errorMessage: '开始日期不能晚于结束日期',
      );
      logService.w(LogConfig.moduleUi, '报销范围无效：开始日期晚于结束日期');
      return;
    }

    state = ReimbursementState(
      startDate: normalizedStart,
      endDate: normalizedEnd,
      isLoading: true,
    );

    try {
      final rangeOrders = await _orderRepository.getByDateRange(
        normalizedStart,
        normalizedEnd,
      );
      final rangeOrderIds = rangeOrders
          .map((order) => order.id)
          .whereType<int>()
          .toList(growable: false);
      final invoiceIdsByOrder = await _orderRepository.getInvoiceIdsForOrders(
        rangeOrderIds,
      );

      final unlinkedOrders = rangeOrders
          .where((order) {
            final orderId = order.id;
            return orderId == null ||
                (invoiceIdsByOrder[orderId]?.isEmpty ?? true);
          })
          .toList(growable: false);
      final invoiceIds = invoiceIdsByOrder.values.expand((ids) => ids).toSet();
      final orderIdsByInvoice = await _invoiceRepository.getOrderIdsForInvoices(
        invoiceIds.toList(growable: false),
      );
      final linkedOrderIds = orderIdsByInvoice.values
          .expand((ids) => ids)
          .toSet();
      final rangeOrderIdSet = rangeOrderIds.toSet();
      final outOfRangeOrderIds = linkedOrderIds.difference(rangeOrderIdSet);
      final closureOrderIds = <int>{...rangeOrderIdSet, ...outOfRangeOrderIds};

      final outsideOrders = await _orderRepository.getByIds(
        outOfRangeOrderIds.toList(growable: false),
      );
      final closureOrders = <Order>[...rangeOrders, ...outsideOrders];

      if (requestVersion != _requestVersion) return;

      state = ReimbursementState(
        startDate: normalizedStart,
        endDate: normalizedEnd,
        rangeOrders: List.unmodifiable(rangeOrders),
        unlinkedOrders: List.unmodifiable(unlinkedOrders),
        invoiceIds: Set.unmodifiable(invoiceIds),
        outOfRangeOrderIds: Set.unmodifiable(outOfRangeOrderIds),
        closureOrderIds: Set.unmodifiable(closureOrderIds),
        closureOrders: List.unmodifiable(closureOrders),
      );
      logService.i(
        LogConfig.moduleUi,
        '报销范围初始化完成：范围内订单=${rangeOrders.length}，'
        '未关联订单=${unlinkedOrders.length}，发票=${invoiceIds.length}，'
        '区间外关联订单=${outOfRangeOrderIds.length}',
      );
    } catch (error, stackTrace) {
      if (requestVersion != _requestVersion) return;

      logService.e(LogConfig.moduleUi, '初始化报销范围失败', error, stackTrace);
      state = ReimbursementState(
        startDate: normalizedStart,
        endDate: normalizedEnd,
        errorMessage: error.toString(),
      );
    }
  }

  /// 按当前日期范围重新读取关系；刷新后需要重新确认区间外闭包。
  Future<void> refresh() async {
    final start = state.startDate;
    final end = state.endDate;
    if (start == null || end == null) return;
    await initializeRange(start, end);
  }

  /// 接受或拒绝把区间外关联订单纳入本次报销。
  void setClosureAccepted(bool accepted) {
    state = state.copyWith(
      closureAccepted: accepted && state.outOfRangeOrderIds.isNotEmpty,
    );
  }

  /// 清除本次进程内会话，不写入数据库或备份。
  void reset() {
    _requestVersion++;
    state = const ReimbursementState();
  }
}

final reimbursementProvider =
    NotifierProvider<ReimbursementNotifier, ReimbursementState>(
      ReimbursementNotifier.new,
    );
