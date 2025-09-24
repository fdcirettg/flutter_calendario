import 'package:flutter/material.dart';
import 'package:flutter_calendario/theme_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'settings_controller.dart';
import 'app_scaffold.dart';
import 'agenda_page.dart';
import 'configuracion_page.dart';
import 'theme_provider.dart';
import 'app_text.dart';
import 'package:shared_preferences/shared_preferences.dart';


void main() {  
  Get.put(SettingsController());
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final GoRouter router = GoRouter(routes:  [
      GoRoute(path: '/', builder: (context, state) => const MyHomePage(title:'Inicio')),
      GoRoute(path: '/agenda', builder: (context, state) => AgendaPage()),
      GoRoute(path: '/configuracion', builder: (context, state) => ConfiguracionPage()),
    ]);
    return MaterialApp.router( title: 'Agenda Veterinaria',
      routerConfig: router,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: themeProvider.themeMode, 
      );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String nombreVeterinaria = '';
  @override
  void initState() {
    super.initState();
    _loadCustomText();
  }
  Future<void> _loadCustomText() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      nombreVeterinaria = prefs.getString('custom_text') ?? 'Mi Veterinaria';
    });
  }
  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: widget.title,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Center(
            child: Text(
              nombreVeterinaria,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ],
      ),
    );
  }
}