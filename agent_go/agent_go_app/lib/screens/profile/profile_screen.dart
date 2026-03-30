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
import '../../providers/user_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../subscription/subscription_screen.dart';
import 'package:file_picker/file_picker.dart';

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
  String? _profileUrl;
  bool _isUploadingImage = false;

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
          _profileUrl = user?.profile;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result == null || result.files.single.path == null) return;

      setState(() => _isUploadingImage = true);

      final file = File(result.files.single.path!);
      final userId = _authService.currentUserId;
      if (userId == null) return;

      final extension = result.files.single.extension ?? 'jpg';
      final fileName = 'avatar_$userId.$extension';

      // 1. Upload to Supabase Storage
      await Supabase.instance.client.storage
          .from('profiles')
          .upload(fileName, file, fileOptions: const FileOptions(upsert: true));

      // 2. Get Public URL
      final publicUrl = Supabase.instance.client.storage
          .from('profiles')
          .getPublicUrl(fileName);

      // 3. Update Profile table
      await _authService.updateProfile(profile: publicUrl);

      // 4. Invalidate provider and refresh local state
      ref.invalidate(userProvider);
      
      setState(() {
        _profileUrl = publicUrl;
      });
      _loadProfile();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated!'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading photo: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await _authService.updateProfile(
        name: _nameCtrl.text.trim(),
        phoneNumber: _phoneCtrl.text.trim(),
        profile: _profileUrl,
      );
      
      // Invalidate provider to sync across app
      ref.invalidate(userProvider);

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
      backgroundColor: AppColors.background,
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
          : _user == null 
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.textTertiary, size: 48),
                      const SizedBox(height: 16),
                      const Text('Could not load profile'),
                      TextButton(onPressed: _loadProfile, child: const Text('Retry')),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Column(
                    children: [
                      // Avatar
                      Center(
                        child: Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                gradient: AppColors.heroGradient,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: _isUploadingImage
                                    ? const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : _profileUrl != null && _profileUrl!.isNotEmpty
                                        ? Image.network(
                                            _profileUrl!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Center(
                                              child: Text(
                                                _user?.name?.isNotEmpty == true ? _user!.name![0].toUpperCase() : '?',
                                                style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          )
                                        : Center(
                                            child: Text(
                                              _user?.name?.isNotEmpty == true ? _user!.name![0].toUpperCase() : '?',
                                              style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _pickAndUploadImage,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: AppColors.secondary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (!_isEditing) ...[
                        Text(
                          _user?.name ?? 'No name set',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _user?.email ?? '',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                        ),
                        if (_user?.phoneNumber != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _user!.phoneNumber!,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Wallet Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: AppColors.heroGradient,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.secondary.withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary, size: 28),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Wallet Points',
                                      style: TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w500),
                                    ),
                                    Text(
                                      '${_user?.callPointsBalance ?? 0} Pts',
                                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                                  ).then((_) => _loadProfile());
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.secondary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  minimumSize: const Size(0, 44),
                                  elevation: 0,
                                ),
                                child: const Text('Recharge', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),

                              ),
                            ],
                          ),
                        ),
                      ],

                      if (_isEditing) ...[
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(labelText: 'Name'),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _phoneCtrl,
                          decoration: const InputDecoration(labelText: 'Phone Number'),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _isSaving ? null : _save,
                          child: _isSaving
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Save Changes'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => setState(() => _isEditing = false),
                          child: const Text('Cancel'),
                        ),
                      ],

                      const SizedBox(height: 8),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Divider(color: AppColors.borderLight),
                      ),

                      // Menu Items
                      _MenuItem(
                        icon: Icons.workspace_premium_rounded,
                        label: 'My Membership',
                        subtitle: 'Current Plan: ${(_user?.planTier ?? 'base').toUpperCase()}',
                        color: const Color(0xFFF59E0B),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                          ).then((_) => _loadProfile());
                        },
                      ),
                      _MenuItem(
                        icon: Icons.language_rounded,
                        label: 'Language Control',
                        subtitle: context.locale.languageCode == 'ta' ? 'தமிழ்' : 'English',
                        color: const Color(0xFF3B82F6),
                        onTap: () {
                          if (context.locale.languageCode == 'en') {
                            context.setLocale(const Locale('ta'));
                          } else {
                            context.setLocale(const Locale('en'));
                          }
                        },
                      ),
                      _MenuItem(
                        icon: Icons.notifications_active_rounded,
                        label: 'App Notifications',
                        subtitle: _user?.notification == true ? 'Active' : 'Muted',
                        onTap: () async {
                          await _authService.updateProfile(notification: !(_user?.notification ?? false));
                          _loadProfile();
                        },
                      ),
                      _MenuItem(
                        icon: Icons.link_rounded,
                        label: 'account_linking'.tr(),
                        subtitle: 'Manage connections',
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
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ResetPasswordScreen(initialEmail: _user?.email),
                            ),
                          );
                        },
                      ),
                      _MenuItem(
                        icon: Icons.logout_rounded,
                        label: 'sign_out'.tr(),
                        color: AppColors.error,
                        onTap: _signOut,
                      ),

                      const SizedBox(height: 48),
                      Text(
                        'AgentGo v1.0.0',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
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
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: (color ?? AppColors.secondary).withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: color ?? AppColors.secondary, size: 22),
      ),
      title: Text(
        label,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
      subtitle: subtitle != null
          ? Text(subtitle!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary))
          : null,
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary, size: 20),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
    );
  }
}
