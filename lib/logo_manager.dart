import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      return null;
    } catch (e) {
      debugPrint('Error retrieving logo: $e');
      return null;
    }
  }

  // Eliminar logo
  static Future<void> deleteLogo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_logoKey);
      await prefs.remove(_logoNameKey);
      await prefs.remove(_logoSizeKey);
    } catch (e) {
      debugPrint('Error deleting logo: $e');
    }
  }

  // Verificar si existe un logo
  static Future<bool> hasLogo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_logoKey);
    } catch (e) {
      debugPrint('Error checking logo existence: $e');
      return false;
    }
  }

  // Obtener información del almacenamiento
  static Future<Map<String, dynamic>> getStorageInfo() async {
    final hasLogo = await LogoStorageService.hasLogo();
    return {
      'total_keys': hasLogo ? 1: 0,
      'has_logo': hasLogo,
      'keys': hasLogo ? [_logoKey] : [],
    };
  }
}

class LogoManager extends StatefulWidget {
  const LogoManager({super.key});

  @override
  State<LogoManager> createState() => _LogoManagerState();
}

class _LogoManagerState extends State<LogoManager> {
 Map<String, dynamic>? _currentLogo;
 bool _isLoading = false;
  @override
  void initState() {
    super.initState();
    _loadLogo();
  }

  // Cargar logo desde el servicio de almacenamiento
  Future<void> _loadLogo() async {
    try {
       final logo = await LogoStorageService.getLogo();
       setState(() {
         _currentLogo = logo;
       });
    } catch (e) {
      debugPrint('Error loading logo: $e');
      _showErrorSnackBar('Error loading logo: $e');
    }
  }


  // Nuevo método para procesar y guardar logo desde una URL
  Future<void> _processAndSaveLogoFromUrl(String url) async {
    try {
      setState(() {
        _isLoading = true;
      });
      // Obtener los bytes de la imagen desde la URL
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final imageData = response.bodyBytes;
        // Procesar y guardar el logo
        await _processAndSaveLogo(imageData);
      } else {
        throw Exception('Failed to load image from URL');
      }
    } catch (e) {
      _showErrorSnackBar('Error processing logo from URL: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Procesar y guardar logo (ahora toma los bytes directamente)
  Future<void> _processAndSaveLogo(Uint8List imageData) async {
    try {
      // Redimensionar imagen
      final resizedImage = await ImageUtils.resizeImage(imageData);
      // Guardar logo
      final String logoName = 'logo_${DateTime.now().millisecondsSinceEpoch}.png';
      await LogoStorageService.saveLogo(logoName, resizedImage);
      // Recargar logo
      await _loadLogo();
      _showSuccessSnackBar('Logo processed and saved successfully');
    } catch (e) {
      _showErrorSnackBar('Error processing logo: $e');
    }
  }

  // Eliminar logo actual
  Future<void> _removeLogo() async {
    try {
      await LogoStorageService.deleteLogo();
      setState(() {
        _currentLogo = null;
      });
      await _loadLogo();
      _showSuccessSnackBar('Logo deleted successfully');
    } catch (e) {
      _showErrorSnackBar('Error deleting logo: $e');
    }
  }

  // Confirmar eliminación
  void _confirmDeleteLogo() {
    showDialog(context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('Eliminar Logo'),
        content: const Text('¿Estás seguro/a de que quieres eliminar el logo actual?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _removeLogo();
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Eliminar'),
        ),
      ],
      );
    },
    );
  }

  // Mostrar opciones de selección
  void _showImageSourceOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bottomSheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('Desde URL'),
                onTap: () {
                  Navigator.of(bottomSheetContext).pop();
                  _showUrlDialog();
                },
              ),
              if (_currentLogo != null) 
              ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Eliminar Logo', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.of(bottomSheetContext).pop();
                    _confirmDeleteLogo();
                },
              ),
            ],
           ),
        );
      },
    );
  }
  
  // Nuevo método para mostrar el diálogo de URL
  void _showUrlDialog() {
    final urlController = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
       return AlertDialog(
        title: const Text('Pegar URL de la imagen'),
        content: TextField(
          controller: urlController,
          decoration: const InputDecoration(
            hintText: 'Ejemplo: https://ejemplo.com/logo.png',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              if (urlController.text.isNotEmpty) {
                Navigator.of(dialogContext).pop();
                _processAndSaveLogoFromUrl(urlController.text);
              }
            },
            child: const Text('Guardar'),
          ),
        ]
       );
      }
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return  AppScaffold(
      title: 'Logo Manager',
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column( 
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [ 
            const SizedBox(height: 32), // Espacio superior
            //Contenedor del logo
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300, width: 2),
                borderRadius: BorderRadius.circular(16),
                color: Colors.grey.shade50,
              ),
              child: _isLoading
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Procesando imagen...', style: TextStyle(fontSize: 16)),
                  ],
                ),
                )
              : _currentLogo != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.memory(
                      _currentLogo!['image_bytes'],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  )
                  : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.image_outlined,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                    
                    const SizedBox(height:16),
                    const Text('Sin logo',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    const Text('Añade un logo para personalizar la app',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed:  _isLoading ? null : _showImageSourceOptions,
                        icon: Icon(_currentLogo != null ? Icons.edit : Icons.add_a_photo),
                        label: Text(_currentLogo != null ? 'Cambiar Logo' : 'Añadir Logo'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical:16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
            // Botón de eliminar (solo si hay logo)
            if (_currentLogo != null && !_isLoading)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _confirmDeleteLogo,
                  icon: const Icon(Icons.delete, color: Colors.red),
                  label: const Text('Eliminar logo', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            
            const SizedBox(height: 24),
            
            // Información del logo actual
            if (_currentLogo != null)
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade600),
                          const SizedBox(width: 8),
                          const Text(
                            'Información del logo:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow('Nombre:', _currentLogo!['name']),
                      _buildInfoRow('Pixeles:', '${_currentLogo!['width']} x ${_currentLogo!['height']}'),
                      _buildInfoRow('Tamaño:', '${(_currentLogo!['size_bytes'] / 1024).toStringAsFixed(1)} KB'),
                      _buildInfoRow('Creado:', _formatDate(_currentLogo!['created_at'])),
                      _buildInfoRow('Almacenado en:', 'SharedPreferences'),
                    ],
                  ),
                ),
              ),
                          const Spacer(),
            
            // Información adicional
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue.shade600, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Las imágenes se redimensionan automáticamente a máximo 512x512 píxeles',
                          style: TextStyle(
                            color: Colors.blue.shade800,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Usando SharedPreferences para almacenamiento local',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),                    
                    ],
                    
                  ),
                  
            ),

          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
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