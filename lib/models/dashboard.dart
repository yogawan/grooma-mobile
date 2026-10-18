enum DashboardPeriod {
  day,
  week,
  month,
  year;

  String get apiValue => switch (this) {
    DashboardPeriod.day => 'DAY',
    DashboardPeriod.week => 'WEEK',
    DashboardPeriod.month => 'MONTH',
    DashboardPeriod.year => 'YEAR',
  };

  String get label => switch (this) {
    DashboardPeriod.day => 'Harian',
    DashboardPeriod.week => 'Mingguan',
    DashboardPeriod.month => 'Bulanan',
    DashboardPeriod.year => 'Tahunan',
  };
}

class DashboardSummary {
  const DashboardSummary({
    required this.totalRevenue,
    required this.transactionCount,
    required this.avgOrderValue,
    required this.uniqueCustomers,
  });

  final num totalRevenue;
  final int transactionCount;
  final num avgOrderValue;
  final int uniqueCustomers;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      totalRevenue: json['totalRevenue'] as num,
      transactionCount: json['transactionCount'] as int,
      avgOrderValue: json['avgOrderValue'] as num,
      uniqueCustomers: json['uniqueCustomers'] as int,
    );
  }
}

class RevenuePoint {
  const RevenuePoint({
    required this.label,
    required this.revenue,
    required this.transactionCount,
  });

  final String label;
  final num revenue;
  final int transactionCount;

  // `_id` shape depends on the `period` the request was made with — see
  // dashboard doc §3.2: string for DAY, {year,week} for WEEK,
  // {year,month} for MONTH, number for YEAR. Normalize all four into a
  // single display label here so the UI never has to branch on it.
  factory RevenuePoint.fromJson(Map<String, dynamic> json) {
    final id = json['_id'];
    final String label;
    if (id is String) {
      label = id;
    } else if (id is num) {
      label = id.toStringAsFixed(0);
    } else if (id is Map && id.containsKey('week')) {
      label = '${id['year']}-W${id['week']}';
    } else if (id is Map && id.containsKey('month')) {
      final month = (id['month'] as num).toInt().toString().padLeft(2, '0');
      label = '${id['year']}-$month';
    } else {
      label = '-';
    }
    return RevenuePoint(
      label: label,
      revenue: json['revenue'] as num,
      transactionCount: json['transactionCount'] as int,
    );
  }
}

class PaymentBreakdownItem {
  const PaymentBreakdownItem({
    required this.method,
    required this.count,
    required this.revenue,
  });

  final String method;
  final int count;
  final num revenue;

  factory PaymentBreakdownItem.fromJson(Map<String, dynamic> json) {
    return PaymentBreakdownItem(
      method: json['_id'] as String,
      count: json['count'] as int,
      revenue: json['revenue'] as num,
    );
  }
}

class RevenueData {
  const RevenueData({required this.byPeriod, required this.paymentBreakdown});

  final List<RevenuePoint> byPeriod;
  final List<PaymentBreakdownItem> paymentBreakdown;

  factory RevenueData.fromJson(Map<String, dynamic> json) {
    return RevenueData(
      byPeriod: (json['byPeriod'] as List)
          .map((e) => RevenuePoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      paymentBreakdown: (json['paymentBreakdown'] as List)
          .map((e) => PaymentBreakdownItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ServiceStat {
  const ServiceStat({
    required this.id,
    required this.serviceName,
    required this.count,
    required this.revenue,
  });

  final String id;
  final String serviceName;
  final int count;
  final num revenue;

  factory ServiceStat.fromJson(Map<String, dynamic> json) {
    return ServiceStat(
      id: json['_id'] as String,
      serviceName: json['serviceName'] as String,
      count: json['count'] as int,
      revenue: json['revenue'] as num,
    );
  }
}

class AgentStat {
  const AgentStat({
    required this.id,
    required this.transactionCount,
    required this.totalRevenue,
    required this.agentRevenue,
  });

  final String id;
  final int transactionCount;
  final num totalRevenue;
  final num agentRevenue;

  // `agentName` is intentionally not parsed here: the backend returns the
  // raw agent ObjectId in that field (known bug, dashboard doc §3.4), not
  // an actual name. Resolving real names needs a /users lookup that is
  // out of scope for this module.
  factory AgentStat.fromJson(Map<String, dynamic> json) {
    return AgentStat(
      id: json['_id'] as String,
      transactionCount: json['transactionCount'] as int,
      totalRevenue: json['totalRevenue'] as num,
      agentRevenue: json['agentRevenue'] as num,
    );
  }
}

class CountItem {
  const CountItem({required this.label, required this.count});

  final String label;
  final int count;

  factory CountItem.fromJson(Map<String, dynamic> json) {
    return CountItem(label: json['_id'] as String, count: json['count'] as int);
  }
}

class TransactionStats {
  const TransactionStats({
    required this.byStatus,
    required this.byPaymentStatus,
    required this.byPaymentMethod,
  });

  final List<CountItem> byStatus;
  final List<CountItem> byPaymentStatus;
  final List<CountItem> byPaymentMethod;

  factory TransactionStats.fromJson(Map<String, dynamic> json) {
    List<CountItem> parse(String key) => (json[key] as List)
        .map((e) => CountItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return TransactionStats(
      byStatus: parse('byStatus'),
      byPaymentStatus: parse('byPaymentStatus'),
      byPaymentMethod: parse('byPaymentMethod'),
    );
  }
}

class InventoryLowStockItem {
  const InventoryLowStockItem({
    required this.id,
    required this.name,
    required this.branchName,
    required this.quantity,
    required this.minimumStock,
  });

  final String id;
  final String name;
  final String branchName;
  final num quantity;
  final num minimumStock;

  factory InventoryLowStockItem.fromJson(Map<String, dynamic> json) {
    return InventoryLowStockItem(
      id: json['_id'] as String,
      name: json['name'] as String,
      branchName: (json['branch'] as Map<String, dynamic>)['name'] as String,
      quantity: json['quantity'] as num,
      minimumStock: json['minimumStock'] as num,
    );
  }
}
