/// `pagination` block of the page envelope.
class PageInfo {
  const PageInfo({
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrevious,
  });

  factory PageInfo.fromJson(Map<String, Object?> json) => PageInfo(
    page: json['page']! as int,
    size: json['size']! as int,
    totalElements: json['totalElements']! as int,
    totalPages: json['totalPages']! as int,
    hasNext: json['hasNext']! as bool,
    hasPrevious: json['hasPrevious']! as bool,
  );

  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool hasNext;
  final bool hasPrevious;
}

/// A page envelope: `values` plus `pagination`.
class Page<T> {
  const Page({required this.items, required this.pagination});

  final List<T> items;
  final PageInfo pagination;
}
