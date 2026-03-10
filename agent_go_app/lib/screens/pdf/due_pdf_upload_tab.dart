import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/theme/app_colors.dart';
import '../../config/supabase_config.dart';
import '../../models/pdf_upload_model.dart';
import '../../services/pdf_service.dart';
import '../../services/pdf_processing_service.dart';
import '../../services/modified_pdf_service.dart';
import '../../utils/formatters.dart';
import '../../components/common/status_badge.dart';
import '../../components/common/empty_state.dart';
import '../../models/user_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/agent_provider.dart';
import '../../components/common/agent_switcher.dart';

/// Screen for uploading LIC due-list PDFs and viewing upload history.
class DuePdfUploadTab extends ConsumerStatefulWidget {
  const DuePdfUploadTab({super.key});

  @override
  ConsumerState<DuePdfUploadTab> createState() => _DuePdfUploadTabState();
}

class _DuePdfUploadTabState extends ConsumerState<DuePdfUploadTab> {
  late PdfService _pdfService;
  late final PdfProcessingService _processingService;
  List<PdfUploadModel> _uploads = [];
  bool _isLoading = true;
  bool _isUploading = false;
  String? _processingId; // track which upload is being processed

  @override
  void initState() {
    super.initState();
    final targetUserIds = ref.read(agentProvider).targetUserIds;
    _pdfService = PdfService(Supabase.instance.client, targetUserIds: targetUserIds);
    _processingService = PdfProcessingService(Supabase.instance.client);
    _loadUploads();
  }

  Future<void> _loadUploads() async {
    setState(() => _isLoading = true);
    try {
      final uploads = await _pdfService.getUploads();
      if (mounted) setState(() => _uploads = uploads);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUpload() async {
    try {
      // 1. Pick file
      final platformFile = await _pdfService.pickPdfFile();
      if (platformFile == null) return;

      if (!mounted) return;

      // 2. Choose Agent (if applicable)
      final agentState = ref.read(agentProvider);
      String? targetUserId;
      
      if (agentState.availableAgents.length > 1) {
        final agent = await _showAgentPicker(agentState.availableAgents);
        if (agent == null) return; // Cancelled
        targetUserId = agent.id;
      }

      // 3. Ask for due month
      final dueMonth = await _showMonthPicker();
      if (dueMonth == null) return;

      setState(() => _isUploading = true);

      final fileName =
          'due_list_${dueMonth}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      // Get file bytes for processing
      Uint8List bytes;
      if (platformFile.bytes != null) {
        bytes = platformFile.bytes!;
      } else if (platformFile.path != null) {
        bytes = await File(platformFile.path!).readAsBytes();
      } else {
        throw Exception('Cannot read file data');
      }

      // Upload
      final upload = await _pdfService.uploadPdf(
        platformFile: platformFile,
        fileName: fileName,
        dueMonth: dueMonth,
        targetUserId: targetUserId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF uploaded! Processing...'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadUploads();
      }

      // Auto-process
      setState(() {
        _isUploading = false;
        _processingId = upload.id;
      });

      try {
        final result = await _processingService.processPdf(
          pdfBytes: bytes,
          pdfUploadId: upload.id,
          dueMonth: dueMonth,
          targetUserId: targetUserId,
        );
        // ... rest of processing catch/finally logic

        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Processed ${result['records']} dues!'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadUploads();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ Processing failed: $e'),
              backgroundColor: AppColors.warning,
            ),
          );
          _loadUploads();
        }
      } finally {
        if (mounted) setState(() => _processingId = null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Upload failed: $e'),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  /// Reprocess an existing uploaded PDF.
  Future<void> _reprocess(PdfUploadModel upload) async {
    if (upload.dueMonth == null) return;

    setState(() => _processingId = upload.id);

    try {
      // Download the PDF from storage
      final bytes = await Supabase.instance.client.storage
          .from(SupabaseConfig.pdfBucket)
          .download('${Supabase.instance.client.auth.currentUser!.id}/${upload.fileName}');

      final result = await _processingService.processPdf(
        pdfBytes: bytes,
        pdfUploadId: upload.id,
        dueMonth: upload.dueMonth!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Processed ${result['records']} dues!'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadUploads();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Processing failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processingId = null);
    }
  }

  Future<String?> _showMonthPicker() async {
    final now = DateTime.now();
    int selectedYear = now.year;
    int selectedMonth = now.month;

    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Due Month'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded),
                        onPressed: () {
                          setDialogState(() {
                            selectedYear--;
                          });
                        },
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            '$selectedYear',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded),
                        onPressed: () {
                          setDialogState(() {
                            selectedYear++;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(12, (i) {
                      final month = i + 1;
                      final isSelected = month == selectedMonth;
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() => selectedMonth = month);
                        },
                        child: Container(
                          width: 60,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              _monthNames[i],
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textPrimary,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final monthStr = selectedMonth.toString().padLeft(2, '0');
                    Navigator.pop(ctx, '$selectedYear-$monthStr');
                  },
                  child: const Text('Select'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  Future<AgentDetails?> _showAgentPicker(List<AgentDetails> agents) async {
    return showDialog<AgentDetails>(
      context: context,
      builder: (ctx) => _AgentSelectDialog(agents: agents),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen for agent changes to refresh history
    ref.listen<AgentState>(agentProvider, (previous, next) {
      if (previous?.targetUserIds != next.targetUserIds) {
        _pdfService = PdfService(Supabase.instance.client, targetUserIds: next.targetUserIds);
        _loadUploads();
      }
    });

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isUploading ? null : _pickAndUpload,
        icon: _isUploading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.upload_file_rounded),
        label: Text(_isUploading ? 'Uploading...' : 'Upload PDF'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
                  onRefresh: _loadUploads,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                    itemCount: _uploads.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return const Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: AgentSwitcher(isLight: true),
                        );
                      }
                      
                      final upload = _uploads[index - 1];
                      return _UploadCard(
                        upload: upload,
                        isProcessing: _processingId == upload.id,
                        onProcess: (upload.status == 'uploaded' || upload.status == 'failed')
                            ? () => _reprocess(upload)
                            : null,
                      );
                    },
                  ),
                ),
    );
  }
}

class _UploadCard extends StatefulWidget {
  final PdfUploadModel upload;
  final bool isProcessing;
  final VoidCallback? onProcess;

  const _UploadCard({
    required this.upload,
    this.isProcessing = false,
    this.onProcess,
  });

  @override
  State<_UploadCard> createState() => _UploadCardState();
}

class _UploadCardState extends State<_UploadCard> {
  bool _isGenerating = false;

  Future<void> _downloadModifiedPdf() async {
    if (widget.upload.dueMonth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No due month set for this upload')),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final service = ModifiedPdfService(Supabase.instance.client);
      final user = Supabase.instance.client.auth.currentUser;
      final name = user?.userMetadata?['full_name'] ??
          user?.email?.split('@').first ??
          'Agent';

      await service.shareModifiedPdf(
        dueMonth: widget.upload.dueMonth!,
        agentName: name,
        agentCode: '',
        branchCode: '',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error generating PDF: $e'),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final upload = widget.upload;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // PDF icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.picture_as_pdf_rounded,
                    color: AppColors.error, size: 24),
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      upload.fileName,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        if (upload.dueMonth != null)
                          Text(
                            Formatters.dueMonth(upload.dueMonth),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        Text(
                          '${upload.recordsExtracted ?? 0} records',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Formatters.timeAgo(upload.createdAt),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ),

              // Status
              StatusBadge(status: upload.status),
            ],
          ),

          // Process button for uploaded/failed PDFs
          if ((upload.status == 'uploaded' || upload.status == 'failed') &&
              widget.onProcess != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.isProcessing ? null : widget.onProcess,
                icon: widget.isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.play_arrow_rounded, size: 18),
                label: Text(widget.isProcessing
                    ? 'Processing...'
                    : 'Process Now – Extract Dues'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  textStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],

          // Download Modified PDF button (only for completed uploads)
          if (upload.status == 'completed' && upload.dueMonth != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isGenerating ? null : _downloadModifiedPdf,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child:
                            CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_rounded, size: 18),
                label: Text(_isGenerating
                    ? 'Generating...'
                    : 'Download Modified PDF (with Phone Numbers)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding:
                      const EdgeInsets.symmetric(vertical: 10),
                  textStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AgentSelectDialog extends StatelessWidget {
  final List<AgentDetails> agents;

  const _AgentSelectDialog({required this.agents});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Agent'),
      contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: agents.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (ctx, index) {
            final agent = agents[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Text(
                  agent.name.characters.first,
                  style: const TextStyle(color: AppColors.primary),
                ),
              ),
              title: Text(agent.name),
              subtitle: Text('Code: ${agent.agentCode}'),
              onTap: () => Navigator.pop(ctx, agent),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
