import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/transparent_google_auth.dart';
import 'calendar_api_widget.dart';
import 'dart:io' show Platform;

// Widget principal que usa la Google Calendar API
class MiCalendarioConAPI extends StatelessWidget {
  const MiCalendarioConAPI({Key? key}) : super(key: key);

  // Verificar si estamos en una plataforma no soportada
  bool get _isPlatformUnsupported {
    if (kIsWeb) return false; // Web siempre está soportado
    
    try {
      return Platform.isMacOS; // macOS puede tener problemas
    } catch (e) {
      return false; // Si no podemos detectar, asumimos que está soportado
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = TransparentGoogleAuthService.isSignedIn;
    final user = TransparentGoogleAuthService.currentUser;
    final isPlatformUnsupported = _isPlatformUnsupported;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(
                isPlatformUnsupported ? Icons.warning : (isAuthenticated ? Icons.event_available : Icons.warning_amber),
                color: isPlatformUnsupported ? Colors.red : (isAuthenticated ? Colors.green : Colors.orange),
                size: 28,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mi Calendario',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: isPlatformUnsupported ? Colors.red : (isAuthenticated ? Colors.green : Colors.orange),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          isPlatformUnsupported ? Icons.error : (isAuthenticated ? Icons.verified_user : Icons.warning_amber),
                          size: 16,
                          color: isPlatformUnsupported ? Colors.red.shade600 : (isAuthenticated ? Colors.green.shade600 : Colors.orange.shade600),
                        ),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            isPlatformUnsupported 
                              ? 'Funcionalidad limitada en esta plataforma'
                              : (isAuthenticated 
                                ? 'Conectado: ${user?.displayName ?? user?.email ?? "Usuario autenticado"}'
                                : 'No autenticado'),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isPlatformUnsupported ? Colors.red.shade600 : (isAuthenticated ? Colors.green.shade600 : Colors.orange.shade600),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (isAuthenticated && !isPlatformUnsupported) ...[
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.api,
                            size: 16,
                            color: Colors.blue.shade600,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Usando Google Calendar API',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.blue.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: isPlatformUnsupported 
                ? _buildPlatformUnsupportedView(context)
                : (isAuthenticated
                    ? GoogleCalendarApiWidget(
                        height: kIsWeb ? 600 : 500,
                      )
                    : _buildNotAuthenticatedView(context)),
          ),
        ),
        SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPlatformUnsupportedView(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 400,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.red.shade300),
        borderRadius: BorderRadius.circular(12),
        color: Colors.red.shade50,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.desktop_access_disabled,
            size: 64,
            color: Colors.red.shade600,
          ),
          SizedBox(height: 16),
          Text(
            'Plataforma no soportada',
            style: TextStyle(
              color: Colors.red.shade700,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'El calendario de Google no está disponible en esta plataforma. Te recomendamos usar la versión web.',
              style: TextStyle(
                color: Colors.red.shade600,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.blue.shade600,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Usa la versión web para acceso completo',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotAuthenticatedView(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 400,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.orange.shade300),
        borderRadius: BorderRadius.circular(12),
        color: Colors.orange.shade50,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_circle,
            size: 64,
            color: Colors.orange.shade600,
          ),
          SizedBox(height: 16),
          Text(
            'Autenticación requerida',
            style: TextStyle(
              color: Colors.orange.shade700,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Necesitas autenticarte con Google para ver tu calendario',
              style: TextStyle(
                color: Colors.orange.shade600,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              // Intentar autenticación
              await TransparentGoogleAuthService.initializeTransparentAuth();
            },
            icon: Icon(Icons.login),
            label: Text('Iniciar sesión con Google'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}