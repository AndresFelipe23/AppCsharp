# AprendeCsharp2026 — App (Flutter)

Aplicación móvil en **Flutter** para consumir el contenido del proyecto **AprendeCsharp2026**: cursos, lecciones y **prácticas** (ejercicios) de C#. La app se conecta al **backend** (NestJS) para obtener datos y guardar el progreso del usuario.

## Requisitos

- **Flutter SDK** instalado y configurado (`flutter doctor` sin errores críticos).
- Un emulador/dispositivo Android/iOS o Chrome/Edge (si ejecutas en web).
- **Backend** levantado y accesible desde el dispositivo/emulador.

## Cómo ejecutar

Desde la carpeta `App/`:

```bash
flutter pub get
flutter run
```

Si tienes varios dispositivos conectados:

```bash
flutter devices
flutter run -d <device_id>
```

## Backend / API

La app requiere que el backend esté corriendo (por ejemplo con `nest start`) y que la **base URL** apunte al host correcto según tu entorno:

- **Android Emulator**: normalmente `http://10.0.2.2:<puerto>` apunta a tu máquina local.
- **Dispositivo físico**: usa la IP LAN de tu PC, por ejemplo `http://192.168.1.50:<puerto>`.
- **Web**: suele funcionar con `http://localhost:<puerto>` (depende de CORS).

Si necesitas cambiar la URL del backend, busca en el código de la app la configuración de API (por ejemplo archivos tipo `api.dart`, `config.dart`, `constants.dart` o servicios HTTP en `lib/`).

## Pantallas principales

- **Inicio**: acceso a secciones principales y navegación del curso.
- **Ejercicios/Prácticas**: listado, detalle y envío de respuestas.

## Estructura (alto nivel)

- `lib/`: código fuente de la app (pantallas, servicios, modelos, widgets).
- `pubspec.yaml`: dependencias y assets.

## Notas

- Las prácticas de tipo **Escribir código** se validan en el backend comparando las declaraciones esperadas con lo enviado por la app.
- Si ves errores de red, revisa: URL/puerto, firewall, y que el backend sea accesible desde el dispositivo/emulador.
