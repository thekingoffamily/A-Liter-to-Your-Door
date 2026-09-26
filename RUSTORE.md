# Публикация «Литр До Дома» в RuStore

Инструкция по выпуску сборки в RuStore. Приложение бесплатное, без рекламы и
встроенных покупок, не требует интернета и не собирает персональные данные.

## 1. Требования

- Flutter SDK 3.16+ и Android SDK
- Аккаунт разработчика RuStore
- Иконка 512x512 (в проекте — `assets/icon/app_icon.png`) и логотип

Проверка окружения:

```bash
flutter doctor
```

## 2. Сборка AAB

RuStore принимает **AAB**. Выполните:

```powershell
pwsh -File build_apk.ps1 -Bundle -Icons -Sounds
```

Готовый файл: `build/app/outputs/bundle/release/app-release.aab`.

Отдельные APK для проверки на телефоне:

```powershell
pwsh -File build_apk.ps1 -SplitAbi
adb install -r build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
```

## 3. Подпись релиза

1. Создайте ключ и `android/key.properties`:

   ```powershell
   pwsh -File build_apk.ps1 -NewKeystore -StorePass "пароль" -KeyPass "пароль"
   ```

2. Подключите подпись в `android/app/build.gradle.kts` (один раз):

   ```kotlin
   import java.util.Properties
   import java.io.FileInputStream

   val keystoreProperties = Properties()
   val keystorePropertiesFile = rootProject.file("key.properties")
   if (keystorePropertiesFile.exists()) {
       keystoreProperties.load(FileInputStream(keystorePropertiesFile))
   }

   android {
       signingConfigs {
           create("release") {
               keyAlias = keystoreProperties["keyAlias"] as String
               keyPassword = keystoreProperties["keyPassword"] as String
               storeFile = file(keystoreProperties["storeFile"] as String)
               storePassword = keystoreProperties["storePassword"] as String
           }
       }
       buildTypes {
           release {
               signingConfig = signingConfigs.getByName("release")
           }
       }
   }
   ```

3. Соберите AAB: `flutter build appbundle --release`.

> Сохраните `upload-keystore.jks` и пароли. Без них нельзя выпустить обновление.
> Файлы `key.properties` и `*.jks` уже добавлены в `.gitignore`.

## 4. Карточка приложения

Готовые материалы магазина лежат в папке `store/`:

- `store/icon_512.png` — иконка 512x512 (загружается в карточку RuStore)
- `store/logo.png` — логотип «ЛИТР ДО ДОМА» для шапки карточки
- `store/rustore_description.txt` — краткое и полное описание

- **Название:** Литр До Дома: Симулятор Очереди
- **Краткое описание:** Пиксельная аркада про топливный кризис: ищите АЗС,
  стойте в очередях и не останьтесь без бензина.
- **Полное описание:**

  > Бензин на нуле: Симулятор Очереди — пиксельная городская аркада с видом
  > сверху. Катайтесь по большому городу, ищите работающие заправки, следите за
  > остатком топлива, занимайте очередь и не дайте другим водителям оставить вас
  > без бензина.
  >
  > Выбирайте маршрут, обходите пробки, ищите выгодные цены, улучшайте
  > автомобиль и переживайте неожиданные события: от поломки колонки до приезда
  > долгожданного бензовоза.
  >
  > Сможете ли вы добраться до заправки, пока стрелка бака не опустилась до нуля?

- **Категория:** Игры → Аркады / Симуляторы
- **Возрастной рейтинг:** 6+ (нет жестокости и рекламы)
- **Контакты и политика конфиденциальности:** данные не собираются и не
  передаются; всё хранится локально на устройстве.

## 5. Скриншоты

Рекомендуется 4–8 скриншотов разного геймплея: очередь на АЗС, ночная трасса,
гараж, экран с пустым баком, финал кампании.

## 6. Чек-лист перед публикацией

- [ ] `flutter test` проходит
- [ ] release AAB подписан своим ключом
- [ ] иконка и название («Литр До Дома») отображаются корректно
- [ ] приложение запускается без интернета
- [ ] проверены поворот экрана и сворачивание (пауза)
- [ ] заполнены описание, категория и возрастной рейтинг
