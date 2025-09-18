import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'settings_controller.dart';
import 'app_scaffold.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';

class ConfiguracionPage extends StatelessWidget {
  ConfiguracionPage({super.key});

  final SettingsController settingsController = Get.put(SettingsController());

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return AppScaffold(
      title: 'Configuración',
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: RadioGroup<ThemeMode>(
          groupValue: themeProvider.themeMode,
          onChanged: (mode) => themeProvider.setTheme(mode!),
          child: Column(
            children: <Widget>[
            RadioListTile<ThemeMode>(
              value: ThemeMode.light,
              title: Text('Claro'),
            ),
            RadioListTile<ThemeMode>(
              value: ThemeMode.dark,
              title: Text('Oscuro'),
            ),
            RadioListTile<ThemeMode>(
              value: ThemeMode.system,
              title: Text('Seguir sistema'),
            ),
          ],
        ),
      ),
    ),
    );
  }
}