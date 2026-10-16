/// One page of a paginated API list.
class Paged<T> {
  const Paged({required this.items, required this.total, required this.page, required this.lastPage});

  final List<T> items;
  final int total;
  final int page;
  final int lastPage;

  bool get hasMore => page < lastPage;
}
