import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/theme/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import 'package:easy_localization/easy_localization.dart';
import '../auth/reset_password_screen.dart';
import '../agent_connection/agent_linking_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/agent_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io' show Platform;

/// Profile screen for viewing/editing the agent's profile and signing out.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final AuthService _authService;
  UserModel? _user;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _authService = AuthService(Supabase.instance.client);
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = await _authService.getUserProfile();
      if (mounted) {
        setState(() {
          _user = user;
          _nameCtrl.text = user?.name ?? '';
          _phoneCtrl.text = user?.phoneNumber ?? '';
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await _authService.updateProfile(
        name: _nameCtrl.text.trim(),
        phoneNumber: _phoneCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('profile_updated'.tr()),
              backgroundColor: AppColors.success),
        );
        setState(() => _isEditing = false);
        _loadProfile();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.error),
        );
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('sign_out'.tr()),
        content: Text('confirm_sign_out'.tr()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('cancel'.tr())),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text('sign_out'.tr()),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      // Clear Agent state before signing out
      ref.invalidate(agentProvider);
      
      await _authService.signOut();
      if (mounted) {
        // Clear entire nav stack and go back to root (AuthGate will show LoginScreen)
        Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('profile'.tr()),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              onPressed: () => setState(() => _isEditing = true),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Avatar
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      gradient: AppColors.heroGradient,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _user?.name?.isNotEmpty == true
                            ? _user!.name![0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (!_isEditing) ...[
                    Text(
                      _user?.name ?? 'No name set',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _user?.email ?? '',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (_user?.phoneNumber != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _user!.phoneNumber!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ],

                  if (_isEditing) ...[
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Phone Number'),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Save'),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _isEditing = false),
                      child: const Text('Cancel'),
                    ),
                  ],

                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Menu items
                  _MenuItem(
                    icon: Icons.language_rounded,
                    label: 'language'.tr(),
                    subtitle: 'switch_language'.tr(),
                    trailing: Text(
                      context.locale.languageCode == 'ta' ? 'தமிழ்' : 'English',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                    onTap: () {
                      if (context.locale.languageCode == 'en') {
                        context.setLocale(const Locale('ta'));
                      } else {
                        context.setLocale(const Locale('en'));
                      }
                    },
                  ),
                  _MenuItem(
                    icon: Icons.notifications_rounded,
                    label: 'Notifications',
                    subtitle: _user?.notification == true ? 'Enabled' : 'Disabled',
                    onTap: () async {
                      await _authService.updateProfile(
                          notification: !(_user?.notification ?? false));
                      _loadProfile();
                    },
                  ),
                   _MenuItem(
                    icon: Icons.security_rounded,
                    label: 'privacy_security'.tr(),
                    subtitle: 'privacy_subtitle'.tr(),
                    onTap: () {},
                  ),
                  _MenuItem(
                    icon: Icons.link_rounded,
                    label: 'account_linking'.tr(),
                    subtitle: 'account_linking_subtitle'.tr(),
                    color: AppColors.secondary,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AgentLinkingScreen()),
                      ).then((_) => ref.read(agentProvider.notifier).refresh());
                    },
                  ),
                  _MenuItem(
                    icon: Icons.lock_reset_rounded,
                    label: 'reset_password'.tr(),
                    subtitle: 'reset_password_subtitle'.tr(),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ResetPasswordScreen(
                            initialEmail: _user?.email,
                          ),
                        ),
                      );
                    },
                  ),
                  _MenuItem(
                    icon: Icons.help_outline_rounded,
                    label: 'help_support'.tr(),
                    onTap: () {},
                  ),
                  const SizedBox(height: 12),
                  _MenuItem(
                    icon: Icons.share_rounded,
                    label: 'invite_friends'.tr(),
                    subtitle: 'invite_friends_subtitle'.tr(),
                    color: const Color(0xFF25D366),
                    onTap: () {
                      Share.share(
                        'Hey! I\'ve been using AgentGo to manage my LIC clients and dues efficiently. It\'s a game changer! Check it out: https://agentgo.app',
                        subject: 'Check out AgentGo!',
                      );
                    },
                  ),
                  _MenuItem(
                    icon: Icons.logout_rounded,
                    label: 'sign_out'.tr(),
                    color: AppColors.error,
                    onTap: _signOut,
                  ),

                  const SizedBox(height: 24),
                  Text(
                    'AgentGo v1.0.0',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color? color;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _MenuItem({
    required this.icon,
    required this.label,
    this.subtitle,
    this.color,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: (color ?? AppColors.primary).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color ?? AppColors.primary, size: 20),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: color ?? AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style: Theme.of(context).textTheme.bodySmall)
          : null,
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded,
          color: AppColors.textTertiary),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}
