import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'app_scaffold.dart';
import 'settings_controller.dart';

class AgendaPage extends StatelessWidget {
  AgendaPage({super.key});

  final SettingsController settingsController = Get.put(SettingsController());

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Agenda',
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Center(child: Text('Aquí va la agenda')),
          ],
        ),
      ),
    );
  }
}