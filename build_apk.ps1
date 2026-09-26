<#
    build_apk.ps1 — сборка APK/AAB «Литр До Дома» для RuStore.

    Что делает скрипт:
      1. проверяет, что Flutter доступен в PATH;
      2. при необходимости создаёт папку android/ (flutter create) — lib/ и
         pubspec.yaml при этом не перезаписываются;
      3. прописывает русское название приложения и портретную ориентацию
         в AndroidManifest.xml;
      4. по флагу -Icons генерирует иконку из assets/icon/app_icon.png;
      5. по флагу -Sounds генерирует 8-bit звуки в assets/audio;
      6. по флагу -NewKeystore создаёт ключ подписи и android/key.properties;
      7. выполняет flutter pub get, тесты и собирает APK или AAB.

    Примеры:
      pwsh -File build_apk.ps1                          # release APK
      pwsh -File build_apk.ps1 -Icons -Sounds           # иконка + звуки
      pwsh -File build_apk.ps1 -Bundle                  # AAB для RuStore
      pwsh -File build_apk.ps1 -SplitAbi                # APK под каждую архитектуру
      pwsh -File build_apk.ps1 -NewKeystore -StorePass "пароль" -KeyPass "пароль"
#>

[CmdletBinding()]
param(
    [string]$Org = 'com.litrdodoma',
    [string]$ProjectName = 'litr_do_doma',
    [string]$AppLabel = 'Литр До Дома',
    [switch]$InitAndroid,
    [switch]$Icons,
    [switch]$Sounds,
    [switch]$Bundle,
    [switch]$SplitAbi,
    [switch]$Debug,
    [switch]$NewKeystore,
    [string]$StorePass = '',
    [string]$KeyPass = ''
)

$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot
if (-not $root) {
    $root = Split-Path -Parent $MyInvocation.MyCommand.Path
}
Set-Location $root

function Write-Step([string]$text) {
    Write-Host ''
    Write-Host "==> $text" -ForegroundColor Cyan
}

function Fail([string]$text) {
    Write-Host ''
    Write-Host "ОШИБКА: $text" -ForegroundColor Red
    exit 1
}

Write-Host 'Литр До Дома — сборка для Android' -ForegroundColor Yellow
Write-Host "Каталог проекта: $root"

# --- 1. Flutter -------------------------------------------------------------
Write-Step 'Проверяю Flutter'
$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutterCmd) {
    Fail @'
Flutter не найден в PATH.
Установите Flutter SDK: https://docs.flutter.dev/get-started/install/windows
Затем добавьте <flutter>\bin в переменную PATH и запустите скрипт снова.
Проверка: flutter doctor
'@
}
Write-Host "Flutter: $($flutterCmd.Source)"
& flutter --version
if ($LASTEXITCODE -ne 0) {
    Fail 'flutter --version завершился с ошибкой. Запустите "flutter doctor".'
}

# --- 2. Папка android/ ------------------------------------------------------
$androidDir = Join-Path $root 'android'
if ($InitAndroid -or -not (Test-Path $androidDir)) {
    Write-Step 'Создаю платформенную папку android/ (flutter create)'
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('litr_platform_' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp | Out-Null
    & flutter create --platforms=android --org $Org --project-name $ProjectName $tmp
    if ($LASTEXITCODE -ne 0) {
        Fail 'flutter create завершился с ошибкой.'
    }
    Copy-Item -Recurse -Force (Join-Path $tmp 'android') $root
    $meta = Join-Path $tmp '.metadata'
    if (Test-Path $meta) {
        Copy-Item -Force $meta $root
    }
    Remove-Item -Recurse -Force $tmp
    Write-Host 'Папка android/ готова (lib/ и pubspec.yaml не изменялись)'
}
else {
    Write-Host 'Папка android/ уже есть — пропускаю генерацию'
}

# --- 3. AndroidManifest -----------------------------------------------------
Write-Step 'Настраиваю AndroidManifest.xml'
$manifest = Join-Path $root 'android/app/src/main/AndroidManifest.xml'
if (Test-Path $manifest) {
    $text = Get-Content -Raw -Encoding UTF8 $manifest
    $original = $text

    $text = [regex]::Replace($text, 'android:label="[^"]*"', 'android:label="' + $AppLabel + '"')

    if ($text -notmatch 'android:screenOrientation') {
        $replacement = 'android:name=".MainActivity"' + "`r`n            " + 'android:screenOrientation="portrait"'
        $text = [regex]::Replace($text, 'android:name="\.MainActivity"', $replacement)
    }

    if ($text -ne $original) {
        Set-Content -Path $manifest -Value $text -Encoding UTF8 -NoNewline
        Write-Host "Название приложения: $AppLabel, ориентация: portrait"
    }
    else {
        Write-Host 'AndroidManifest.xml уже настроен'
    }
}
else {
    Write-Warning "Не найден $manifest — проверьте структуру android/ вручную"
}

# --- 4. Звуки (необязательно) ----------------------------------------------
if ($Sounds) {
    Write-Step 'Генерирую 8-bit звуки'
    & dart run tool/gen_sounds.dart
    if ($LASTEXITCODE -ne 0) {
        Write-Warning 'Не удалось сгенерировать звуки — останутся текущие файлы'
    }
}

# --- 5. Иконки (необязательно) ----------------------------------------------
if ($Icons) {
    Write-Step 'Иконки приложения из assets/icon/app_icon.png'
    & flutter pub add --dev flutter_launcher_icons
    if ($LASTEXITCODE -eq 0) {
        & dart run flutter_launcher_icons
        if ($LASTEXITCODE -ne 0) {
            Write-Warning 'flutter_launcher_icons не сработал — останется стандартная иконка'
        }
    }
    else {
        Write-Warning 'Не удалось добавить flutter_launcher_icons — останется стандартная иконка'
    }
}

# --- 6. Ключ подписи (необязательно) ---------------------------------------
if ($NewKeystore) {
    Write-Step 'Создаю ключ подписи'
    if ([string]::IsNullOrWhiteSpace($StorePass) -or [string]::IsNullOrWhiteSpace($KeyPass)) {
        Fail 'Укажите -StorePass и -KeyPass: pwsh -File build_apk.ps1 -NewKeystore -StorePass "..." -KeyPass "..."'
    }
    $keytool = Get-Command keytool -ErrorAction SilentlyContinue
    if (-not $keytool -and $env:JAVA_HOME) {
        $candidate = Join-Path $env:JAVA_HOME 'bin\keytool.exe'
        if (Test-Path $candidate) {
            $keytool = Get-Item $candidate
        }
    }
    if (-not $keytool) {
        Fail 'keytool не найден. Он входит в JDK (Android Studio -> Embedded JDK) — добавьте его в PATH.'
    }
    $jks = Join-Path $root 'android/app/upload-keystore.jks'
    $dname = 'CN=' + $AppLabel + ', O=Indie, C=RU'
    & $keytool.Source -genkeypair -v -keystore $jks -alias upload -keyalg RSA -keysize 2048 -validity 10000 -storepass $StorePass -keypass $KeyPass -dname $dname
    if ($LASTEXITCODE -ne 0) {
        Fail 'keytool не смог создать ключ.'
    }
    $props = @(
        'storePassword=' + $StorePass,
        'keyPassword=' + $KeyPass,
        'keyAlias=upload',
        'storeFile=upload-keystore.jks'
    ) -join "`r`n"
    Set-Content -Path (Join-Path $root 'android/key.properties') -Value $props -Encoding UTF8 -NoNewline
    Write-Host ''
    Write-Host 'Ключ создан: android/app/upload-keystore.jks' -ForegroundColor Green
    Write-Host 'Пароли записаны в android/key.properties (файл в .gitignore).' -ForegroundColor Yellow
    Write-Host 'СОХРАНИТЕ ключ и пароли: без них нельзя выпустить обновление.' -ForegroundColor Yellow
}

# --- 7. Зависимости и сборка ------------------------------------------------
Write-Step 'flutter pub get'
& flutter pub get
if ($LASTEXITCODE -ne 0) {
    Fail 'flutter pub get завершился с ошибкой (проверьте интернет и версию Flutter).'
}

Write-Step 'Тесты'
& flutter test
if ($LASTEXITCODE -ne 0) {
    Write-Warning 'Тесты не прошли — сборка продолжается, но результат стоит проверить'
}

if ($Bundle) {
    Write-Step 'Сборка AAB (Google Play / RuStore)'
    if ($Debug) { & flutter build appbundle --debug } else { & flutter build appbundle --release }
}
else {
    Write-Step 'Сборка APK'
    $flutterArgs = @('build', 'apk')
    if ($Debug) { $flutterArgs += '--debug' } else { $flutterArgs += '--release' }
    if ($SplitAbi) { $flutterArgs += '--split-per-abi' }
    & flutter @flutterArgs
}

if ($LASTEXITCODE -ne 0) {
    Fail 'Сборка завершилась с ошибкой. Смотрите вывод выше.'
}

# --- 8. Результат -----------------------------------------------------------
Write-Step 'Готовые файлы'
$apkDir = Join-Path $root 'build/app/outputs/flutter-apk'
if (Test-Path $apkDir) {
    Get-ChildItem -Path $apkDir -Filter '*.apk' | ForEach-Object {
        Write-Host ('  APK: ' + $_.FullName) -ForegroundColor Green
    }
}
$aabDir = Join-Path $root 'build/app/outputs/bundle/release'
if (Test-Path $aabDir) {
    Get-ChildItem -Path $aabDir -Filter '*.aab' | ForEach-Object {
        Write-Host ('  AAB: ' + $_.FullName) -ForegroundColor Green
    }
}

Write-Host ''
Write-Host 'Дальше: проверьте APK на телефоне (adb install -r <файл>.apk) и загрузите его в RuStore.' -ForegroundColor Yellow
Write-Host 'Подробности публикации — в RUSTORE.md' -ForegroundColor Yellow
