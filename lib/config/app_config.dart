class AppConfig {
  // URL base del backend
  // Cambia esta URL según tu configuración:
  // - Desarrollo local: 'http://localhost:3000'
  // - Servidor remoto: 'https://aprendecsharp.site'
  // - Emulador Android: 'http://10.0.2.2:3000'
  // - Emulador iOS: 'http://localhost:3000'
  //
  // Producción: API pública en aprendecsharp.site
  static const String baseUrl = 'https://www.aprendecsharp.site';
  // Timeout para las peticiones HTTP (en segundos)
  static const int httpTimeout = 30;
}
