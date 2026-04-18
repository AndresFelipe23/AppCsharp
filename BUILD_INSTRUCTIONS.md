# Instrucciones para Generar App Bundles

## Configuración Completada

✅ Package name cambiado a: `com.afesdev.app`
✅ Nombre de la app: `Aprende C#`
✅ Configuración de producción habilitada (minify, proguard)
✅ Bundle identifier iOS: `com.afesdev.app`

## Pre-requisitos

1. **Android:**
   - Android SDK instalado
   - Java JDK 17 o superior
   - Keystore configurado (ver sección de firma)

2. **iOS:**
   - macOS con Xcode instalado
   - Certificados de desarrollo/distribución configurados en Apple Developer

## Configurar Firma para Android (Solo una vez)

### 1. Generar Keystore

**Para Windows (PowerShell):**

```powershell
cd App/android
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

**Para Windows (CMD):**

```cmd
cd App\android
"C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

**Para Linux/Mac:**

```bash
cd App/android
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

**Nota:** 
- Guarda la contraseña y el alias de forma segura
- El keystore se creará en la carpeta `App/android/`
- Si tu instalación de Android Studio está en otra ubicación, ajusta la ruta del keytool

### 2. Crear archivo key.properties

Crea el archivo `App/android/key.properties`:

**Para Windows:**
```properties
storePassword=<tu-contraseña-del-keystore>
keyPassword=<tu-contraseña-de-la-key>
keyAlias=upload
storeFile=upload-keystore.jks
```

**Para Linux/Mac:**
```properties
storePassword=<tu-contraseña-del-keystore>
keyPassword=<tu-contraseña-de-la-key>
keyAlias=upload
storeFile=<ruta-al-keystore>/upload-keystore.jks
```

**Nota:** En Windows, si el keystore está en `App/android/`, usa solo el nombre del archivo. En Linux/Mac, usa la ruta completa.

### 3. Actualizar build.gradle.kts

Actualiza `App/android/app/build.gradle.kts` en la sección `buildTypes`:

```kotlin
buildTypes {
    release {
        val keystoreProperties = Properties()
        val keystorePropertiesFile = rootProject.file("key.properties")
        if (keystorePropertiesFile.exists()) {
            keystoreProperties.load(FileInputStream(keystorePropertiesFile))
        }
        signingConfig = signingConfigs.create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
        isMinifyEnabled = true
        isShrinkResources = true
        proguardFiles(
            getDefaultProguardFile("proguard-android-optimize.txt"),
            "proguard-rules.pro"
        )
    }
}
```

Y agrega al inicio del archivo:

```kotlin
import java.util.Properties
import java.io.FileInputStream
```

## Generar App Bundle para Android

### Comando:

```bash
cd App
flutter build appbundle --release
```

### Ubicación del archivo generado:

```
App/build/app/outputs/bundle/release/app-release.aab
```

### Subir a Google Play Console:

1. Ve a [Google Play Console](https://play.google.com/console)
2. Selecciona tu app o crea una nueva
3. Ve a "Producción" > "Crear nueva versión"
4. Sube el archivo `app-release.aab`

## Generar IPA para iOS

### 1. Abrir proyecto en Xcode:

```bash
cd App/ios
open Runner.xcworkspace
```

### 2. Configurar en Xcode:

- Selecciona el target "Runner"
- Ve a "Signing & Capabilities"
- Selecciona tu equipo de desarrollo
- Verifica que el Bundle Identifier sea: `com.afesdev.app`

### 3. Generar desde Flutter:

```bash
cd App
flutter build ipa --release
```

### Ubicación del archivo generado:

```
App/build/ios/ipa/app.ipa
```

### Alternativa: Generar desde Xcode

1. Abre `Runner.xcworkspace` en Xcode
2. Selecciona "Any iOS Device" como destino
3. Product > Archive
4. Una vez completado, haz clic en "Distribute App"
5. Sigue el asistente para subir a App Store Connect

## Verificar la Build

### Android:

```bash
cd App
flutter build apk --release
```

Esto generará un APK en: `App/build/app/outputs/flutter-apk/app-release.apk`

### iOS:

```bash
cd App
flutter build ios --release
```

## Comandos Útiles

### Limpiar build anterior:

```bash
cd App
flutter clean
flutter pub get
```

### Verificar configuración:

```bash
cd App
flutter doctor -v
```

### Verificar que el package name es correcto:

**Android:**
```bash
cd App
grep -r "com.afesdev.app" android/app/build.gradle.kts
```

**iOS:**
```bash
cd App
grep -r "com.afesdev.app" ios/Runner.xcodeproj/project.pbxproj
```

## Notas Importantes

⚠️ **IMPORTANTE:** 
- Guarda el keystore de Android de forma segura. Si lo pierdes, no podrás actualizar la app en Google Play.
- Para iOS, necesitas una cuenta de Apple Developer activa ($99/año)
- Asegúrate de que todas las dependencias estén actualizadas antes de generar el bundle

## Troubleshooting

### Error: "Keystore file not found"
- Verifica que la ruta en `key.properties` sea correcta
- Usa ruta absoluta o relativa desde `android/`

### Error: "Signing config not found"
- Verifica que hayas actualizado `build.gradle.kts` correctamente
- Asegúrate de que `key.properties` existe y tiene los valores correctos

### Error iOS: "No signing certificate found"
- Abre Xcode y configura el signing automático
- O configura manualmente los certificados en Apple Developer
