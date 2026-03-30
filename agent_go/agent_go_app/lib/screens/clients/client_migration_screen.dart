import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../subscription/subscription_screen.dart';
import '../../models/user_model.dart';
import 'package:easy_localization/easy_localization.dart';

class ClientMigrationScreen extends StatefulWidget {
  const ClientMigrationScreen({super.key});

  @override
  State<ClientMigrationScreen> createState() => _ClientMigrationScreenState();
}

class _ClientMigrationScreenState extends State<ClientMigrationScreen> {
  String? _videoUrl;
  String? _videoId;
  bool _isVideoLoaded = false;
  bool _migrationComplete = false;
  bool _isUploading = false;
  int _totalClients = 0;
  
  bool _isPreviewing = false;
  List<Map<String, dynamic>> _newClients = [];
  List<Map<String, dynamic>> _duplicateClients = [];

  @override
  void initState() {
    super.initState();
    _fetchVideoUrl();
  }

  Future<void> _fetchVideoUrl() async {
    try {
      final res = await Supabase.instance.client
          .from('app_content')
          .select('value')
          .eq('Key', 'intro_video_link')
          .maybeSingle();

      if (res != null && res['value'] != null && mounted) {
        String url = res['value'];
        
        // Extract basic video ID from common youtube formats
        String? vidId;
        if (url.contains('v=')) {
          vidId = url.split('v=')[1].split('&').first;
        } else if (url.contains('youtu.be/')) {
          vidId = url.split('youtu.be/')[1].split('?').first;
        } else if (url.contains('embed/')) {
          vidId = url.split('embed/')[1].split('?').first;
        }

        if (vidId != null) {
          setState(() {
            _videoUrl = url;
            _videoId = vidId;
            _isVideoLoaded = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching video URL: $e');
    }
  }

  Future<void> _uploadAndMigrate() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'csv', 'xlsx', 'xls', 'numbers'],
    );

    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);
      setState(() {
        _isUploading = true;
      });

      try {
        final userId = AuthService(Supabase.instance.client).currentUserId;
        if (userId != null) {
          final ext = file.path.split('.').last;
          final fileName = 'client_data_$userId.$ext';
          
          await Supabase.instance.client.storage
              .from('client_imports')
              .upload(fileName, file, fileOptions: const FileOptions(upsert: true));
              
          final fileUrl = Supabase.instance.client.storage
              .from('client_imports')
              .getPublicUrl(fileName);

          // Put the URL in the user table
          await Supabase.instance.client
              .from('user')
              .update({'imported_file_url': fileUrl})
              .eq('id', userId);

          // Parse actual rows if CSV
          int parsedCount = 0;
          if (ext == 'csv') {
            try {
              final input = file.openRead();
              final fieldsRaw = await input
                  .transform(utf8.decoder)
                  .transform(const CsvDecoder())
                  .toList();
                  
              final fields = fieldsRaw.expand((e) => e).toList();
                  
              List<Map<String, dynamic>> clientsToInsert = [];
              for (var row in fields) {
                // If it looks like a valid row with SNo
                if (row.length >= 17 && int.tryParse(row[0].toString().trim()) != null) {
                  String? parseDate(String dateStr) {
                    if (dateStr.isEmpty) return null;
                    try {
                      final p = dateStr.contains('/') ? dateStr.split('/') : dateStr.split('-');
                      if (p.length == 3) {
                         return '${p[2]}-${p[1].padLeft(2, '0')}-${p[0].padLeft(2, '0')}';
                      }
                    } catch (_) {}
                    return null;
                  }

                  String pDob = parseDate(row[3].toString()) ?? '';
                  String pStartDate = parseDate(row[9].toString()) ?? '';

                  clientsToInsert.add({
                    'user_id': userId,
                    'full_name': row[2].toString().trim(),
                    'date_of_birth': pDob.isNotEmpty ? pDob : null,
                    'mobile_number': row[4].toString().trim(),
                    'email': row[5].toString().trim(),
                    'Address': row[6].toString().trim(),
                    'Policy_Number': row[7].toString().trim(),
                    'policy_start_date': pStartDate.isNotEmpty ? pStartDate : null,
                    'Plan': row[10].toString().trim(),
                    'Term': row[11].toString().trim(),
                    'Sum': row[13].toString().trim(),
                    'Mode': row[14].toString().trim(),
                    'Premium': row[16].toString().trim(),
                    'nominee': row[17].toString().trim(),
                  });
                }
              }

              if (clientsToInsert.isNotEmpty) {
                 final incomingPolicies = clientsToInsert
                     .map((c) => c['Policy_Number']?.toString().trim() ?? '')
                     .where((p) => p.isNotEmpty)
                     .toList();
                     
                 final existingRes = await Supabase.instance.client
                     .rpc('check_existing_policies', params: {'p_numbers': incomingPolicies});
                     
                 final existingPolicies = (existingRes as List)
                     .map((e) => e['policy_number'].toString().trim())
                     .toSet();

                 _newClients.clear();
                 _duplicateClients.clear();

                 for (var c in clientsToInsert) {
                   final pNumber = c['Policy_Number']?.toString().trim();
                   if (pNumber != null && existingPolicies.contains(pNumber)) {
                     _duplicateClients.add(c);
                   } else {
                     _newClients.add(c);
                   }
                 }

                 if (mounted) {
                   setState(() {
                      _isUploading = false;
                      _isPreviewing = true;
                   });
                 }
                 return;
              }
            } catch (e) {
              debugPrint('CSV Parse Error: $e');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('CSV Parsing/Insertion Error: $e'), backgroundColor: AppColors.error),
                );
              }
              rethrow; // Ensure we stop the flow and show the error
            }
          }

          if (mounted) {
            setState(() {
              _isUploading = false;
              _migrationComplete = true;
              // If it's 0 (like a Numbers file), we just show 1 to acknowledge the file.
              _totalClients = parsedCount > 0 ? parsedCount : 1; 
            });
          }
        }
      } catch (e) {
        debugPrint('Upload error: $e');
        if (mounted) {
          setState(() => _isUploading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error during migration: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  Future<void> _confirmMigration() async {
    setState(() => _isUploading = true);
    try {
      if (_newClients.isNotEmpty) {
         for (int i = 0; i < _newClients.length; i += 100) {
             int end = (i + 100 < _newClients.length) ? i + 100 : _newClients.length;
             await Supabase.instance.client
                 .from('client')
                 .upsert(_newClients.sublist(i, end), onConflict: 'Policy_Number');
         }
      }
      
      if (mounted) {
        setState(() {
          _isUploading = false;
          _isPreviewing = false;
          _migrationComplete = true;
          _totalClients = _newClients.length; 
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Insertion Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _navigateToNext() async {
    setState(() => _isUploading = true);
    try {
      await AuthService(Supabase.instance.client).updateProfile(onboardingStep: OnboardingStep.payment);
    } catch (_) {}
    if (mounted) {
      setState(() => _isUploading = false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('client_migration_title'.tr()),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'upload_existing_clients'.tr(),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'watch_tutorial'.tr(),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              
              // Video Section
              if (_isVideoLoaded && _videoId != null && _videoUrl != null)
                GestureDetector(
                  onTap: () async {
                    if (await canLaunchUrlString(_videoUrl!)) {
                      await launchUrlString(_videoUrl!, mode: LaunchMode.externalApplication);
                    }
                  },
                  child: Container(
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 5))
                      ],
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: 'https://img.youtube.com/vi/$_videoId/maxresdefault.jpg',
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => CachedNetworkImage(
                            imageUrl: 'https://img.youtube.com/vi/$_videoId/hqdefault.jpg',
                            fit: BoxFit.cover,
                            errorWidget: (c, u, e) => const Icon(Icons.video_library, size: 50, color: Colors.grey),
                          ),
                        ),
                        Container(color: Colors.black.withValues(alpha: 0.3)),
                        const Center(
                          child: Icon(Icons.play_circle_fill, size: 60, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text('loading_tutorial'.tr()),
                  ),
                ),
                
              const SizedBox(height: 32),
              
              // Upload Section
              if (_migrationComplete) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.success),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'client_migration_completed'.tr(),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.success),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Total $_totalClients new clients securely imported.',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ] else if (_isPreviewing) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Data Analysis Complete',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                              ),
                              child: Column(
                                children: [
                                  Text('${_newClients.length}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.success)),
                                  const SizedBox(height: 4),
                                  const Text('New Clients', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                              ),
                              child: Column(
                                children: [
                                  Text('${_duplicateClients.length}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.warning)),
                                  const SizedBox(height: 4),
                                  const Text('Duplicates', style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Note: Duplicates (already matching your policy numbers) will be ignored.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      if (_isUploading)
                        const Center(child: CircularProgressIndicator())
                      else ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _confirmMigration,
                            icon: const Icon(Icons.check_circle_rounded),
                            label: Text('Confirm & Migrate ${_newClients.length} New Clients'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isPreviewing = false;
                              _newClients.clear();
                              _duplicateClients.clear();
                            });
                          },
                          child: const Text('Cancel / Upload Another File'),
                        ),
                      ],
                    ],
                  ),
                ),
              ] else ...[
                Material(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: InkWell(
                    onTap: _isUploading ? null : _uploadAndMigrate,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                      child: Column(
                        children: [
                          if (_isUploading)
                            const SizedBox(width: 56, height: 56, child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary))
                          else
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.folder_shared_rounded, size: 56, color: AppColors.primary),
                            ),
                          const SizedBox(height: 24),
                          Text(
                            _isUploading ? 'uploading'.tr() : 'upload_data_file'.tr(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              
              const SizedBox(height: 48),
              
              // Next Button
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _migrationComplete ? _navigateToNext : null,
                  child: Text('next_btn'.tr()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
