import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io' show Platform;

class TransparentGoogleAuthService {
  static GoogleSignIn? _googleSignIn;
  static GoogleSignInAccount? _currentUser;
  static Map<String, String>? _authHeaders;
  
  // Scopes necesarios para Google Calendar
  static const List<String> _scopes = [
    'https://www.googleapis.com/auth/calendar.readonly',
    'https://www.googleapis.com/auth/userinfo.email',
    'https://www.googleapis.com/auth/userinfo.profile',
  ];

  static GoogleSignIn get _instance {
    if (_googleSignIn == null) {
      final clientId = dotenv.env['GOOGLE_CLIENT_ID'];
      
      if (kIsWeb) {
        _googleSignIn = GoogleSignIn(
          clientId: clientId,
          scopes: _scopes,
          // Configuración específica para web
          signInOption: SignInOption.standard,
        );
      } else {
        _googleSignIn = GoogleSignIn(
          scopes: _scopes,
          signInOption: SignInOption.standard,
        );
      }
    }
    return _googleSignIn!;
  }

  // Getter para usuario actual
  static GoogleSignInAccount? get currentUser => _currentUser;

  // Getter para verificar si está logueado
  static bool get isSignedIn => _currentUser != null;

  // Getter para headers de autenticación
  static Map<String, String>? get authHeaders => _authHeaders;

  // Verificar si la plataforma soporta Google Sign-In
  static bool get _isPlatformSupported {
    if (kIsWeb) return true;
    
    // En Flutter, verificamos si estamos en una plataforma móvil soportada
    // Nota: macOS puede tener problemas con Google Sign-In
    try {
      if (!kIsWeb && Platform.isMacOS) {
        print('⚠️ macOS detectado - autenticación puede ser limitada');
        return false;
      }
      return true;
    } catch (e) {
      // Si no podemos detectar la plataforma, asumimos que está soportada
      return true;
    }
  }

  // Inicialización automática y transparente
  static Future<bool> initializeTransparentAuth() async {
    try {
      print('🔐 Iniciando autenticación transparente...');
      
      // Verificar si la plataforma está soportada
      if (!_isPlatformSupported) {
        print('⚠️ Plataforma no soportada para Google Sign-In');
        return false;
      }
      
      // Intentar login silencioso primero
      final user = await _instance.signInSilently();
      
      if (user != null) {
        print('✅ Login silencioso exitoso: ${user.email}');
        _currentUser = user;
        await _setupAuthHeaders();
        return true;
      }

      // Si no hay login silencioso, intentar login interactivo UNA VEZ
      print('⚠️ Login silencioso falló, intentando login interactivo...');
      final interactiveUser = await _instance.signIn();
      
      if (interactiveUser != null) {
        print('✅ Login interactivo exitoso: ${interactiveUser.email}');
        _currentUser = interactiveUser;
        await _setupAuthHeaders();
        return true;
      }

      print('❌ No se pudo autenticar');
      return false;
      
    } catch (error) {
      print('❌ Error en autenticación transparente: $error');
      // En caso de error, no crashear la app
      return false;
    }
  }

  // Configurar headers de autenticación para requests HTTP
  static Future<void> _setupAuthHeaders() async {
    if (_currentUser == null) return;
    
    try {
      final auth = await _currentUser!.authentication;
      _authHeaders = {
        'Authorization': 'Bearer ${auth.accessToken}',
        'Content-Type': 'application/json',
      };
      print('✅ Headers de autenticación configurados');
    } catch (error) {
      print('❌ Error configurando headers: $error');
    }
  }

  // Obtener URL del calendario con token de acceso
  static Future<String?> getAuthenticatedCalendarUrl() async {
    if (!isSignedIn) {
      print('❌ Usuario no autenticado para URL del calendario');
      return null;
    }

    try {
      print('🔍 Obteniendo autenticación para calendario...');
      final auth = await _currentUser!.authentication;
      
      print('🔍 Access token disponible: ${auth.accessToken != null}');
      print('🔍 ID token disponible: ${auth.idToken != null}');
      
      if (auth.accessToken == null) {
        print('❌ No hay access token disponible');
        return null;
      }

      // Probemos primero con la URL directa del calendario sin token
      // Google Calendar embebido NO necesita access token en la URL
      const baseUrl = 'https://calendar.google.com/calendar/embed';
      const calendarId = '02fe70469480b93b808fbbbbc7fbcb453059735d42171b343626393437d2314b%40group.calendar.google.com';
      
      // URL sin token de acceso (Google Calendar embebido usa cookies del navegador)
      final calendarUrl = '$baseUrl?src=$calendarId&ctz=America%2FHermosillo'
          '&showTitle=0&showNav=1&showDate=1&showCalendars=1&showTz=0'
          '&mode=WEEK&height=600&wkst=1&bgcolor=%23ffffff';

      print('✅ URL del calendario generada (sin token en URL)');
      print('🔗 URL: $calendarUrl');
      return calendarUrl;
      
    } catch (error) {
      print('❌ Error generando URL del calendario: $error');
      return null;
    }
  }

  // Verificar y renovar autenticación si es necesario
  static Future<bool> ensureAuthenticated() async {
    if (!isSignedIn) {
      return await initializeTransparentAuth();
    }

    try {
      // Verificar si el token sigue siendo válido
      final auth = await _currentUser!.authentication;
      if (auth.accessToken != null) {
        await _setupAuthHeaders();
        return true;
      }
    } catch (error) {
      print('⚠️ Token expirado, renovando autenticación...');
    }

    // Si el token expiró, renovar autenticación
    return await initializeTransparentAuth();
  }

  // Cerrar sesión (opcional)
  static Future<void> signOut() async {
    try {
      await _instance.signOut();
      _currentUser = null;
      _authHeaders = null;
      print('✅ Sesión cerrada');
    } catch (error) {
      print('❌ Error cerrando sesión: $error');
    }
  }

  // Cliente HTTP autenticado para requests adicionales
  static http.Client? getAuthenticatedHttpClient() {
    if (_authHeaders == null) return null;
    
    return http.Client();
  }
}