import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:lendify/screens/explore_screen.dart';
import 'package:lendify/screens/wishlists_screen.dart';
import 'package:lendify/screens/bookings_screen.dart';
import 'package:lendify/screens/messages_screen.dart';
import 'package:lendify/screens/profile_screen.dart';
import 'package:lendify/theme.dart';
import 'package:provider/provider.dart';
import 'package:lendify/services/data_service.dart';
import 'package:lendify/models/user.dart' as model;
import 'package:lendify/services/localization_service.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  model.User? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final u = await DataService.getCurrentUser();
      if (mounted) setState(() => _currentUser = u);
    } catch (_) {}
  }

  final List<Widget> _screens = [
    const ExploreScreen(),
    const WishlistsScreen(),
    const BookingsScreen(),
    const MessagesScreen(),
    const ProfileScreen(),
  ];

  Widget _navIcon(IconData icon, int index) => _HoveringNavIcon(icon: icon, active: _currentIndex == index);

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocalizationController>();
    return WillPopScope(
      onWillPop: () async {
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
          return false;
        }
        return true;
      },
      child: Scaffold(
        body: _screens[_currentIndex],
        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() => _currentIndex = index);
          },
          selectedItemColor: BrandColors.primary,
          unselectedItemColor: BrandColors.inactiveNav,
          selectedIconTheme: const IconThemeData(size: 20),
          unselectedIconTheme: const IconThemeData(size: 20),
          selectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
          items: [
            BottomNavigationBarItem(
              icon: _navIcon(Icons.search, 0),
              activeIcon: _HoveringNavIcon(icon: Icons.search, active: true),
              label: l10n.t('Erkunden'),
            ),
            BottomNavigationBarItem(
              icon: _navIcon(Icons.favorite_border, 1),
              activeIcon: _HoveringNavIcon(icon: Icons.favorite_border, active: true),
              label: l10n.t('Wunschlisten'),
            ),
            BottomNavigationBarItem(
              icon: _HoveringAssetNavIcon(asset: 'assets/images/icononly_transparent_nobuffer.png', active: _currentIndex == 2, baseSize: 32.0),
              activeIcon: _HoveringAssetNavIcon(asset: 'assets/images/icononly_transparent_nobuffer.png', active: true, baseSize: 32.0),
              label: l10n.t('Buchungen'),
            ),
            BottomNavigationBarItem(
              icon: _navIcon(Icons.chat_bubble_outline, 3),
              activeIcon: _HoveringNavIcon(icon: Icons.chat_bubble_outline, active: true),
              label: l10n.t('Nachrichten'),
            ),
            BottomNavigationBarItem(
              icon: Stack(clipBehavior: Clip.none, children: [
                _ProfileNavIcon(photoUrl: _currentUser?.photoURL, active: _currentIndex == 4),
                const Positioned(right: -2, top: -2, child: DecoratedBox(decoration: BoxDecoration(color: BrandColors.logoAccent, shape: BoxShape.circle), child: SizedBox(width: 8, height: 8))),
              ]),
              activeIcon: Stack(clipBehavior: Clip.none, children: [
                _ProfileNavIcon(photoUrl: _currentUser?.photoURL, active: true),
                const Positioned(right: -2, top: -2, child: DecoratedBox(decoration: BoxDecoration(color: BrandColors.logoAccent, shape: BoxShape.circle), child: SizedBox(width: 8, height: 8))),
              ]),
              label: l10n.t('Profil'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HoveringNavIcon extends StatefulWidget {
  final IconData icon; final bool active;
  const _HoveringNavIcon({required this.icon, required this.active});
  @override
  State<_HoveringNavIcon> createState() => _HoveringNavIconState();
}

class _HoveringNavIconState extends State<_HoveringNavIcon> {
  bool _hovering = false;
  @override
  Widget build(BuildContext context) {
    final color = widget.active || _hovering ? BrandColors.primary : BrandColors.inactiveNav;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedScale(scale: _hovering ? 1.33 : 1.0, duration: const Duration(milliseconds: 180), curve: Curves.easeOut, child: Icon(widget.icon, size: 20, color: color)),
    );
  }
}

class _HoveringAssetNavIcon extends StatefulWidget {
  final String asset;
  final bool active;
  final double baseSize;
  const _HoveringAssetNavIcon({required this.asset, required this.active, this.baseSize = 22});
  @override
  State<_HoveringAssetNavIcon> createState() => _HoveringAssetNavIconState();
}

class _HoveringAssetNavIconState extends State<_HoveringAssetNavIcon> with SingleTickerProviderStateMixin {
  bool _hovering = false;
  late final AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    // 3x faster per rotation than the main logo (700ms per 1 rotation)
    // Main logo: 1 rotation in 700ms; this does 3 rotations in 700ms total => 233ms per rotation.
    _spinController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  }

  @override
  void didUpdateWidget(covariant _HoveringAssetNavIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    // No automatic spinning on active state; spin only on hover enter.
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.active || _hovering ? BrandColors.primary : BrandColors.inactiveNav;
    return MouseRegion(
      onEnter: (_) {
        setState(() => _hovering = true);
        _spinController.forward(from: 0); // Single 360° rotation on hover enter
      },
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedScale(
        scale: _hovering ? 1.33 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: AnimatedBuilder(
          animation: _spinController,
          builder: (context, child) => Transform.rotate(
            angle: _spinController.value * 2 * math.pi * 3,
            child: child,
          ),
          child: ImageIcon(AssetImage(widget.asset), size: widget.baseSize, color: color),
        ),
      ),
    );
  }
}

class _ProfileNavIcon extends StatelessWidget {
  final String? photoUrl;
  final bool active;
  const _ProfileNavIcon({required this.photoUrl, required this.active});

  @override
  Widget build(BuildContext context) {
    final Color border = active ? BrandColors.primary : BrandColors.inactiveNav;
    final double size = 20;
    final double radius = size / 2;
    return MouseRegion(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: border, width: 1.6),
        ),
        child: ClipOval(
          child: photoUrl != null && photoUrl!.isNotEmpty
              ? Image.network(photoUrl!, fit: BoxFit.cover)
              : Center(child: Icon(Icons.person_outline, size: 14, color: border)),
        ),
      ),
    );
  }
}
