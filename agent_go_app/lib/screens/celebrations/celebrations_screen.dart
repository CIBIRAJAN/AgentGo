import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/theme/app_colors.dart';
import '../../utils/url_launcher_helper.dart';
import 'package:intl/intl.dart';
import '../../utils/poster_generator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/agent_provider.dart';

/// Screen showing upcoming birthdays and wedding anniversaries
/// for clients and their family members.
class CelebrationsScreen extends ConsumerStatefulWidget {
  const CelebrationsScreen({super.key});

  @override
  ConsumerState<CelebrationsScreen> createState() => _CelebrationsScreenState();
}

class _CelebrationsScreenState extends ConsumerState<CelebrationsScreen> {
  List<Map<String, dynamic>> _celebrations = [];
  bool _isLoading = true;
  String _filter = 'all'; // all, today, week, month
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  final _scrollController = ScrollController();
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(() {
      if (_scrollController.offset > 400 && !_showScrollToTop) {
        setState(() => _showScrollToTop = true);
      } else if (_scrollController.offset <= 400 && _showScrollToTop) {
        setState(() => _showScrollToTop = false);
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final targetUserIds = ref.read(agentProvider).targetUserIds;
      final data = await Supabase.instance.client.rpc(
        'get_upcoming_celebrations',
        params: {'p_user_ids': targetUserIds, 'p_days': 365},
      );
      if (mounted) {
        setState(() {
          _celebrations = (data as List).cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _onSearch(String q) {
    setState(() => _searchQuery = q.toLowerCase());
  }

  List<Map<String, dynamic>> get _filtered {
    return _celebrations.where((c) {
      final days = c['days_until'] as int? ?? 999;
      
      // Filter by period
      final matchesPeriod = switch (_filter) {
        'today' => days == 0,
        'week' => days <= 7,
        'month' => days <= 30,
        _ => true,
      };

      if (!matchesPeriod) return false;

      // Filter by search
      if (_searchQuery.isEmpty) return true;
      final name = (c['person_name'] as String? ?? '').toLowerCase();
      final cname = (c['client_name'] as String? ?? '').toLowerCase();
      final policy = (c['policy_number'] as String? ?? '').toLowerCase();

      return name.contains(_searchQuery) ||
          cname.contains(_searchQuery) ||
          policy.contains(_searchQuery);
    }).toList();
  }

  void _sendWish(Map<String, dynamic> celebration) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Send Wish Poster',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.primarySurface,
                child: Text('EN', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
              title: const Text('Wish in English'),
              onTap: () {
                Navigator.pop(ctx);
                _processWish(celebration, 'english');
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.primarySurface,
                child: Text('TA', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
              title: const Text('Wish in Tamil'),
              onTap: () {
                Navigator.pop(ctx);
                _processWish(celebration, 'tamil');
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8F5E9),
                child: Icon(Icons.flash_on_rounded, color: Color(0xFF2E7D32)),
              ),
              title: const Text('Direct WhatsApp (Tamil)'),
              subtitle: const Text('Straight to chat • No image'),
              onTap: () {
                Navigator.pop(ctx);
                _processWish(celebration, 'tamil', usePoster: false);
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE3F2FD),
                child: Icon(Icons.flash_on_rounded, color: Color(0xFF1976D2)),
              ),
              title: const Text('Direct WhatsApp (English)'),
              subtitle: const Text('Straight to chat • No image'),
              onTap: () {
                Navigator.pop(ctx);
                _processWish(celebration, 'english', usePoster: false);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _processWish(Map<String, dynamic> celebration, String language, {bool usePoster = true}) {
    final phone = celebration['phone_number'] as String?;
    final cc = celebration['phone_cc'] as String? ?? '+91';
    final name = celebration['person_name'] as String? ?? 'Friend';
    final eventType = celebration['event_type'] as String? ?? 'birthday';
    final isToday = (celebration['days_until'] as int? ?? 999) == 0;
    final source = celebration['source'] as String? ?? 'client';
    final clientName = celebration['client_name'] as String? ?? '';
    final agentName = Supabase.instance.client.auth.currentUser!.userMetadata?['full_name'] ?? 'Your Agent';

    String message;

    if (language == 'tamil') {
      if (source == 'family') {
        if (eventType == 'birthday') {
          message = isToday
              ? 'வணக்கம் $clientName,\nஉங்கள் குடும்ப உறுப்பினர் $name-க்கு இனிய பிறந்தநாள் நல்வாழ்த்துக்கள்! 🎂🎉\nஇந்த நாள் இனிய நாளாக அமைய வாழ்த்துக்கள்!\n\nஅன்புடன்,\n$agentName'
              : 'வணக்கம் $clientName,\nஉங்கள் குடும்ப உறுப்பினர் $name-க்கு முன்கூட்டியே பிறந்தநாள் வாழ்த்துக்கள்! 🎂🎉\n\nஅன்புடன்,\n$agentName';
        } else {
          message = isToday
              ? 'வணக்கம் $clientName,\nஉங்கள் குடும்ப உறுப்பினர் $name-க்கு இனிய திருமண நாள் வாழ்த்துக்கள்! 💍🎉\n\nஅன்புடன்,\n$agentName'
              : 'வணக்கம் $clientName,\nஉங்கள் குடும்ப உறுப்பினர் $name-க்கு முன்கூட்டியே திருமண நாள் வாழ்த்துக்கள்! 💍🎉\n\nஅன்புடன்,\n$agentName';
        }
      } else {
        if (eventType == 'birthday') {
          message = isToday
              ? '🎂 இனிய பிறந்தநாள் நல்வாழ்த்துக்கள் $name! 🎉\n\nஉங்கள் வாழ்வில் எல்லா வளங்களும் நலன்களும் பெற்று நீடூழி வாழ இறைவனை பிராத்திக்கிறேன்.\n\nஅன்புடன்,\n$agentName'
              : '🎂 முன்கூட்டியே பிறந்தநாள் நல்வாழ்த்துக்கள் $name! 🎉\n\nஅன்புடன்,\n$agentName';
        } else {
          message = isToday
              ? '💍 இனிய திருமண நாள் வாழ்த்துக்கள் $name! 🎉\n\nஇன்று போல என்றும் மகிழ்ச்சியாக வாழ வாழ்த்துக்கள்.\n\nஅன்புடன்,\n$agentName'
              : '💍 முன்கூட்டியே திருமண நாள் வாழ்த்துக்கள் $name! 🎉\n\nஅன்புடன்,\n$agentName';
        }
      }
    } else {
      if (source == 'family') {
        if (eventType == 'birthday') {
          message = isToday
              ? 'Hi $clientName, wishing your family member $name a very Happy Birthday! 🎂🎉\n\nWishing them a wonderful day filled with joy and blessings!\n\nWarm Regards\n$agentName'
              : 'Hi $clientName, Advance Birthday Wishes to your family member $name! 🎂🎉\n\nWishing them a fantastic celebration ahead!\n\nWarm Regards\n$agentName';
        } else {
          message = isToday
              ? 'Hi $clientName, wishing your family member $name a Happy Wedding Anniversary! 💍🎉\n\nWishing them a lifetime of love and happiness!\n\nWarm Regards\n$agentName'
              : 'Hi $clientName, Advance Anniversary Wishes to your family member $name! 💍🎉\n\nWishing them a beautiful celebration!\n\nWarm Regards\n$agentName';
        }
      } else {
        if (eventType == 'birthday') {
          message = isToday
              ? '🎂 Happy Birthday $name! 🎉\n\nWishing you a wonderful day filled with joy, happiness, and blessings. May this year bring you great health, wealth, and success!\n\nWarm Regards\n$agentName'
              : '🎂 Advance Birthday Wishes to $name! 🎉\n\nYour birthday is coming up soon! Wishing you a fantastic celebration ahead!\n\nWarm Regards\n$agentName';
        } else {
          message = isToday
              ? '💍 Happy Wedding Anniversary $name! 🎉\n\nWishing you and your partner a lifetime of love, happiness, and togetherness. May your bond grow stronger every day!\n\nWarm Regards\n$agentName'
              : '💍 Advance Anniversary Wishes to $name! 🎉\n\nYour wedding anniversary is approaching! Wishing you a beautiful celebration of your love!\n\nWarm Regards\n$agentName';
        }
      }
    }

    if (usePoster) {
      PosterGenerator.shareWishPoster(
        context: context,
        clientName: name,
        agentName: agentName,
        eventType: eventType,
        language: language,
        textMessage: message,
      );
    } else {
      if (phone == null || phone.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No phone number available')),
        );
        return;
      }
      UrlLauncherHelper.openWhatsApp(
        phoneNumber: '$cc$phone',
        message: message,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen for agent changes
    ref.listen(agentProvider, (previous, next) {
      if (previous?.selectedAgentId != next.selectedAgentId) {
        _load();
      }
    });

    final filtered = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🎉 Celebrations'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by name or policy number...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchCtrl.clear();
                          _onSearch('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: _onSearch,
            ),
          ),

          // Filter chips
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _FilterChip(
                    label: 'All',
                    selected: _filter == 'all',
                    onTap: () => setState(() => _filter = 'all')),
                _FilterChip(
                    label: '🎉 Today',
                    selected: _filter == 'today',
                    onTap: () => setState(() => _filter = 'today')),
                _FilterChip(
                    label: 'This Week',
                    selected: _filter == 'week',
                    onTap: () => setState(() => _filter = 'week')),
                _FilterChip(
                    label: 'This Month',
                    selected: _filter == 'month',
                    onTap: () => setState(() => _filter = 'month')),
              ],
            ),
          ),

          // Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              '${filtered.length} upcoming celebrations',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),

          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cake_rounded,
                                size: 64,
                                color:
                                    AppColors.textTertiary.withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            Text(
                              'No celebrations found',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                      color: AppColors.textTertiary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Add birthdates & anniversaries in client details',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final c = filtered[index];
                            return _CelebrationCard(
                              celebration: c,
                              onSendWish: () => _sendWish(c),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: _showScrollToTop
          ? FloatingActionButton.small(
              onPressed: () {
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                );
              },
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              child: const Icon(Icons.arrow_upward_rounded),
            )
          : null,
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppColors.textSecondary,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _CelebrationCard extends StatelessWidget {
  final Map<String, dynamic> celebration;
  final VoidCallback onSendWish;

  const _CelebrationCard({
    required this.celebration,
    required this.onSendWish,
  });

  @override
  Widget build(BuildContext context) {
    final name = celebration['person_name'] as String? ?? 'Unknown';
    final eventType = celebration['event_type'] as String? ?? 'birthday';
    final eventDate = celebration['event_date'] as String?;
    final daysUntil = celebration['days_until'] as int? ?? 999;
    final clientName = celebration['client_name'] as String? ?? '';
    final source = celebration['source'] as String? ?? 'client';
    final hasPhone = (celebration['phone_number'] as String?)?.isNotEmpty == true;

    final isBirthday = eventType == 'birthday';
    final emoji = isBirthday ? '🎂' : '💍';
    final color = isBirthday
        ? const Color(0xFFEC4899)
        : const Color(0xFFF59E0B);

    String daysLabel;
    if (daysUntil == 0) {
      daysLabel = 'Today! 🎉';
    } else if (daysUntil == 1) {
      daysLabel = 'Tomorrow';
    } else if (daysUntil <= 7) {
      daysLabel = 'In $daysUntil days';
    } else {
      daysLabel = 'In $daysUntil days';
    }

    String formattedDate = '';
    if (eventDate != null) {
      try {
        final d = DateTime.parse(eventDate);
        formattedDate = DateFormat('dd MMM').format(d);
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: daysUntil == 0
            ? color.withValues(alpha: 0.08)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: daysUntil == 0 ? color.withValues(alpha: 0.3) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          // Emoji / avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  source == 'family' ? '$name (Policyholder: $clientName)' : name,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '${isBirthday ? "Birthday" : "Anniversary"} • $formattedDate',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: daysUntil <= 1
                        ? color.withValues(alpha: 0.15)
                        : AppColors.border.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    daysLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: daysUntil <= 1 ? color : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // WhatsApp wish button
          if (hasPhone)
            GestureDetector(
              onTap: onSendWish,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chat_rounded,
                        color: Color(0xFF25D366), size: 18),
                    SizedBox(height: 2),
                    Text(
                      'Wish',
                      style: TextStyle(
                        color: Color(0xFF25D366),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
