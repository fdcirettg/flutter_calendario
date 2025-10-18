import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/transparent_google_auth.dart';
// Platform checks removed; rely on authentication state instead.

class CalendarWeekWidget extends StatefulWidget {
  const CalendarWeekWidget({Key? key}) : super(key: key);

  @override
  State<CalendarWeekWidget> createState() => _CalendarWeekWidgetState();
}

class _CalendarWeekWidgetState extends State<CalendarWeekWidget> {
  bool _isLoading = true;
  String? _errorMessage;
  List<CalendarEvent> _events = [];
  String _calendarId = '';
  DateTime _currentWeekStart = DateTime.now();

  @override
  void initState() {
    super.initState();
    _currentWeekStart = _getWeekStart(DateTime.now());
    _initializeCalendar();
  }

  DateTime _getWeekStart(DateTime date) {
    // Obtener el lunes de la semana actual
    final daysFromMonday = date.weekday - 1;
    return DateTime(date.year, date.month, date.day).subtract(Duration(days: daysFromMonday));
  }

  Future<void> _initializeCalendar() async {
    await _loadCalendarUrl();
    
    if (_calendarId.isNotEmpty) {
      await _loadWeekEvents();
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

  Future<void> _loadWeekEvents() async {
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
      print('🗓️ Cargando eventos de la semana...');

      if (!TransparentGoogleAuthService.isSignedIn) {
        throw Exception('Usuario no autenticado');
      }

      final authHeaders = TransparentGoogleAuthService.authHeaders;
      if (authHeaders == null) {
        throw Exception('No hay headers de autenticación disponibles');
      }

      // Calcular fechas de la semana (lunes a domingo)
      final weekEnd = _currentWeekStart.add(Duration(days: 7));
      
      final timeMin = _currentWeekStart.toUtc().toIso8601String();
      final timeMax = weekEnd.toUtc().toIso8601String();

      final url = 'https://www.googleapis.com/calendar/v3/calendars/${Uri.encodeComponent(_calendarId)}/events'
          '?timeMin=$timeMin'
          '&timeMax=$timeMax'
          '&singleEvents=true'
          '&orderBy=startTime'
          '&maxResults=100';

      print('🔗 URL de la API (semana): $url');

      final response = await http.get(
        Uri.parse(url),
        headers: authHeaders,
      );

      print('📊 Respuesta de la API: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List<dynamic>? ?? [];
        
        final events = items.map((item) => CalendarEvent.fromJson(item)).toList();
        
        print('✅ Eventos de la semana cargados: ${events.length}');
        
        setState(() {
          _events = events;
          _isLoading = false;
        });
      } else {
        throw Exception('Error de API: ${response.statusCode} - ${response.body}');
      }

    } catch (error) {
      print('❌ Error cargando eventos de la semana: $error');
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  void _previousWeek() {
    setState(() {
      _currentWeekStart = _currentWeekStart.subtract(Duration(days: 7));
    });
    _loadWeekEvents();
  }

  void _nextWeek() {
    setState(() {
      _currentWeekStart = _currentWeekStart.add(Duration(days: 7));
    });
    _loadWeekEvents();
  }

  void _goToCurrentWeek() {
    setState(() {
      _currentWeekStart = _getWeekStart(DateTime.now());
    });
    _loadWeekEvents();
  }

  String _formatWeekRange() {
    final weekEnd = _currentWeekStart.add(Duration(days: 6));
    final months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];

    if (_currentWeekStart.month == weekEnd.month) {
      return '${_currentWeekStart.day} - ${weekEnd.day} de ${months[_currentWeekStart.month - 1]} ${_currentWeekStart.year}';
    } else {
      return '${_currentWeekStart.day} de ${months[_currentWeekStart.month - 1]} - ${weekEnd.day} de ${months[weekEnd.month - 1]} ${weekEnd.year}';
    }
  }

  List<CalendarEvent> _getEventsForDay(DateTime day) {
    return _events.where((event) {
      if (event.startTime == null) return false;
      final eventDay = DateTime(event.startTime!.year, event.startTime!.month, event.startTime!.day);
      final targetDay = DateTime(day.year, day.month, day.day);
      return eventDay == targetDay;
    }).toList();
  }

  Widget _buildNotConfiguredView() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.orange.shade300),
        borderRadius: BorderRadius.circular(12),
        color: Colors.orange.shade50,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.view_week_outlined,
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
            'Cargando vista semanal...',
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
            'Error cargando vista semanal',
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
              _errorMessage ?? 'No se pudo cargar la vista semanal',
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

  Widget _buildWeekView() {
    final daysOfWeek = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    
    return Column(
      children: [
        // Controles de navegación de semana
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: _previousWeek,
                    icon: Icon(Icons.chevron_left),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.blue.shade100,
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        _formatWeekRange(),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      SizedBox(height: 4),
                      TextButton(
                        onPressed: _goToCurrentWeek,
                        child: Text(
                          'Ir a semana actual',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: _nextWeek,
                    icon: Icon(Icons.chevron_right),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.blue.shade100,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        SizedBox(height: 16),
        
        // Vista de la semana
        Expanded(
          child: Row(
            children: List.generate(7, (index) {
              final day = _currentWeekStart.add(Duration(days: index));
              final dayEvents = _getEventsForDay(day);
              final isToday = _isToday(day);
              
              return Expanded(
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isToday ? Colors.blue.shade400 : Colors.grey.shade300,
                      width: isToday ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: isToday ? Colors.blue.shade50 : Colors.white,
                  ),
                  child: Column(
                    children: [
                      // Header del día
                      Container(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isToday ? Colors.blue.shade600 : Colors.grey.shade100,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              daysOfWeek[index],
                              style: TextStyle(
                                color: isToday ? Colors.white : Colors.grey.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '${day.day}',
                              style: TextStyle(
                                color: isToday ? Colors.white : Colors.grey.shade800,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Eventos del día
                      Expanded(
                        child: dayEvents.isEmpty
                            ? Center(
                                child: Text(
                                  'Sin eventos',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 10,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: EdgeInsets.all(4),
                                itemCount: dayEvents.length,
                                itemBuilder: (context, eventIndex) {
                                  final event = dayEvents[eventIndex];
                                  return Container(
                                    margin: EdgeInsets.only(bottom: 4),
                                    padding: EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.green.shade300),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          event.title,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green.shade800,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (!event.isAllDay && event.startTime != null) ...[
                                          SizedBox(height: 2),
                                          Text(
                                            _formatTime(event.startTime!),
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: Colors.green.shade600,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  bool _isToday(DateTime day) {
    final now = DateTime.now();
    return day.year == now.year && day.month == now.month && day.day == now.day;
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
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

    return _buildWeekView();
  }
}

// Reutilizar el modelo CalendarEvent del otro widget
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
        startTime = DateTime.parse(start['date']);
        isAllDay = true;
      } else if (start['dateTime'] != null) {
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
}