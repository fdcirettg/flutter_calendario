import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'app_scaffold.dart';
import 'settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'widgets/calendar_api_widget.dart' show CalendarEvent;
import 'services/transparent_google_auth.dart';

class AgendaPage extends StatefulWidget {
  AgendaPage({super.key});

  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> {
  final SettingsController settingsController = Get.put(SettingsController());

  String _calendarId = '';
  bool _isLoading = true;
  String? _errorMessage;
  List<CalendarEvent> _events = [];
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _loadCalendarId();
    if (_calendarId.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });
      return;
    }

    await _fetchEventsForDay(_selectedDate);
  }

  Future<void> _loadCalendarId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _calendarId = prefs.getString('calendar_id') ?? '';
    });
  }

  Uri _eventsUriForRange(DateTime from, DateTime to) {
    final timeMin = from.toUtc().toIso8601String();
    final timeMax = to.toUtc().toIso8601String();
    final encoded = Uri.encodeComponent(_calendarId);
    return Uri.parse('https://www.googleapis.com/calendar/v3/calendars/$encoded/events?timeMin=$timeMin&timeMax=$timeMax&singleEvents=true&orderBy=startTime&maxResults=250');
  }

  Future<void> _fetchEventsForDay(DateTime date) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (_calendarId.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    if (!TransparentGoogleAuthService.isSignedIn) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Usuario no autenticado. Ve a Login.';
      });
      return;
    }

    try {
      final start = DateTime(date.year, date.month, date.day);
      final end = start.add(Duration(days: 1));
      final uri = _eventsUriForRange(start, end);
      final headers = TransparentGoogleAuthService.authHeaders;
      if (headers == null) throw Exception('No hay headers de auth');

      final res = await http.get(uri, headers: headers);
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final items = (data['items'] as List<dynamic>?) ?? [];
        final events = items.map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>)).toList();
        setState(() {
          _events = events;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error API: ${res.statusCode} ${res.body}';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _createEvent(Map<String, dynamic> body) async {
    if (_calendarId.isEmpty) return _showMessage('Calendario no configurado');
    final encoded = Uri.encodeComponent(_calendarId);
    final uri = Uri.parse('https://www.googleapis.com/calendar/v3/calendars/$encoded/events');
    final headers = TransparentGoogleAuthService.authHeaders;
    if (headers == null) return _showMessage('No autenticado');

    try {
      final res = await http.post(uri, headers: {...headers, 'Content-Type': 'application/json'}, body: json.encode(body));
      if (res.statusCode == 200 || res.statusCode == 201) {
        _showMessage('Evento creado');
        await _fetchEventsForDay(_selectedDate);
      } else {
        _showMessage('Error creando evento: ${res.statusCode} ${res.body}');
      }
    } catch (e) {
      _showMessage('Error creando evento: $e');
    }
  }

  Future<void> _updateEvent(String eventId, Map<String, dynamic> body) async {
    if (_calendarId.isEmpty) return _showMessage('Calendario no configurado');
    final encoded = Uri.encodeComponent(_calendarId);
    final uri = Uri.parse('https://www.googleapis.com/calendar/v3/calendars/$encoded/events/$eventId');
    final headers = TransparentGoogleAuthService.authHeaders;
    if (headers == null) return _showMessage('No autenticado');

    try {
      final res = await http.put(uri, headers: {...headers, 'Content-Type': 'application/json'}, body: json.encode(body));
      if (res.statusCode == 200) {
        _showMessage('Evento actualizado');
        await _fetchEventsForDay(_selectedDate);
      } else {
        _showMessage('Error actualizando evento: ${res.statusCode} ${res.body}');
      }
    } catch (e) {
      _showMessage('Error actualizando evento: $e');
    }
  }

  Future<void> _deleteEvent(String eventId) async {
    if (_calendarId.isEmpty) return _showMessage('Calendario no configurado');
    final encoded = Uri.encodeComponent(_calendarId);
    final uri = Uri.parse('https://www.googleapis.com/calendar/v3/calendars/$encoded/events/$eventId');
    final headers = TransparentGoogleAuthService.authHeaders;
    if (headers == null) return _showMessage('No autenticado');

    try {
      final res = await http.delete(uri, headers: headers);
      if (res.statusCode == 204) {
        _showMessage('Evento eliminado');
        await _fetchEventsForDay(_selectedDate);
      } else {
        _showMessage('Error eliminando evento: ${res.statusCode} ${res.body}');
      }
    } catch (e) {
      _showMessage('Error eliminando evento: $e');
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _showEventDialog({CalendarEvent? event}) async {
    final titleController = TextEditingController(text: event?.title ?? '');
    final descController = TextEditingController(text: event?.description ?? '');
    final locationController = TextEditingController(text: event?.location ?? '');
    bool isAllDay = event?.isAllDay ?? false;
    DateTime start = event?.startTime ?? DateTime.now();
    DateTime end = event?.endTime ?? start.add(Duration(hours: 1));

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setState) {
          return AlertDialog(
            title: Text(event == null ? 'Crear evento' : 'Editar evento'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: titleController, decoration: InputDecoration(labelText: 'Título')),
                  SizedBox(height: 8),
                  TextField(controller: descController, decoration: InputDecoration(labelText: 'Descripción')),
                  SizedBox(height: 8),
                  TextField(controller: locationController, decoration: InputDecoration(labelText: 'Lugar')),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Checkbox(value: isAllDay, onChanged: (v) => setState(() => isAllDay = v ?? false)),
                      Text('Todo el día'),
                    ],
                  ),
                  SizedBox(height: 8),
                  ListTile(
                    title: Text(isAllDay ? '${start.year}/${start.month}/${start.day}' : '${start.year}/${start.month}/${start.day} ${start.hour}:${start.minute.toString().padLeft(2,'0')}'),
                    leading: Icon(Icons.calendar_today),
                    onTap: () async {
                      final d = await showDatePicker(context: ctx, initialDate: start, firstDate: DateTime(2000), lastDate: DateTime(2100));
                      if (d != null) {
                        if (!isAllDay) {
                          final t = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(start));
                          if (t != null) start = DateTime(d.year, d.month, d.day, t.hour, t.minute);
                        } else {
                          start = DateTime(d.year, d.month, d.day);
                        }
                        setState(() {});
                      }
                    },
                  ),
                  if (!isAllDay)
                    ListTile(
                      title: Text('${end.year}/${end.month}/${end.day} ${end.hour}:${end.minute.toString().padLeft(2,'0')}'),
                      leading: Icon(Icons.access_time),
                      onTap: () async {
                        final d = await showDatePicker(context: ctx, initialDate: end, firstDate: DateTime(2000), lastDate: DateTime(2100));
                        if (d != null) {
                          final t = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(end));
                          if (t != null) end = DateTime(d.year, d.month, d.day, t.hour, t.minute);
                          setState(() {});
                        }
                      },
                    ),
                ],
              ),
            ),
            actions: [
              if (event != null)
                TextButton(onPressed: () async { Navigator.of(ctx).pop(); await _deleteEvent(event.id); }, child: Text('Eliminar', style: TextStyle(color: Colors.red))),
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Cancelar')),
              ElevatedButton(
                onPressed: () async {
                  final body = <String, dynamic>{
                    'summary': titleController.text,
                    'description': descController.text.isEmpty ? null : descController.text,
                    'location': locationController.text.isEmpty ? null : locationController.text,
                  };

                  if (isAllDay) {
                    body['start'] = {'date': '${start.year.toString().padLeft(4,'0')}-${start.month.toString().padLeft(2,'0')}-${start.day.toString().padLeft(2,'0')}'};
                    body['end'] = {'date': '${start.add(Duration(days:1)).year.toString().padLeft(4,'0')}-${start.add(Duration(days:1)).month.toString().padLeft(2,'0')}-${start.add(Duration(days:1)).day.toString().padLeft(2,'0')}' };
                  } else {
                    body['start'] = {'dateTime': start.toUtc().toIso8601String()};
                    body['end'] = {'dateTime': end.toUtc().toIso8601String()};
                  }

                  Navigator.of(ctx).pop();
                  if (event == null) {
                    await _createEvent(body);
                  } else {
                    await _updateEvent(event.id, body);
                  }
                },
                child: Text(event == null ? 'Crear' : 'Guardar'),
              ),
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Agenda',
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(icon: Icon(Icons.chevron_left), onPressed: () { setState(() { _selectedDate = _selectedDate.subtract(Duration(days:1)); }); _fetchEventsForDay(_selectedDate); }),
                Expanded(child: Center(child: Text('${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))),
                IconButton(icon: Icon(Icons.chevron_right), onPressed: () { setState(() { _selectedDate = _selectedDate.add(Duration(days:1)); }); _fetchEventsForDay(_selectedDate); }),
              ],
            ),
            SizedBox(height: 8),
            if (_isLoading) CircularProgressIndicator(),
            if (!_isLoading && _calendarId.isEmpty) ...[
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(border: Border.all(color: Colors.orange), borderRadius: BorderRadius.circular(8)),
                child: Column(children: [Text('Calendario no configurado.'), SizedBox(height:8), Text('Ve a Configuración para establecer el ID del calendario bajo la llave "calendar_id".')]),
              )
            ] else if (!_isLoading && _errorMessage != null) ...[
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(border: Border.all(color: Colors.red), borderRadius: BorderRadius.circular(8)),
                child: Text('Error: $_errorMessage'),
              )
            ] else ...[
              Expanded(
                child: _events.isEmpty
                    ? Center(child: Text('No hay eventos para este día'))
                    : ListView.builder(
                        itemCount: _events.length,
                        itemBuilder: (context, index) {
                          final ev = _events[index];
                          return Card(
                            child: ListTile(
                              title: Text(ev.title),
                              subtitle: Text(ev.dateTimeText),
                              trailing: IconButton(icon: Icon(Icons.edit), onPressed: () => _showEventDialog(event: ev)),
                              onLongPress: () async {
                                final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: Text('Eliminar'), content: Text('Eliminar evento "${ev.title}"?'), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('Cancelar')), TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text('Eliminar'))]));
                                if (ok == true) await _deleteEvent(ev.id);
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(icon: Icon(Icons.refresh), label: Text('Actualizar'), onPressed: () => _fetchEventsForDay(_selectedDate)),
                Row(children: [
                  ElevatedButton.icon(icon: Icon(Icons.add), label: Text('Nuevo evento'), onPressed: () => _showEventDialog()),
                  SizedBox(width: 8),
                  // Reautenticar y mostrar tokeninfo para depuración en desktop
                  TextButton.icon(
                    icon: Icon(Icons.lock_reset),
                    label: Text('Reautenticar'),
                    onPressed: () async {
                      final ok = await TransparentGoogleAuthService.reAuthenticate();
                      if (!ok) {
                        _showMessage('Reautenticación fallida');
                        return;
                      }

                      final info = await TransparentGoogleAuthService.debugTokenInfo();
                      await showDialog(context: context, builder: (ctx) => AlertDialog(title: Text('Token info'), content: SingleChildScrollView(child: Text(info == null ? 'No token' : info.toString())), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('OK'))]));
                      await _fetchEventsForDay(_selectedDate);
                    },
                  ),
                ])
              ],
            )
          ],
        ),
      ),
    );
  }
}