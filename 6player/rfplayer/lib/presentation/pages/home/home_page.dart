import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../home/widgets/feature_card.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/constants/supported_formats.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.appName),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.0,
              ),
              delegate: SliverChildListDelegate([
                FeatureCard(
                  icon: Icons.video_library,
                  title: loc.playVideo,
                  description: loc.playVideoDesc,
                  route: '/video-player',
                  allowedExtensions: videoFormats.toList(),
                ),
                FeatureCard(
                  icon: Icons.photo_library,
                  title: loc.viewImage,
                  description: loc.viewImageDesc,
                  route: '/image-viewer',
                  allowedExtensions: imageFormats.toList(),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}