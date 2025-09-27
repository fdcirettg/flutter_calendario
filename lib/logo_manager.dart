import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'app_scaffold.dart';
import 'package:http/http.dart' as http; // Importa el paquete http

// Servicio de almacenamiento con SharedPreferences
class LogoStorageService {
  static const String _logoKey = 'app_logo_data';
  static const String _logoNameKey = 'app_logo_name';
  static const String _logoSizeKey = 'app_logo_size';

  // Guardar logo (reemplaza el existente)
  static Future<void> saveLogo(String name, Uint8List imageData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Convertimos los bytes a Base64 para almacenamiento
      String base64Image = base64Encode(imageData);
      // Guardar los datos del logo en SharedPreferences
      await prefs.setString(_logoKey, base64Image);
      await prefs.setString(_logoNameKey, name);
      await prefs.setInt(_logoSizeKey, imageData.length);

    } catch (e) {
      throw Exception('Error saving logo: $e');
    }
  }

  // Obtener el logo
  static Future<Map<String, dynamic>?> getLogo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? base64Image  = prefs.getString(_logoKey);
      if (base64Image != null) {
        // Convertimos de Base64 a bytes
        Uint8List imageData = base64Decode(base64Image);
        String? name = prefs.getString(_logoNameKey);
        int? size = prefs.getInt(_logoSizeKey);
        // Obtener dimensiones de la imagen
        final width = await decodeImageFromList(imageData).then((img) => img.width);
        final height = await decodeImageFromList(imageData).then((img) => img.height);
        return {
          'name': name ?? 'Logo',
          'width': width,
          'height': height,
          'image_bytes': imageData,
          'size': size ?? 0,
          'created_at': DateTime.now().toIso8601String(),
        };
      }
    } catch (e) {
      throw Exception('Error retrieving logo: $e');
    }
  }

  // Eliminar logo
  static Future<void> deleteLogo() async {
  }

  // Verificar si existe un logo
  static Future<bool> hasLogo() async {
  }

  // Obtener información del almacenamiento
  static Future<Map<String, dynamic>> getStorageInfo() async {
  }
}

class LogoManager extends StatefulWidget {
  const LogoManager({super.key});

  @override
  State<LogoManager> createState() => _LogoManagerState();
}

class _LogoManagerState extends State<LogoManager> {

  @override
  void initState() {
  }

  // Cargar logo desde el servicio de almacenamiento
  Future<void> _loadLogo() async {
  }

  // Seleccionar y procesar imagen
  Future<void> _pickImage(ImageSource source) async {
  }

  // Nuevo método para procesar y guardar logo desde una URL
  Future<void> _processAndSaveLogoFromUrl(String url) async {
  }

  // Procesar y guardar logo (ahora toma los bytes directamente)
  Future<void> _processAndSaveLogo(Uint8List imageData) async {
  }

  // Eliminar logo actual
  Future<void> _removeLogo() async {
  }

  // Confirmar eliminación
  void _confirmDeleteLogo() {
  }

  // Mostrar información de depuración
  Future<void> _showDebugInfo() async {
  }

  // Mostrar opciones de selección
  void _showImageSourceOptions() {
  }
  
  // Nuevo método para mostrar el diálogo de URL
  void _showUrlDialog() {
  }

  void _showSuccessSnackBar(String message) {
  }

  void _showErrorSnackBar(String message) {
  }

  @override
  Widget build(BuildContext context) {
    return  AppScaffold(
      title: 'Logo Manager',
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column( 
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [ Text('Logo Manager'),]
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {

  }

  String _formatDate(String dateString) {
    final date = DateTime.parse(dateString).toLocal();
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// Utilidad para redimensionar imágenes (sin cambios, ya que es genérica)
class ImageUtils {
  static Future<Uint8List> resizeImage(Uint8List imageBytes, {int maxSize = 512}) async {
    final ui.Image image = await _decodeImageFromBytes(imageBytes);
    
    // Calcular nuevas dimensiones manteniendo proporción
    final int originalWidth = image.width;
    final int originalHeight = image.height;
    
    double ratio = math.min(maxSize / originalWidth, maxSize / originalHeight);
    int newWidth = (originalWidth * ratio).round();
    int newHeight = (originalHeight * ratio).round();
    
    // Crear canvas para redimensionar
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final Rect srcRect = Rect.fromLTWH(0, 0, originalWidth.toDouble(), originalHeight.toDouble());
    final Rect dstRect = Rect.fromLTWH(0, 0, newWidth.toDouble(), newHeight.toDouble());
    
    canvas.drawImageRect(image, srcRect, dstRect, Paint());
    
    final ui.Picture picture = recorder.endRecording();
    final ui.Image resizedImage = await picture.toImage(newWidth, newHeight);
    
    final ByteData? byteData = await resizedImage.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
  
  static Future<ui.Image> _decodeImageFromBytes(Uint8List bytes) async {
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frame = await codec.getNextFrame();
    return frame.image;
  }
}