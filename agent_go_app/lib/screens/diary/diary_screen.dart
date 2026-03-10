import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme/app_colors.dart';
import '../../models/agent_diary_model.dart';
import '../../services/agent_diary_service.dart';
import '../../utils/formatters.dart';
import '../../components/common/empty_state.dart';
import 'add_edit_diary_screen.dart';
import '../notifications/notification_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/agent_provider.dart';

class DiaryScreen extends ConsumerStatefulWidget {
  const DiaryScreen({super.key});

  @override
  ConsumerState<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends ConsumerState<DiaryScreen> {
  late final AgentDiaryService _service;
  List<AgentDiaryModel> _diaries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _service = AgentDiaryService(Supabase.instance.client);
    _loadDiaries();
  }

  Future<void> _loadDiaries() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final targetUserIds = ref.read(agentProvider).targetUserIds;
      final data = await AgentDiaryService(Supabase.instance.client, targetUserIds: targetUserIds).getDiaries();
      if (mounted) setState(() => _diaries = data);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _delete(String id) async {
    try {
      await _service.deleteDiary(id);
      _loadDiaries();
    } catch (_) {}
  }

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen for agent changes
    ref.listen(agentProvider, (previous, next) {
      if (previous?.selectedAgentId != next.selectedAgentId) {
        _loadDiaries();
      }
    });

    return Scaffold(
      appBar: ModalRoute.of(context)?.canPop ?? false
          ? AppBar(
              title: const Text('Agent Diary'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_rounded),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationScreen()));
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _loadDiaries,
                ),
              ],
            )
          : null,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddEditDiaryScreen()),
          );
          if (result == true) _loadDiaries();
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Appointment'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _diaries.isEmpty
              ? const EmptyState(
                  icon: Icons.book_rounded,
                  title: 'No Appointments Yet',
                  subtitle: 'Tap the button below to add an appointment to your diary.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16).copyWith(bottom: 100),
                  itemCount: _diaries.length,
                  itemBuilder: (context, index) {
                    final diary = _diaries[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: AppColors.border),
                      ),
                      elevation: 0,
                      color: AppColors.surface,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    diary.name,
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (diary.phoneNumber != null && diary.phoneNumber!.isNotEmpty)
                                      IconButton(
                                        icon: const Icon(Icons.phone_rounded, color: AppColors.success),
                                        onPressed: () => _call(diary.phoneNumber!),
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(8),
                                      ),
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert_rounded),
                                      onSelected: (val) async {
                                        if (val == 'edit') {
                                          final result = await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) => AddEditDiaryScreen(diary: diary)),
                                          );
                                          if (result == true) _loadDiaries();
                                        } else if (val == 'delete') {
                                          _delete(diary.id);
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Text('Edit Appointment'),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Delete Appointment', style: TextStyle(color: AppColors.error)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (diary.address != null && diary.address!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textTertiary),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      diary.address!,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 12),
                            const Divider(),
                            const SizedBox(height: 8),
                            _buildDateRow(context, 'Date 1', diary.appointmentDate1),
                            if (diary.appointmentDate2 != null)
                              _buildDateRow(context, 'Date 2', diary.appointmentDate2),
                            if (diary.appointmentDate3 != null)
                              _buildDateRow(context, 'Date 3', diary.appointmentDate3),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildDateRow(BuildContext context, String label, DateTime? date) {
    if (date == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text('$label: ', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
          Text(Formatters.dateTime(date), style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
