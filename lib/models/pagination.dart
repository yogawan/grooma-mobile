class Pagination {
  const Pagination({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  final int page;
  final int limit;
  final int total;
  final int totalPages;

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      page: json['page'] as int,
      limit: json['limit'] as int,
      total: json['total'] as int,
      // Subscription invoices (Kelola doc §4.3) key this `pages`
      // instead of `totalPages` like every other paginated endpoint —
      // a real backend inconsistency, not a typo. Tolerating both
      // here avoids a parallel near-duplicate pagination model.
      totalPages: (json['totalPages'] ?? json['pages']) as int,
    );
  }
}
