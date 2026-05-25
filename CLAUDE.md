# CLAUDE.md

Документация проекта для будущих сессий Claude Code. Краткая карта кода, договорённости и нетривиальные места, которые не выводятся напрямую из исходников.

## О проекте

**dishes_app** — мобильное Flutter-приложение «Мои блюда». Локальный каталог блюд с ингредиентами, картинками и ценами; формирование общей корзины покупок из нескольких блюд; шаринг блюд и корзин через системный share. Никакого backend — всё хранится локально в JSON.

- Язык UI: **русский** (все строки, комментарии в коде, тексты для шаринга — на русском).
- Платформа: основная — **Android** (под iOS не настроен — см. `flutter_launcher_icons.ios: false` в [pubspec.yaml](pubspec.yaml)).
- Flutter SDK: `>=3.6.0`, Dart `>=3.0.0 <4.0.0`.

## Запуск и сборка

```powershell
flutter pub get
flutter run            # на подключённое устройство/эмулятор
flutter build apk      # релизный APK
flutter pub run flutter_launcher_icons   # пересобрать иконки приложения
```

## Структура кода

```
lib/
├── main.dart                       # MaterialApp, тема (seed=Colors.orange, M3)
├── models/
│   ├── dish.dart                   # Блюдо: id, name, ingredients[], imagePath
│   ├── ingredient.dart             # Ингредиент: name, weight, unit, price?
│   └── product.dart                # Продукт каталога: id, name, defaultAmount, defaultUnit
├── services/
│   └── storage_service.dart        # JSON-файлы в getApplicationDocumentsDirectory(), картинки в подпапке dish_images/
├── screens/
│   ├── home_screen.dart            # Список блюд + режим выбора для корзины, импорт/экспорт блюд, меню каталога продуктов
│   ├── dish_edit_screen.dart       # Создание/редактирование блюда + ингредиенты + фото
│   ├── dish_detail_screen.dart     # Просмотр блюда + кнопка шаринга
│   ├── cart_screen.dart            # Объединённая корзина по выбранным блюдам, чекбоксы, ручное добавление, шаринг
│   └── products_screen.dart        # Каталог продуктов с импортом/экспортом; здесь же showProductEditDialog()
└── widgets/
    └── product_picker_sheet.dart   # Bottom sheet с поиском для выбора продукта из каталога
```

## Архитектурные договорённости

- **Никакого state management** (Provider/Bloc/Riverpod). Только `StatefulWidget` + `setState`. Состояние блюд живёт в `_HomeScreenState._dishes` и пересохраняется в файл через `StorageService.saveDishes()` после каждого изменения. При возврате с дочернего экрана делается `_load()` для перечитывания.
- **Хранилище** — два JSON-файла в `ApplicationDocumentsDirectory`:
  - `dishes.json` — блюда;
  - `products.json` — каталог продуктов.
  - Картинки блюд лежат в подпапке `dish_images/`, имя — `<millisecondsSinceEpoch><ext>`. См. [lib/services/storage_service.dart:25-32](lib/services/storage_service.dart#L25-L32).
- **Идентификаторы** — `uuid.v4()` для `Dish` и `Product`. При импорте, если id коллизирует, к нему приписывается `_${microsecondsSinceEpoch}`.
- **Экспорт блюд намеренно затирает `imagePath`** ([lib/services/storage_service.dart:113-119](lib/services/storage_service.dart#L113-L119)) — пути локального устройства бессмысленны на другом телефоне.
- **Импорт каталога продуктов в режиме merge сравнивает по имени** (case-insensitive, trimmed), а не по id, и **не перезаписывает** существующие записи — чтобы не сбить `defaultAmount`/`defaultUnit`. См. [lib/services/storage_service.dart:198-210](lib/services/storage_service.dart#L198-L210).

## Единицы измерения — нетривиальная часть

В [lib/models/ingredient.dart](lib/models/ingredient.dart) есть «семейства единиц» для агрегации в корзине:

- `mass` — `г`, `кг` (базовая `г`)
- `volume` — `мл`, `л` (базовая `мл`)
- `шт`, `уп` — каждая в своём «семействе»

При объединении ингредиентов в корзине ([lib/screens/cart_screen.dart:109-133](lib/screens/cart_screen.dart#L109-L133)):

- Одноимённые продукты складываются **только если их семейства совпадают**. Например, «Молоко 200 мл» + «Молоко 0.5 л» = «Молоко 700 мл» (потом UI покажет «0.7 л»). А «Лук 200 г» и «Лук 2 шт» останутся **разными строками** в корзине.
- `amountDisplay` автоматически конвертирует `г→кг` и `мл→л` при значениях ≥ 1000.
- Поддерживаемые единицы: `Ingredient.allUnits = ['г', 'кг', 'мл', 'л', 'шт', 'уп']`.

Если будете добавлять новую единицу — нужно одновременно прописать её в `allUnits`, `unitFamily()`, `toBase()`, `baseUnitOf()` и в логике `amountDisplay`.

## Сценарии шаринга

Используется `share_plus`. Три точки выхода:

1. **Блюдо целиком** (`DishDetailScreen._share`) — `Dish.toShareText()` + картинка через `Share.shareXFiles`, если есть.
2. **Кнопка share в карточке списка** (`HomeScreen._shareDish`) — **не** шарит напрямую, а открывает `CartScreen` для одного блюда, чтобы пользователь мог отредактировать состав перед отправкой. Это намеренно.
3. **Корзина из N блюд** (`CartScreen._share`) — собирается агрегированный текст; картинка добавляется только если в корзине ровно одно блюдо.

Также есть **экспорт/импорт JSON** через `file_picker` + `share_plus` — и для блюд (в `HomeScreen`), и для каталога продуктов (в `ProductsScreen`).

## Иконки приложения

Сконфигурировано в `pubspec.yaml` под `flutter_launcher_icons`. Для адаптивной иконки Android 8+ используется **отдельный foreground с safe-zone ~66%** (`assets/icon/icon_foreground.png`), чтобы маска лаунчера не обрезала лого. Legacy-иконка для старых Android — полная квадратная (`assets/icon/icon.png`). Это уже отлажено (см. коммит `11a8cfd`) — если будете трогать иконки, помните про safe-zone.

## Стиль и тон

- **Комментарии в коде — на русском**, в стиле «зачем это нужно», а не «что делает». Следуйте этому стилю.
- **UI-строки — на русском.** Никакой локализации/i18n пока нет (можно добавить через `flutter_localizations`, если потребуется).
- **Тема приложения** — Material 3, seed `Colors.orange`. Акцентные элементы (карточки выбранных блюд, шапки корзины) используют `Colors.orange.shade50/100/700/900`.

## Что в `assets/`

- `assets/icon/icon.png` — legacy-иконка
- `assets/icon/icon_foreground.png` — foreground адаптивной иконки

Других ассетов нет; в `pubspec.yaml` секция `assets:` не объявлена (картинки блюд кладёт пользователь через `image_picker` и они хранятся вне assets).

## Чего в проекте НЕТ (и о чём стоит спросить, прежде чем добавлять)

- Тестов (ни unit, ни widget) — папки `test/` нет.
- CI/CD конфигурации.
- iOS-сборки (отключена в `flutter_launcher_icons`, Info.plist под image_picker/share не правился).
- State management библиотек.
- Кода работы с сетью / API.
- Локализации.
