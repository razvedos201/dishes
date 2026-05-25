// Условный экспорт: на мобильных/десктопе подхватывается local_image_io.dart
// с реальной работой с File; на вебе — local_image_web.dart, который всегда
// сообщает «картинок нет».
export 'local_image_web.dart' if (dart.library.io) 'local_image_io.dart';
