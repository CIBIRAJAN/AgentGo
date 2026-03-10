import 'package:flutter/material.dart';
import '../../config/theme/app_colors.dart';
import '../dashboard/dashboard_screen.dart';
import '../clients/clients_list_screen.dart';
import '../dues/dues_list_screen.dart';
import '../pdf/pdf_upload_screen.dart';
import '../analytics/analytics_screen.dart';
import '../profile/profile_screen.dart';
import '../diary/diary_screen.dart';
import '../celebrations/celebrations_screen.dart';
import '../commission/commission_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import '../notifications/notification_screen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/agent_provider.dart';

/// Home screen with bottom navigation bar.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  static _HomeScreenState? of(BuildContext context) =>
      context.findAncestorStateOfType<_HomeScreenState>();

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;
  String? _initialDueStatus;

  @override
  void initState() {
    super.initState();
    // Proactively refresh agent data on home mount to ensure 
    // the switcher shows up immediately after login.
    Future.microtask(() => ref.read(agentProvider.notifier).refresh());
  }

  void setTab(int index, {String? dueStatus}) {
    setState(() {
      _currentIndex = index;
      _initialDueStatus = dueStatus;
    });
  }

  void _openPdfUpload() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PdfUploadScreen()),
    );
  }

  void _openAnalytics() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
    );
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  List<String> get _tabTitles => ['', 'clients'.tr(), 'dues'.tr()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Show AppBar only for Clients and Dues tabs (Dashboard has its own header)
      appBar: _currentIndex > 0
          ? AppBar(
              title: Text(_tabTitles[_currentIndex]),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_rounded),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationScreen()));
                  },
                ),
                const SizedBox(width: 8),
              ],
            )
          : null,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const DashboardScreen(),
          const ClientsListScreen(),
          DuesListScreen(initialStatus: _initialDueStatus),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openPdfUpload,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.upload_file_rounded, size: 26),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: AppColors.surface,
        elevation: 8,
        height: 56,
        padding: EdgeInsets.zero,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.dashboard_rounded,
              label: 'home'.tr(),
              isSelected: _currentIndex == 0,
              onTap: () => setState(() => _currentIndex = 0),
            ),
            _NavItem(
              icon: Icons.people_rounded,
              label: 'clients'.tr(),
              isSelected: _currentIndex == 1,
              onTap: () => setState(() => _currentIndex = 1),
            ),
            const SizedBox(width: 48), // Space for FAB
            _NavItem(
              icon: Icons.receipt_long_rounded,
              label: 'dues'.tr(),
              isSelected: _currentIndex == 2,
              onTap: () => setState(() => _currentIndex = 2),
            ),
            _NavItem(
              icon: Icons.grid_view_rounded,
              label: 'menu'.tr(),
              isSelected: false,
              onTap: () => _showMoreMenu(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.book_rounded, color: AppColors.success),
              title: Text('agent_diary'.tr()),
              subtitle: Text('manage_appointments'.tr()),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DiaryScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.analytics_rounded,
                  color: AppColors.primary),
              title: Text('analytics'.tr()),
              subtitle: Text('commission_insights'.tr()),
              onTap: () {
                Navigator.pop(ctx);
                _openAnalytics();
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_rounded,
                  color: AppColors.error),
              title: Text('pdf_uploads'.tr()),
              subtitle: Text('view_upload_pdfs'.tr()),
              onTap: () {
                Navigator.pop(ctx);
                _openPdfUpload();
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_rounded,
                  color: AppColors.secondary),
              title: Text('profile'.tr()),
              subtitle: Text('manage_account'.tr()),
              onTap: () {
                Navigator.pop(ctx);
                _openProfile();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(3),
              decoration: isSelected
                  ? BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(8),
                    )
                  : null,
              child: Icon(
                icon,
                color: isSelected ? AppColors.primary : AppColors.textTertiary,
                size: 22,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppColors.primary : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
