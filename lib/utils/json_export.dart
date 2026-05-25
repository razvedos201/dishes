// Условный экспорт: на мобильных/десктопе — share через share_plus с временным
// файлом; на вебе — скачивание JSON-файла в браузер.
export 'json_export_web.dart' if (dart.library.io) 'json_export_io.dart';
