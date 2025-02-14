abstract class BaseRepository<T> {
  Future<T> create(T item);
  Future<T?> read(String id);
  Future<List<T>> readAll();
  Future<int> update(T item);
  Future<int> delete(String id);
}
