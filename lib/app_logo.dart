//AppLogo
import 'package:flutter/material.dart';
import 'darth.math' as math;
import 'logo_manager.dart';

class AppLogo extends StatelessWidget {
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  const AppLogo({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.borderRadius,
  });
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?> (
      future: LogoStorageService().getLogo(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: borderRadius ?? BorderRadius.circular(8.0),
            ),
            child: const Center(
              child: SizedBox(width: 20, height: 20, 
              child: CircularProgressIndicator(strokeWidth: 2,)),
            ),
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          Widget image = Image.memory(
            snapshot.data!['image_bytes'],
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: borderRadius ?? BorderRadius.circular(8.0),
                ),
                child:  Center(
                  child: Icon(
                    Icons.error,
                    size: (width != null && height != null)
                        ? math.min(width!, height!) * 0.5
                        : 32.0,
                    color: Colors.red,
                  ),
                ),
              );
            },
            );
          if (borderRadius != null) {
            return ClipRRect(
              borderRadius: borderRadius!,
              child: image,
            );
          }
          return image;

        } else {
          // Logo por defecto
          return Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: borderRadius ?? BorderRadius.circular(8.0),
              color: Colors.red.shade100,
            ),
            child: Icon(
              Icons.business,
              size: (width != null && height != null)
                  ? math.min(width!, height!) * 0.5
                  : 32.0,
              color: Colors.grey.shade400,
            ),
          );
        }
      },
    );
  }
}