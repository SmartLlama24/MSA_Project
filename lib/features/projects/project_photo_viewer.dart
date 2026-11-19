import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../data/models.dart';

class ProjectPhotoViewer extends StatelessWidget {
  const ProjectPhotoViewer({super.key, required this.photo});

  final ProjectPhoto photo;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      title: Text(photo.createdAt.toLocal().toString().split('.').first),
    ),
    body: Center(
      child: InteractiveViewer(
        minScale: 0.8,
        maxScale: 5,
        child: Image.network(
          photo.signedUrl ?? '',
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                color: context.appPalette.accent,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            debugPrint(
              '[ProjectPhoto] Full-screen image load failed: '
              'photo=${photo.id}, error=$error\n$stackTrace',
            );
            return Icon(
              Icons.broken_image_outlined,
              color: context.appPalette.mutedText,
              size: 56,
            );
          },
        ),
      ),
    ),
  );
}
