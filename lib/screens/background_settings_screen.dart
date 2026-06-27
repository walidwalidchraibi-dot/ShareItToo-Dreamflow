import 'package:flutter/material.dart';
import 'package:lendify/services/background_theme_service.dart';
import 'package:provider/provider.dart';

class BackgroundSettingsScreen extends StatelessWidget {
  const BackgroundSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<BackgroundThemeController>();
    final selected = controller.selectedChoice;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Hintergrund'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Wähle einen Hintergrund für den eingeloggten Bereich von ShareItToo.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.86),
                    ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: AppBackgroundChoice.values.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.84,
                  ),
                  itemBuilder: (context, index) {
                    final choice = AppBackgroundChoice.values[index];
                    return _BackgroundPreviewCard(
                      choice: choice,
                      selected: selected == choice,
                      onTap: () => controller.setChoice(choice),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackgroundPreviewCard extends StatelessWidget {
  final AppBackgroundChoice choice;
  final bool selected;
  final VoidCallback onTap;

  const _BackgroundPreviewCard({
    required this.choice,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? const Color(0xFF38BDF8)
        : Colors.white.withValues(alpha: 0.16);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: borderColor,
              width: selected ? 2.6 : 1.0,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.22),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(23),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(choice.assetPath, fit: BoxFit.cover),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.08),
                        Colors.black.withValues(
                          alpha: choice.overlayOpacity * 0.52,
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: selected ? 1.0 : 0.0,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        color: Color(0xFF38BDF8),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 14,
                  child: Text(
                    choice.uiLabel,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
