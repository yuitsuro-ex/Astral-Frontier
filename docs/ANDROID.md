# Android: тестовая сборка

## Готовый APK

`build/astral-frontier-debug.apk` — подписанная debug-сборка 0.1.0 (versionCode 1), пакет `org.astralfrontier.game`, только ARM64 (`arm64-v8a`), Android 7.0/API 24 и выше. Target/compile API 36. Ориентация landscape. Рендерер `gl_compatibility` задан явно и для desktop, и для mobile. Размер около 26,4 MiB.

Скачать файл на телефон, открыть и разрешить установку этому источнику, если Android запросит её. Игра работает локально; разрешение на интернет в APK не запрашивается. Подпись тестовая, не предназначена для Google Play. Для обновлений тестовой версии сохраните debug keystore; он хранится вне проекта в `/workspace/.android-build/debug.keystore` и в APK не включён.

На телефоне или эмуляторе APK пока не запускался. В этой среде нет подключённого Android-устройства; adb также не может создать служебный каталог в read-only home. Это не помешало подписанному экспорту, но установка и runtime остаются непроверенными.

## Инструменты этой сборки

- Godot 4.6.3.stable.official.7d41c59c4.
- Официальный `android_debug.apk` из Godot 4.6.3 export templates, извлечён из ZIP частичной загрузкой с проверкой CRC. Шаблон установлен в `.runtime/data/godot/export_templates/4.6.3.stable/`.
- Android build-tools 36.0.0 и platform-tools 37.0.1 из официального репозитория Google, SHA-1 архивов сверены с repository metadata. Каталог: `/workspace/.android-build/sdk`.
- OpenJDK runtime 21.0.12.1 с keytool; компиляция Java/Gradle не использовалась. Для полноценной Gradle/AAB-сборки понадобится JDK и остальной SDK по документации Godot.
- Отдельный локальный RSA 2048 debug keystore, подписи APK v2/v3.

## Повторная сборка

```sh
./scripts/build_android.sh
```

Скрипт импортирует проект, выполняет стандартный Godot APK export без Gradle, проверяет подпись, 16 KiB page alignment, манифест и ZIP CRC, создаёт `.sha256` и `apk-info.txt`. Логи находятся в `.runtime/android-import.log` и `.runtime/android-export.log`. Проверки логики запускаются отдельно: `./tests/check.sh`.

На другой машине установите Godot и Android templates строго версии 4.6.3, поместите `android_debug.apk` в указанный выше локальный каталог. Можно задать `ANDROID_SDK_ROOT`, `JAVA_HOME`, `ASTRAL_DEBUG_KEYSTORE`. Скрипт ожидает build-tools 36.0.0 и platform-tools. При отсутствии ключа создаётся новый тестовый ключ; он не сможет обновить APK, подписанный другим ключом.

Для AAB позднее включить Gradle, установить необходимые platform SDK/NDK/CMake, настроить release-подпись и проверить актуальные требования Google Play. Текущая сборка — debug APK.

## Приёмка на устройстве

Проверить джойстик + прыжок + добычу одновременно; сохранение при уходе в фон и повторном запуске; 16:9/19.5:9/20:9 и safe area; прогрев 15 минут в 60/30 FPS; p95/p99 frame time, RAM и нагрев; физический геймпад. Изменение размера/прозрачности и переназначение кнопок пока отсутствует.
