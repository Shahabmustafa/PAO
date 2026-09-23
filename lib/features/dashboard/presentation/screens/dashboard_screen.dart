import 'package:flutter/material.dart';
import 'package:flutter_floating_bottom_bar/flutter_floating_bottom_bar.dart';
import '../../../../core/notifications/notification_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../add_item/presentation/screens/add_item_screen.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../../requests/data/model/request_model.dart';
import '../../../requests/data/request_store.dart';
import '../../../requests/presentation/screens/requests_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../wishlist/presentation/screens/wishlist_screen.dart';
import '../../../../core/l10n/l10n.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  final _barController = BottomBarController();

  final List<Widget> _screens = const [
    HomeScreen(),
    WishlistScreen(),
    AddItemScreen(),
    RequestsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // A tapped push notification (see NotificationRouter) may request a tab
    // switch, either right as this screen is (re)pushed onto the stack...
    final requested = NotificationRouter.requestedTab.value;
    if (requested != null) {
      NotificationRouter.requestedTab.value = null;
      _currentIndex = requested;
    }
    // ...or while it's already mounted.
    NotificationRouter.requestedTab.addListener(_onTabRequested);
  }

  @override
  void dispose() {
    NotificationRouter.requestedTab.removeListener(_onTabRequested);
    _barController.dispose();
    super.dispose();
  }

  void _onTabRequested() {
    final requested = NotificationRouter.requestedTab.value;
    if (requested == null) return;
    NotificationRouter.requestedTab.value = null;
    setState(() => _currentIndex = requested);
    _barController.show();
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
    _barController.show();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BottomBar(
        controller: _barController,
        // Home, Add Product, Requests and Settings hide the bar on scroll
        // (down hides, up shows); Wishlist keeps it pinned and
        // _onTabTapped/_onTabRequested force it back into view when
        // navigating away.
        scrollBehavior: BottomBarScrollBehavior(
          hideOnScroll: _currentIndex != 1,
        ),
        showIcon: false,
        // Zero offset and a transparent bar decoration: _FloatingNavBarContent
        // draws its own margin and pill background already, exactly like the
        // original hand-built nav bar. Leaving these unset falls back to the
        // package's own outer margin and tinted surface color, which then
        // shows through around/behind our pill as an extra colored halo.
        layout: const BottomBarLayout.adaptive(
          maxWidth: 420,
          offset: 0,
          clip: Clip.none,
        ),
        theme: const BottomBarThemeData(barDecoration: BoxDecoration()),
        // Reserves the floating bar's real, measured height at the bottom
        // of every tab, so its content (e.g. Add Product's Post button)
        // never ends up hidden underneath it.
        body: IndexedStack(index: _currentIndex, children: _screens),
        child: _FloatingNavBarContent(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
        ),
      ),
    );
  }
}

class _FloatingNavBarContent extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _FloatingNavBarContent({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(34),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Row(
              children: [
                Expanded(
                  child: _NavItem(
                    icon: AppIcons.homeOutline,
                    activeIcon: AppIcons.homeFilled,
                    label: context.l10n.navHome,
                    isActive: currentIndex == 0,
                    onTap: () => onTap(0),
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: AppIcons.favoriteOutline,
                    activeIcon: AppIcons.favoriteFilled,
                    label: context.l10n.navWishlist,
                    isActive: currentIndex == 1,
                    onTap: () => onTap(1),
                  ),
                ),
                const SizedBox(width: 64),
                Expanded(
                  // Received requests still waiting for the user's answer.
                  child: ValueListenableBuilder<List<RequestModel>>(
                    valueListenable: RequestStore.received,
                    builder: (context, received, _) => _NavItem(
                      icon: AppIcons.inbox,
                      label: context.l10n.navRequests,
                      isActive: currentIndex == 3,
                      badgeCount: received.where((r) => r.isPending).length,
                      onTap: () => onTap(3),
                    ),
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: AppIcons.settingsOutline,
                    activeIcon: AppIcons.settingsFilled,
                    label: context.l10n.navSettings,
                    isActive: currentIndex == 4,
                    onTap: () => onTap(4),
                  ),
                ),
              ],
            ),
            Positioned(top: -14, child: _CreateButton(onTap: () => onTap(2))),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String icon;
  final String? activeIcon;
  final String label;
  final bool isActive;
  final int badgeCount;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.primary : context.appTextSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AppIcon(
                  isActive && activeIcon != null ? activeIcon! : icon,
                  size: 22,
                  color: color,
                ),
                if (badgeCount > 0)
                  PositionedDirectional(
                    top: -6,
                    end: -10,
                    child: _CountBadge(count: badgeCount),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;

  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          fontSize: 10,
          height: 1.2,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _CreateButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CreateButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        height: 56,
        width: 56,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Center(
          child: AppIcon(AppIcons.add, size: 24, color: AppColors.onPrimary),
        ),
      ),
    );
  }
}
