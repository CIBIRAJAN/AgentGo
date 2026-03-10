import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import '../../config/theme/app_colors.dart';
import '../../config/supabase_config.dart';
import '../../utils/formatters.dart';
import '../../services/pdf_processing_service.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/agent_provider.dart';
import '../../components/common/agent_switcher.dart';

/// Commission (salary PDF) upload & yearly income tracking.
class CommissionScreen extends ConsumerStatefulWidget {
  const CommissionScreen({super.key});

  @override
  ConsumerState<CommissionScreen> createState() => _CommissionScreenState();
}

class _CommissionScreenState extends ConsumerState<CommissionScreen> {
  List<Map<String, dynamic>> _uploads = [];
  bool _isLoading = true;
  bool _isUploading = false;

  List<String> get _targetUserIds => ref.read(agentProvider).targetUserIds;
  String get _currentUserId => Supabase.instance.client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('commission_uploads')
          .select()
          .filter('user_id', 'in', _targetUserIds)
          .order('commission_month', ascending: false);
      if (mounted) {
        setState(() {
          _uploads = (data as List).cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result == null || result.files.single.path == null) return;

    setState(() => _isUploading = true);

    try {
      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;
      
      // Determine owner agent
      final targetIds = _targetUserIds;
      String ownerId = _currentUserId;
      if (targetIds.length == 1) {
          ownerId = targetIds.first;
      } else {
          // If multiple agents in context, prompt to pick one (or default to current)
          // For now, let's use the first one if it's not the current user, or prompt
          // Reusing the picker logic if needed, but for simplicity let's pick the specific agent if selected.
          final selectedAgent = ref.read(agentProvider).selectedAgent?.id;
          if (selectedAgent != null) {
              ownerId = selectedAgent;
          }
      }

      final storagePath =
          '$ownerId/commission/${DateTime.now().millisecondsSinceEpoch}_$fileName';

      // Upload to Supabase storage
      await Supabase.instance.client.storage
          .from(SupabaseConfig.commissionBucket)
          .upload(storagePath, file);

      final fileUrl = Supabase.instance.client.storage
          .from(SupabaseConfig.commissionBucket)
          .getPublicUrl(storagePath);

      if (!mounted) return;

      // Ask for commission month
      final month = await _pickMonth();
      if (month == null) {
        setState(() => _isUploading = false);
        return;
      }

      // Create record
      final inserted = await Supabase.instance.client
          .from('commission_uploads')
          .insert({
            'user_id': ownerId,
            'file_name': fileName,
            'file_url': fileUrl,
            'storage_path': storagePath,
            'commission_month': month,
            'status': 'processing',
          })
          .select()
          .single();

      // Process PDF to mark dues as paid
      final pdfBytes = await file.readAsBytes();
      final processingService = PdfProcessingService(Supabase.instance.client);
      final resultData = await processingService.processCommissionPdf(
        pdfBytes: pdfBytes,
        commissionUploadId: inserted['id'] as String,
      );

      if (!mounted) return;
      setState(() => _isUploading = false);

      _showProcessingSummary(resultData);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.error),
        );
        setState(() => _isUploading = false);
      }
    }
  }

  void _showProcessingSummary(Map<String, dynamic> data) {
    final markedPaid = data['marked_paid'] ?? 0;
    final policyCount = data['policy_count'] ?? 0;
    final totalCommission = data['total_commission'] ?? 0;
    final matchedList = (data['matched_policies'] as List?) ?? [];
    final unmatchedList = (data['unmatched_policies'] as List?) ?? [];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Processing Results'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _summaryRow('Policies Found', '$policyCount'),
                _summaryRow('Dues Marked Paid', '$markedPaid', isBold: true),
                _summaryRow('Total Commission', Formatters.currency(totalCommission)),
                const Divider(height: 32),
                Text('Matched Policies (${matchedList.length})', 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                if (matchedList.isEmpty) 
                  const Text('No policies matched current dues.', style: TextStyle(fontSize: 12, color: Colors.grey))
                else
                  ...matchedList.take(20).map((p) => Text('• $p', style: const TextStyle(fontSize: 12))),
                if (matchedList.length > 20) 
                  Text('... and ${matchedList.length - 20} more', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                
                const SizedBox(height: 16),
                Text('Unmatched Policies (${unmatchedList.length})', 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange)),
                const SizedBox(height: 8),
                if (unmatchedList.isEmpty) 
                  const Text('All policies in PDF matched dues.', style: TextStyle(fontSize: 12, color: Colors.grey))
                else
                  ...unmatchedList.take(20).map((p) => Text('• $p', style: const TextStyle(fontSize: 12, color: Colors.orange))),
                if (unmatchedList.length > 20) 
                  Text('... and ${unmatchedList.length - 20} more', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(value, style: TextStyle(
            fontSize: 13, 
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isBold ? AppColors.success : null,
          )),
        ],
      ),
    );
  }

  Future<String?> _pickMonth() async {
    final now = DateTime.now();
    String selectedMonth =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';

    return showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController(text: selectedMonth);
        return AlertDialog(
          title: const Text('Commission Month'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              labelText: 'Month (YYYY-MM)',
              hintText: '2025-01',
            ),
            onChanged: (v) => selectedMonth = v,
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, selectedMonth),
                child: const Text('OK')),
          ],
        );
      },
    );
  }

  // Calculate totals
  double get _totalCommission =>
      _uploads.fold(0, (s, u) => s + ((u['total_commission'] as num?) ?? 0));
  double get _totalNetPayable =>
      _uploads.fold(0, (s, u) => s + ((u['net_payable'] as num?) ?? 0));

  @override
  Widget build(BuildContext context) {
    // Listen for agent changes
    ref.listen<AgentState>(agentProvider, (previous, next) {
      if (previous?.targetUserIds != next.targetUserIds) {
        _load();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('💰 Commission'),
        centerTitle: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isUploading ? null : _uploadPdf,
        icon: _isUploading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.upload_file_rounded),
        label: Text(_isUploading ? 'Uploading...' : 'Upload Commission PDF'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: AgentSwitcher(isLight: true),
          ),
          // Summary card
          if (_uploads.isNotEmpty)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Commission',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          Formatters.currency(_totalCommission),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 40, color: Colors.white24),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Net Payable',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          Formatters.currency(_totalNetPayable),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _uploads.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.account_balance_wallet_rounded,
                                size: 64,
                                color: AppColors.textTertiary
                                    .withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            Text('No commission PDFs yet',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                        color: AppColors.textTertiary)),
                            const SizedBox(height: 4),
                            Text(
                              'Upload your LIC commission/salary PDFs\nto track your yearly income',
                              textAlign: TextAlign.center,
                              style:
                                  Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          itemCount: _uploads.length,
                          itemBuilder: (ctx, index) {
                            final u = _uploads[index];
                            return _CommissionCard(
                              upload: u,
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _CommissionCard extends StatelessWidget {
  final Map<String, dynamic> upload;

  const _CommissionCard({
    required this.upload,
  });

  @override
  Widget build(BuildContext context) {
    final month = upload['commission_month'] as String? ?? '';
    final total = (upload['total_commission'] as num?)?.toDouble() ?? 0;
    final premium = (upload['total_premium'] as num?)?.toDouble() ?? 0;
    final net = (upload['net_payable'] as num?)?.toDouble() ?? 0;
    final fileName = upload['file_name'] as String? ?? 'Commission PDF';
    final status = upload['status'] as String? ?? 'uploaded';
    final batch = upload['batch'] as String? ?? '';
    final isProcessed = status == 'processed';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isProcessed
                      ? AppColors.success.withValues(alpha: 0.1)
                      : const Color(0xFFF59E0B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isProcessed
                      ? Icons.check_circle_rounded
                      : Icons.description_rounded,
                  color: isProcessed ? AppColors.success : const Color(0xFFF59E0B),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          month.isNotEmpty ? Formatters.dueMonth(month) : fileName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (batch.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(batch,
                                style: const TextStyle(
                                    fontSize: 9, color: AppColors.primary)),
                          ),
                        ],
                      ],
                    ),
                    Text(fileName,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isProcessed
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: isProcessed ? AppColors.success : AppColors.warning,
                  ),
                ),
              ),
            ],
          ),

          // Show values if processed
          if (isProcessed && (total > 0 || premium > 0)) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                _Stat('Premium', Formatters.currency(premium)),
                const SizedBox(width: 16),
                _Stat('Commission', Formatters.currency(total)),
                const SizedBox(width: 16),
                _Stat('Net Pay', Formatters.currency(net), isBold: true),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;

  const _Stat(this.label, this.value, {this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontSize: 10)),
          Text(value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 12,
                    color: AppColors.textPrimary,
                  )),
        ],
      ),
    );
  }
}
