import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../clients/client_migration_screen.dart';
import '../../models/user_model.dart';
import 'package:easy_localization/easy_localization.dart';

class AgentProfileFetchScreen extends StatefulWidget {
  const AgentProfileFetchScreen({super.key});

  @override
  State<AgentProfileFetchScreen> createState() => _AgentProfileFetchScreenState();
}

class _AgentProfileFetchScreenState extends State<AgentProfileFetchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _agentCodeCtrl = TextEditingController();

  File? _imageFile;
  bool _isLoading = false;
  late final AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = AuthService(Supabase.instance.client);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _dobCtrl.dispose();
    _agentCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );
    if (result != null && result.files.single.path != null) {
      if (mounted) {
        setState(() {
          _imageFile = File(result.files.single.path!);
        });
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      if (mounted) {
        setState(() {
          _dobCtrl.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('profile_picture_required'.tr())),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? profileUrl;
      // Upload image to Supabase Storage
      final userId = _authService.currentUserId;
      if (userId == null) throw Exception('User not logged in');

      try {
        final ext = _imageFile!.path.split('.').last;
        final fileName = 'avatar_$userId.$ext';
        await Supabase.instance.client.storage
            .from('profiles')
            .upload(fileName, _imageFile!, fileOptions: const FileOptions(upsert: true));
        profileUrl = Supabase.instance.client.storage
            .from('profiles')
            .getPublicUrl(fileName);
      } catch (e) {
        // Fallback or ignore if bucket 'avatars' doesn't exist to make sure the app flow continues
        debugPrint('Image upload failed: $e');
      }

      await _authService.updateProfile(
        name: _nameCtrl.text.trim(),
        phoneNumber: _phoneCtrl.text.trim(),
        dob: _dobCtrl.text.trim(),
        agentCode: _agentCodeCtrl.text.trim(),
        profile: profileUrl,
        onboardingStep: OnboardingStep.migration,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ClientMigrationScreen()),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('complete_profile'.tr()),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   Center(
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primary, width: 2),
                          image: _imageFile != null
                              ? DecorationImage(
                                  image: FileImage(_imageFile!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: _imageFile == null
                            ? const Icon(Icons.camera_alt_rounded, size: 40, color: AppColors.primary)
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(child: Text('upload_profile_picture'.tr())),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(labelText: 'full_name'.tr()),
                    validator: (v) => v == null || v.isEmpty ? 'name_required'.tr() : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneCtrl,
                    decoration: InputDecoration(labelText: 'phone_number_label'.tr()),
                    keyboardType: TextInputType.phone,
                    validator: (v) => v == null || v.isEmpty ? 'phone_required'.tr() : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _dobCtrl,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'date_of_birth'.tr(),
                      suffixIcon: const Icon(Icons.calendar_today_rounded),
                    ),
                    onTap: () => _selectDate(context),
                    validator: (v) => v == null || v.isEmpty ? 'dob_required'.tr() : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _agentCodeCtrl,
                    decoration: InputDecoration(labelText: 'agent_code'.tr()),
                    validator: (v) => v == null || v.isEmpty ? 'agent_code_required'.tr() : null,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text('continue_btn'.tr()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
