import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io' show Platform;


class TransparentGoogleAuthService {
  static GoogleSignIn? _googleSignIn;
  static GoogleSignInAccount? _currentUser;
  static Map<String, String>? _authHeaders;

  // Detectar plataforma actual
  static bool get isWeb => kIsWeb;
  static bool get isMacOS => !kIsWeb && Platform.isMacOS;
  static bool get isWindows => !kIsWeb && Platform.isWindows;
  static bool get isLinux => !kIsWeb && Platform.isLinux;
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get isIOS => !kIsWeb && Platform.isIOS;
  static bool get isDesktop => isMacOS || isWindows || isLinux;
  static bool get isMobile => isAndroid || isIOS;

  static GoogleSignIn get _instance {
    if (_googleSignIn == null) {
      final clientId = dotenv.env['GOOGLE_CLIENT_ID'];

      // For web we pass clientId as usual. For desktop (macOS/Windows/Linux)
      // the plugin accepts a clientId parameter as well — provide it when available
      // so the native OAuth flow can use the correct OAuth client for installed apps.
      if (kIsWeb) {
        _googleSignIn = GoogleSignIn(
          clientId: clientId,
          scopes: _scopes,
          signInOption: SignInOption.standard,
        );
      } else {
        if (clientId == null || clientId.isEmpty) {
          print(
            '⚠️ GOOGLE_CLIENT_ID no encontrado en .env — inicia sesión en Desktop podría fallar',
          );
        }

        _googleSignIn = GoogleSignIn(
          clientId: clientId,
          scopes: _scopes,
          signInOption: SignInOption.standard,
        );
      }
    }
    return _googleSignIn!;
  }

  // Scopes necesarios para Google Calendar
  static const List<String> _scopes = [
    'https://www.googleapis.com/auth/calendar',
    'https://www.googleapis.com/auth/userinfo.email',
    'https://www.googleapis.com/auth/userinfo.profile',
  ];

// Inicializar GoogleSignIn con configuración por plataforma
  static GoogleSignIn get instance {
    if (_googleSignIn == null) {
      if (isWeb) {
        // Para web: configuración específica con manejo de FedCM
        debugPrint('Configurando Google Sign-In para Web con soporte FedCM');
        _googleSignIn = GoogleSignIn(
          clientId: dotenv.env['GOOGLE_CLIENT_ID'],
          scopes: [
            'email',
            'profile',
            'openid',
          ],
          serverClientId: dotenv.env['GOOGLE_SERVER_CLIENT_ID'],
        );
      } else if (isMacOS || isIOS) {
        // ✅ CORRECCIÓN: macOS e iOS NO necesitan clientId en código
        // Solo se configura en Info.plist (GIDClientID)
        debugPrint('Configurando Google Sign-In para ${_getPlatformName()}');
        debugPrint('📱 Usando configuración desde Info.plist (GIDClientID)');
        _googleSignIn = GoogleSignIn(
          // NO especificar clientId - se lee automáticamente de Info.plist
          scopes: [
            'email',
            'https://www.googleapis.com/auth/calendar',
          ],
        );
      } else if (isAndroid) {
        // Para Android - se configura en google-services.json
        debugPrint('Configurando Google Sign-In para Android');
        _googleSignIn = GoogleSignIn(
          scopes: [
            'email',
            'https://www.googleapis.com/auth/calendar',
          ],
        );
      } else if (isWindows || isLinux) {
        // Para Windows/Linux - necesitan clientId explícito
        debugPrint('Configurando Google Sign-In para ${_getPlatformName()}');
        _googleSignIn = GoogleSignIn(
          clientId: dotenv.env['GOOGLE_CLIENT_ID_DESKTOP'],
          scopes: [
            'email',
            'https://www.googleapis.com/auth/calendar',
          ],
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
    // Allow all platforms but warn for known tricky platforms.
    try {
      if (!kIsWeb && Platform.isMacOS) {
        print(
          '⚠️ macOS detectado - asegúrate de haber añadido GIDClientID en macos/Runner/Info.plist y de usar un OAuth Client de tipo "Desktop" o "macOS"',
        );
      }
    } catch (e) {
      // ignore platform detection failures
    }
    return true;
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
  await instance.signOut();
  // Intentar login silencioso primero
  final user = await instance.signInSilently();

      if (user != null) {
        print('✅ Login silencioso exitoso: ${user.email}');
        _currentUser = user;
        await _setupAuthHeaders();
        return true;
      }

      // Si no hay login silencioso, intentar login interactivo UNA VEZ
      print('⚠️ Login silencioso falló, intentando login interactivo...');
  final interactiveUser = await instance.signIn();

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

///////
  // Método específico para web que maneja errores FedCM
  static Future<GoogleSignInAccount?> signInWeb() async {
    if (!isWeb) return null;
    
    try {
      debugPrint('Iniciando proceso de login web con manejo FedCM');
      
      // Paso 1: Intentar signInSilently
      debugPrint('Paso 1: Intentando login silencioso...');
      final silentAccount = await instance.signInSilently(suppressErrors: true);
      if (silentAccount != null) {
        debugPrint('✅ Login silencioso exitoso: ${silentAccount.email}');
        return silentAccount;
      }
      
      // Paso 2: Si falla, intentar signIn interactivo
      debugPrint('Paso 2: Login silencioso falló, intentando signIn interactivo...');
      await Future.delayed(const Duration(milliseconds: 500));
      
      final account = await instance.signIn();
      if (account != null) {
        debugPrint('✅ SignIn interactivo exitoso: ${account.email}');
        return account;
      }
      
      debugPrint('❌ Ambos métodos de login fallaron');
      return null;
      
    } catch (error) {
      debugPrint('❌ Error en login web: $error');
      
      if (error.toString().contains('IdentityCredentialError') || 
          error.toString().contains('unknown_reason')) {
        debugPrint('🔧 Error FedCM detectado - verificar configuración de dominio');
        throw Exception('Error de configuración FedCM: Verificar que localhost esté autorizado en Google Console');
      }
      
      return null;
    }
  }

  // Método para hacer login (adaptado para todas las plataformas)
  static Future<GoogleSignInAccount?> signIn() async {
    try {
      debugPrint('🔐 Iniciando sign-in en ${_getPlatformName()}');
      
      if (isWeb) {
        return await signInWeb();
      } else {
        // En desktop y móvil, usar signIn normal
        final GoogleSignInAccount? account = await instance.signIn();
        if (account != null) {
          debugPrint('✅ Usuario logueado en ${_getPlatformName()}: ${account.email}');
          return account;
        } else {
          debugPrint('⚠️ signIn() retornó null en ${_getPlatformName()}');
        }
      }
    } catch (error) {
      debugPrint('❌ Error en Google Sign-In (${_getPlatformName()}): $error');
      
      // Diagnóstico específico para macOS
      if (isMacOS && error.toString().contains('client_secret')) {
        debugPrint('');
        debugPrint('🔍 DIAGNÓSTICO DEL ERROR EN MACOS:');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        debugPrint('El error "client_secret is missing" indica que:');
        debugPrint('1. Estás usando un Client ID de tipo "Web Application" (incorrecto)');
        debugPrint('2. Necesitas crear un Client ID de tipo "iOS" en Google Cloud Console');
        debugPrint('3. El Bundle ID debe ser: com.example.flutterCalendario');
        debugPrint('4. NO incluir clientId en el código para macOS');
        debugPrint('5. El GIDClientID en Info.plist debe ser del tipo iOS');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        debugPrint('');
      }
      
      rethrow;
    }
    return null;
  }
  // Método para login silencioso
  static Future<GoogleSignInAccount?> signInSilently() async {
    try {
      debugPrint('🔄 Intentando login silencioso en ${_getPlatformName()}');
      
      if (isWeb) {
        final GoogleSignInAccount? account = await instance.signInSilently(suppressErrors: true);
        if (account != null) {
          debugPrint('✅ Login silencioso exitoso en web: ${account.email}');
          return account;
        }
      } else {
        final GoogleSignInAccount? account = await instance.signInSilently();
        if (account != null) {
          debugPrint('✅ Login silencioso exitoso en ${_getPlatformName()}: ${account.email}');
          return account;
        }
      }
      debugPrint('⚠️ Login silencioso no disponible en ${_getPlatformName()}');
    } catch (error) {
      debugPrint('⚠️ Error en login silencioso (${_getPlatformName()}): $error');
    }
    return null;
  }

  // Obtener usuario actual
  //static GoogleSignInAccount? get currentUser => instance.currentUser;

  // Verificar si está logueado
  //static bool get isSignedIn => currentUser != null;

  // Obtener token de autenticación
  static Future<GoogleSignInAuthentication?> getAuthentication() async {
    try {
      final account = currentUser;
      if (account != null) {
        return await account.authentication;
      }
    } catch (error) {
      debugPrint('❌ Error obteniendo autenticación: $error');
    }
    return null;
  }
  // Desconectar completamente (revoca tokens)
  static Future<void> disconnect() async {
    try {
      await instance.disconnect();
      debugPrint('🔌 Usuario desconectado completamente en ${_getPlatformName()}');
    } catch (error) {
      debugPrint('❌ Error en desconexión (${_getPlatformName()}): $error');
    }
  }
  
  // Obtener nombre de plataforma para logs
  static String _getPlatformName() {
    if (isWeb) return 'Web';
    if (isMacOS) return 'macOS';
    if (isWindows) return 'Windows';
    if (isLinux) return 'Linux';
    if (isAndroid) return 'Android';
    if (isIOS) return 'iOS';
    return 'Desconocida';
  }
//////
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
      const calendarId =
          '02fe70469480b93b808fbbbbc7fbcb453059735d42171b343626393437d2314b%40group.calendar.google.com';

      // URL sin token de acceso (Google Calendar embebido usa cookies del navegador)
      final calendarUrl =
          '$baseUrl?src=$calendarId&ctz=America%2FHermosillo'
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

  // Re-autenticar o asegurar autenticación (para AgendaPage)
  static Future<bool> reAuthenticate() async {
    print('Attempting to re-authenticate...');
    final result = await ensureAuthenticated();
    if (result) {
      print('Re-authentication successful.');
    } else {
      print('Re-authentication failed.');
    }
    return result;
  }

  // Obtener información del token para depuración
  static Future<Map<String, String?>> debugTokenInfo() async {
    final auth = await getAuthentication();
    return {
      'accessToken': auth?.accessToken,
      'idToken': auth?.idToken,
    };
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
