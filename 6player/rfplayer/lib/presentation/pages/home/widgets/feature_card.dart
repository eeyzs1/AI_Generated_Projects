import 'package:flutter/material.dart';
import 'package:fast_file_picker/fast_file_picker.dart';
import 'package:file_selector/file_selector.dart';
import '../../../router/app_router.dart';

class FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String route;
  final List<String> allowedExtensions;

  const FeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.route,
    required this.allowedExtensions,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () async {
          final typeGroup = XTypeGroup(
            label: 'Allowed Files',
            extensions: allowedExtensions,
          );
          final result = await FastFilePicker.pickFile(
            acceptedTypeGroups: [typeGroup],
          );

          if (result != null) {
            String? pathToUse;
            if (result.path != null) {
              pathToUse = result.path;
            } else if (result.uri != null) {
              pathToUse = result.uri.toString();
            }
            
            if (pathToUse != null) {
              appRouter.push(route, extra: {
                'path': pathToUse,
                'name': result.name,
              });
            }
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
