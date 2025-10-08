import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/transparent_google_auth.dart';
import 'dart:io' show Platform;

class GoogleCalendarApiWidget extends StatefulWidget {
  final double? width;
  final double? height;

  const GoogleCalendarApiWidget({
    Key? key,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  State<GoogleCalendarApiWidget> createState() => _GoogleCalendarApiWidgetState();
}

class _GoogleCalendarApiWidgetState extends State<GoogleCalendarApiWidget> {
  bool _isLoading = true;
  String? _errorMessage;
  List<CalendarEvent> _events = [];
  
  // ID de tu calendario
  //final String _calendarId = '02fe70469480b93b808fbbbbc7fbcb453059735d42171b343626393437d2314b@group.calendar.google.com';
  String _calendarId = '';

  @override
  void initState() {
    super.initState();
    _initializeCalendar();
  }

  Future<void> _initializeCalendar() async {
    await _loadCalendarUrl();
    
    // Verificar si estamos en una plataforma no soportada
    if (!kIsWeb && Platform.isMacOS) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'La funcionalidad de calendario no está disponible en esta plataforma. Usa la versión web para acceso completo.';
      });
      return;
    }
    
    // Solo cargar eventos si hay un calendar ID configurado
    if (_calendarId.isNotEmpty) {
      await _loadCalendarEvents();
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });
    }
  }

  Future<void> _loadCalendarUrl() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _calendarId = prefs.getString('calendar_id') ?? '';
    });
  }
  Future<void> _loadCalendarEvents() async {
    // Verificar si hay calendar ID configurado
    if (_calendarId.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('🔄 Cargando eventos del calendario...');

      // Verificar autenticación
      if (!TransparentGoogleAuthService.isSignedIn) {
        throw Exception('Usuario no autenticado');
      }

      // Obtener headers de autenticación
      final authHeaders = TransparentGoogleAuthService.authHeaders;
      if (authHeaders == null) {
        throw Exception('No hay headers de autenticación disponibles');
      }

      // Construir URL de la API de Google Calendar
      final now = DateTime.now();
      final oneMonthFromNow = now.add(Duration(days: 30));
      
      final timeMin = now.toUtc().toIso8601String();
      final timeMax = oneMonthFromNow.toUtc().toIso8601String();

      final url = 'https://www.googleapis.com/calendar/v3/calendars/${Uri.encodeComponent(_calendarId)}/events'
          '?timeMin=$timeMin'
          '&timeMax=$timeMax'
          '&singleEvents=true'
          '&orderBy=startTime'
          '&maxResults=50';

      print('🔗 URL de la API: $url');

      // Hacer request a la API
      final response = await http.get(
        Uri.parse(url),
        headers: authHeaders,
      );

      print('📊 Respuesta de la API: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List<dynamic>? ?? [];
        
        final events = items.map((item) => CalendarEvent.fromJson(item)).toList();
        
        print('✅ Eventos cargados: ${events.length}');
        
        setState(() {
          _events = events;
          _isLoading = false;
        });
      } else {
        throw Exception('Error de API: ${response.statusCode} - ${response.body}');
      }

    } catch (error) {
      print('❌ Error cargando eventos: $error');
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  Widget _buildNotConfiguredView() {
    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height ?? 400,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.orange.shade300),
        borderRadius: BorderRadius.circular(12),
        color: Colors.orange.shade50,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_month_outlined,
            size: 64,
            color: Colors.orange.shade600,
          ),
          SizedBox(height: 16),
          Text(
            'Calendario aún no configurado',
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
              'Ve a la página de configuración para establecer la URL de tu calendario de Google',
              style: TextStyle(
                color: Colors.orange.shade600,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _initializeCalendar,
            icon: Icon(Icons.refresh),
            label: Text('Verificar configuración'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height ?? 500,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue.shade300),
        borderRadius: BorderRadius.circular(12),
        color: Colors.blue.shade50,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
          ),
          SizedBox(height: 16),
          Text(
            'Cargando eventos del calendario...',
            style: TextStyle(
              color: Colors.blue.shade700,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height ?? 400,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.red.shade300),
        borderRadius: BorderRadius.circular(12),
        color: Colors.red.shade50,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.red.shade600,
          ),
          SizedBox(height: 16),
          Text(
            'Error cargando calendario',
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
              _errorMessage ?? 'No se pudo cargar el calendario',
              style: TextStyle(
                color: Colors.red.shade600,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _initializeCalendar,
            icon: Icon(Icons.refresh),
            label: Text('Reintentar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsView() {
    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height ?? 600,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.green.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Header del calendario
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  color: Colors.green.shade700,
                  size: 24,
                ),
                SizedBox(width: 12),
                Text(
                  'Próximos eventos (${_events.length})',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Spacer(),
                IconButton(
                  onPressed: _initializeCalendar,
                  icon: Icon(
                    Icons.refresh,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
          
          // Lista de eventos
          Expanded(
            child: _events.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No hay eventos próximos',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _events.length,
                    itemBuilder: (context, index) {
                      final event = _events[index];
                      return _buildEventCard(event);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(CalendarEvent event) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: event.isToday ? Colors.blue.shade100 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            event.isAllDay ? Icons.event : Icons.schedule,
            color: event.isToday ? Colors.blue.shade700 : Colors.grey.shade600,
          ),
        ),
        title: Text(
          event.title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: event.isToday ? Colors.blue.shade700 : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(event.dateTimeText),
            if (event.location != null) ...[
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      event.location!,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: event.isToday
            ? Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade600,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'HOY',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingView();
    }

    if (_calendarId.isEmpty) {
      return _buildNotConfiguredView();
    }

    if (_errorMessage != null) {
      return _buildErrorView();
    }

    return _buildEventsView();
  }
}

// Modelo para eventos del calendario
class CalendarEvent {
  final String id;
  final String title;
  final DateTime? startTime;
  final DateTime? endTime;
  final bool isAllDay;
  final String? location;
  final String? description;

  CalendarEvent({
    required this.id,
    required this.title,
    this.startTime,
    this.endTime,
    this.isAllDay = false,
    this.location,
    this.description,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    final start = json['start'];
    final end = json['end'];
    
    DateTime? startTime;
    DateTime? endTime;
    bool isAllDay = false;

    if (start != null) {
      if (start['date'] != null) {
        // Evento de todo el día
        startTime = DateTime.parse(start['date']);
        isAllDay = true;
      } else if (start['dateTime'] != null) {
        // Evento con hora específica
        startTime = DateTime.parse(start['dateTime']);
      }
    }

    if (end != null) {
      if (end['date'] != null) {
        endTime = DateTime.parse(end['date']);
      } else if (end['dateTime'] != null) {
        endTime = DateTime.parse(end['dateTime']);
      }
    }

    return CalendarEvent(
      id: json['id'] ?? '',
      title: json['summary'] ?? 'Sin título',
      startTime: startTime,
      endTime: endTime,
      isAllDay: isAllDay,
      location: json['location'],
      description: json['description'],
    );
  }

  bool get isToday {
    if (startTime == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(startTime!.year, startTime!.month, startTime!.day);
    return today == eventDay;
  }

  String get dateTimeText {
    if (startTime == null) return '';

    if (isAllDay) {
      return 'Todo el día - ${_formatDate(startTime!)}';
    }

    final start = _formatDateTime(startTime!);
    if (endTime != null) {
      final end = _formatTime(endTime!);
      return '$start - $end';
    }

    return start;
  }

  String _formatDate(DateTime date) {
    final months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    return '${date.day} de ${months[date.month - 1]}';
  }

  String _formatDateTime(DateTime date) {
    return '${_formatDate(date)} a las ${_formatTime(date)}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}