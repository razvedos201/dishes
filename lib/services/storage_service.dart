// Условный экспорт: на мобильных/десктопе подхватывается storage_io.dart с
// файловым хранилищем; на вебе — storage_web.dart с shared_preferences.
// Класс StorageService определён в обоих файлах с одинаковым публичным API.
export 'storage_web.dart' if (dart.library.io) 'storage_io.dart';
