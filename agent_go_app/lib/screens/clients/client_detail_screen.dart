import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/theme/app_colors.dart';
import '../../models/client_model.dart';
import '../../services/client_service.dart';
import '../../utils/formatters.dart';
import '../../utils/validators.dart';
import '../../utils/url_launcher_helper.dart';

/// Screen for viewing/editing client details + family members.
class ClientDetailScreen extends StatefulWidget {
  final ClientModel? client;
  final String? ownerId;
  const ClientDetailScreen({super.key, this.client, this.ownerId});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  late final ClientService _clientService;
  bool _isEditing = false;
  bool _isSaving = false;

  // Form controllers
  late TextEditingController _nameCtrl;
  late TextEditingController _policyCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _phoneCcCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _planCtrl;
  late TextEditingController _modeCtrl;
  late TextEditingController _amountCtrl;
  late TextEditingController _sumCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _nomineeCtrl;
  late TextEditingController _termCtrl;
  late TextEditingController _totalAmountCtrl;
  late TextEditingController _timeCtrl;

  DateTime? _dob;
  DateTime? _anniversary;
  DateTime? _policyStartDate;
  DateTime? _policyEndDate;
  DateTime? _doc;

  // Family members
  List<Map<String, dynamic>> _familyMembers = [];
  bool _loadingFamily = false;

  // Profile image
  String? _profileImageUrl;
  Uint8List? _localImageBytes;
  bool _uploadingImage = false;

  bool get _isNew => widget.client == null;

  @override
  void initState() {
    super.initState();
    _clientService = ClientService(Supabase.instance.client);
    _isEditing = _isNew;

    final c = widget.client;
    _nameCtrl = TextEditingController(text: c?.fullName ?? '');
    _policyCtrl = TextEditingController(text: c?.policyNumber ?? '');
    _phoneCtrl = TextEditingController(text: c?.mobileNumber ?? '');
    _phoneCcCtrl = TextEditingController(text: c?.mobileNumberCc ?? '+91');
    _addressCtrl = TextEditingController(text: c?.address ?? '');
    _planCtrl = TextEditingController(text: c?.plan ?? '');
    _modeCtrl = TextEditingController(text: c?.mode ?? '');
    _amountCtrl = TextEditingController(text: c?.premium ?? '');
    _sumCtrl = TextEditingController(text: c?.sum ?? '');
    _emailCtrl = TextEditingController(text: c?.email ?? '');
    _nomineeCtrl = TextEditingController(text: c?.nominee ?? '');
    _termCtrl = TextEditingController(text: c?.term ?? '');
    _totalAmountCtrl = TextEditingController(text: c?.amount ?? '');
    _timeCtrl = TextEditingController(text: c?.time ?? '');
    _profileImageUrl = c?.profileImageUrl;

    _dob = c?.dateOfBirth;
    _anniversary = c?.weddingAnniversary;
    _policyStartDate = c?.policyStartDate;
    _policyEndDate = c?.policyEndDate;
    _doc = c?.dateOfCommission;

    if (!_isNew) _loadFamily();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _policyCtrl.dispose();
    _phoneCtrl.dispose();
    _phoneCcCtrl.dispose();
    _addressCtrl.dispose();
    _planCtrl.dispose();
    _modeCtrl.dispose();
    _amountCtrl.dispose();
    _sumCtrl.dispose();
    _emailCtrl.dispose();
    _nomineeCtrl.dispose();
    _termCtrl.dispose();
    _totalAmountCtrl.dispose();
    _timeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFamily() async {
    if (_isNew) return;
    setState(() => _loadingFamily = true);
    try {
      final data = await Supabase.instance.client
          .from('family_members')
          .select()
          .eq('client_id', widget.client!.id)
          .order('created_at');
      if (mounted) {
        setState(() {
          _familyMembers = (data as List).cast<Map<String, dynamic>>();
          _loadingFamily = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingFamily = false);
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      Uint8List? bytes;
      if (file.bytes != null) {
        bytes = file.bytes;
      } else if (file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }
      if (bytes != null) {
        setState(() => _localImageBytes = bytes);
      }
    }
  }

  Future<String?> _uploadProfileImage() async {
    if (_localImageBytes == null) return _profileImageUrl;
    setState(() => _uploadingImage = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await Supabase.instance.client.storage
          .from('client-profiles')
          .uploadBinary(fileName, _localImageBytes!,
              fileOptions: const FileOptions(contentType: 'image/jpeg'));
      final url = Supabase.instance.client.storage
          .from('client-profiles')
          .getPublicUrl(fileName);
      setState(() {
        _profileImageUrl = url;
        _uploadingImage = false;
      });
      return url;
    } catch (e) {
      setState(() => _uploadingImage = false);
      debugPrint('Image upload error: $e');
      return _profileImageUrl;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      // Upload profile image if one was picked
      final imageUrl = await _uploadProfileImage();

      final data = {
        'full_name': _nameCtrl.text.trim(),
        'Policy_Number': _policyCtrl.text.trim(),
        'mobile_number': _phoneCtrl.text.trim(),
        'mobile_number_cc': _phoneCcCtrl.text.trim(),
        'Address': _addressCtrl.text.trim(),
        'Plan': _planCtrl.text.trim(),
        'Mode': _modeCtrl.text.trim(),
        'Premium': _amountCtrl.text.trim(),
        'Sum': _sumCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'nominee': _nomineeCtrl.text.trim(),
        'Term': _termCtrl.text.trim(),
        'Amount': _totalAmountCtrl.text.trim(),
        'Time': _timeCtrl.text.trim(),
        if (_dob != null) 'date_of_birth': _dob!.toIso8601String().split('T').first,
        if (_anniversary != null) 'wedding anniversary': _anniversary!.toIso8601String().split('T').first,
        if (_policyStartDate != null) 'policy_start_date': _policyStartDate!.toIso8601String().split('T').first,
        if (_policyEndDate != null) 'policy_end_date': _policyEndDate!.toIso8601String().split('T').first,
        if (_doc != null) 'Date of commision': _doc!.toIso8601String().split('T').first,
        if (imageUrl != null) 'profile_image_url': imageUrl,
        if (widget.ownerId != null) 'user_id': widget.ownerId,
      };

      if (_isNew) {
        await _clientService.addClient(data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Client added!'),
                backgroundColor: AppColors.success),
          );
          Navigator.pop(context);
        }
      } else {
        await _clientService.updateClient(widget.client!.id, data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Client updated!'),
                backgroundColor: AppColors.success),
          );
          setState(() => _isEditing = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Client'),
        content: Text(
            'Are you sure you want to delete ${widget.client!.fullName}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _clientService.deleteClient(widget.client!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Client deleted'),
              backgroundColor: AppColors.error),
        );
        Navigator.pop(context);
      }
    }
  }

  // ── Add Family Member ──
  void _addFamilyMember() {
    _showFamilyDialog(null);
  }

  void _editFamilyMember(Map<String, dynamic> member) {
    _showFamilyDialog(member);
  }

  void _showFamilyDialog(Map<String, dynamic>? existing) {
    final nameC = TextEditingController(text: existing?['full_name'] ?? '');
    final phoneC =
        TextEditingController(text: existing?['mobile_number'] ?? '');
    final relC = TextEditingController(text: existing?['relationship'] ?? '');
    String? dob = existing?['date_of_birth'];
    String? anniversary = existing?['wedding_anniversary'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(
              existing == null ? 'Add Family Member' : 'Edit Family Member'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameC,
                  decoration:
                      const InputDecoration(labelText: 'Full Name *'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: relC,
                  decoration: const InputDecoration(
                      labelText: 'Relationship',
                      hintText: 'e.g. Spouse, Son, Daughter'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneC,
                  decoration:
                      const InputDecoration(labelText: 'Mobile Number'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(dob != null
                      ? 'Birthday: $dob'
                      : 'Set Birthday'),
                  trailing: const Icon(Icons.cake_rounded, size: 20),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: dob != null
                          ? DateTime.tryParse(dob!) ?? DateTime(2000)
                          : DateTime(2000),
                      firstDate: DateTime(1920),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) {
                      setDlgState(() =>
                          dob = d.toIso8601String().split('T').first);
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(anniversary != null
                      ? 'Anniversary: $anniversary'
                      : 'Set Anniversary'),
                  trailing: const Icon(Icons.favorite_rounded,
                      size: 20, color: Colors.pink),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: anniversary != null
                          ? DateTime.tryParse(anniversary!) ??
                              DateTime(2000)
                          : DateTime(2000),
                      firstDate: DateTime(1920),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) {
                      setDlgState(() => anniversary =
                          d.toIso8601String().split('T').first);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            if (existing != null)
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await Supabase.instance.client
                      .from('family_members')
                      .delete()
                      .eq('id', existing['id']);
                  _loadFamily();
                },
                style:
                    TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Delete'),
              ),
            ElevatedButton(
              onPressed: () async {
                if (nameC.text.trim().isEmpty) return;
                Navigator.pop(ctx);

                final row = {
                  'client_id': widget.client!.id,
                  'user_id':
                      Supabase.instance.client.auth.currentUser!.id,
                  'full_name': nameC.text.trim(),
                  'relationship': relC.text.trim(),
                  'mobile_number': phoneC.text.trim(),
                  'date_of_birth': dob,
                  'wedding_anniversary': anniversary,
                };

                if (existing != null) {
                  await Supabase.instance.client
                      .from('family_members')
                      .update(row)
                      .eq('id', existing['id']);
                } else {
                  await Supabase.instance.client
                      .from('family_members')
                      .insert(row);
                }
                _loadFamily();
              },
              child: Text(existing == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            _isNew ? 'Add Client' : (widget.client!.fullName ?? 'Client')),
        actions: [
          if (!_isNew && !_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              onPressed: () => setState(() => _isEditing = true),
            ),
          if (!_isNew)
            IconButton(
              icon:
                  const Icon(Icons.delete_rounded, color: AppColors.error),
              onPressed: _delete,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Quick action buttons (view mode)
              if (!_isNew &&
                  !_isEditing &&
                  widget.client!.mobileNumber != null)
                Center(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => UrlLauncherHelper.makeCall(
                            widget.client!.fullPhoneNumber),
                        icon: const Icon(Icons.phone_rounded,
                            color: AppColors.success),
                        label: const Text('Call'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => UrlLauncherHelper.openWhatsApp(
                            phoneNumber:
                                widget.client!.fullPhoneNumber),
                        icon: const Icon(Icons.chat_rounded,
                            color: Color(0xFF25D366)),
                        label: const Text('WhatsApp'),
                      ),
                      if (widget.client!.email != null && widget.client!.email!.isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: () => UrlLauncherHelper.sendEmail(
                              widget.client!.email!),
                          icon: const Icon(Icons.email_rounded,
                              color: Colors.blue),
                          label: const Text('Email'),
                        ),
                    ],
                  ),
                ),
              if (!_isNew && !_isEditing) const SizedBox(height: 20),

              // Profile Photo (optional)
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: AppColors.primarySurface,
                      backgroundImage: _localImageBytes != null
                          ? MemoryImage(_localImageBytes!)
                          : (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
                              ? NetworkImage(_profileImageUrl!) as ImageProvider
                              : null,
                      child: (_localImageBytes == null &&
                              (_profileImageUrl == null || _profileImageUrl!.isEmpty))
                          ? Icon(Icons.person_rounded,
                              size: 48, color: AppColors.primary.withValues(alpha: 0.5))
                          : null,
                    ),
                    if (_isEditing)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _uploadingImage ? null : _pickImage,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: _uploadingImage
                                ? const Padding(
                                    padding: EdgeInsets.all(6),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.camera_alt_rounded,
                                    color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (_isEditing)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Tap camera to add photo (optional)',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 20),

              // Personal Info
              _SectionHeader(title: 'Personal Information'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameCtrl,
                decoration:
                    const InputDecoration(labelText: 'Full Name'),
                validator: (v) => Validators.required(v, 'Name'),
                enabled: _isEditing,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: TextFormField(
                      controller: _phoneCcCtrl,
                      decoration:
                          const InputDecoration(labelText: 'CC'),
                      enabled: _isEditing,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _phoneCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Mobile Number'),
                      keyboardType: TextInputType.phone,
                      enabled: _isEditing,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressCtrl,
                decoration:
                    const InputDecoration(labelText: 'Address'),
                maxLines: 2,
                enabled: _isEditing,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email Address'),
                keyboardType: TextInputType.emailAddress,
                enabled: _isEditing,
              ),
              if (_isEditing) ...[
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_dob != null ? 'Date of Birth: ${Formatters.date(_dob)}' : 'Select Date of Birth'),
                  trailing: const Icon(Icons.cake_rounded, size: 20),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _dob ?? DateTime(2000),
                      firstDate: DateTime(1920),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setState(() => _dob = d);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_anniversary != null ? 'Anniversary: ${Formatters.date(_anniversary)}' : 'Select Anniversary Date'),
                  trailing: const Icon(Icons.favorite_rounded, size: 20),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _anniversary ?? DateTime.now(),
                      firstDate: DateTime(1920),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) setState(() => _anniversary = d);
                  },
                ),
              ],

              const SizedBox(height: 24),
              _SectionHeader(title: 'Policy Details'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _policyCtrl,
                decoration: const InputDecoration(
                    labelText: 'Policy Number'),
                enabled: _isEditing,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _planCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Plan'),
                      enabled: _isEditing,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _modeCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Mode'),
                      enabled: _isEditing,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _termCtrl,
                      decoration: const InputDecoration(labelText: 'Term (Years)'),
                      keyboardType: TextInputType.number,
                      enabled: _isEditing,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _nomineeCtrl,
                      decoration: const InputDecoration(labelText: 'Nominee'),
                      enabled: _isEditing,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _amountCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Premium Amount'),
                      keyboardType: TextInputType.number,
                      enabled: _isEditing,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _sumCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Sum Assured'),
                      keyboardType: TextInputType.number,
                      enabled: _isEditing,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _totalAmountCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Base Amount/Inst. Premium'),
                      keyboardType: TextInputType.number,
                      enabled: _isEditing,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _timeCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Time'),
                      enabled: _isEditing,
                    ),
                  ),
                ],
              ),

              if (_isEditing) ...[
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_policyStartDate != null ? 'Start Date: ${Formatters.date(_policyStartDate)}' : 'Select Policy Start Date'),
                  trailing: const Icon(Icons.calendar_today_rounded, size: 20),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _policyStartDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) setState(() => _policyStartDate = d);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_policyEndDate != null ? 'End Date: ${Formatters.date(_policyEndDate)}' : 'Select Policy End Date'),
                  trailing: const Icon(Icons.event_busy_rounded, size: 20),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _policyEndDate ?? (_policyStartDate ?? DateTime.now()).add(const Duration(days: 365)),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) setState(() => _policyEndDate = d);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_doc != null ? 'D.O.C: ${Formatters.date(_doc)}' : 'Select Date of Commission (D.O.C)'),
                  trailing: const Icon(Icons.handshake_rounded, size: 20),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _doc ?? DateTime.now(),
                      firstDate: DateTime(1920),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) setState(() => _doc = d);
                  },
                ),
              ],

              // Dates info (view only)
              if (!_isNew && !_isEditing) ...[
                const SizedBox(height: 24),
                _SectionHeader(title: 'Dates'),
                const SizedBox(height: 12),
                if (widget.client!.dateOfBirth != null)
                  _InfoRow(
                      label: 'Date of Birth',
                      value: Formatters.date(widget.client!.dateOfBirth)),
                if (widget.client!.weddingAnniversary != null)
                  _InfoRow(
                      label: 'Anniversary',
                      value: Formatters.date(widget.client!.weddingAnniversary)),
                if (widget.client!.policyStartDate != null)
                  _InfoRow(
                      label: 'Policy Start',
                      value: Formatters.date(widget.client!.policyStartDate)),
                if (widget.client!.policyEndDate != null)
                  _InfoRow(
                      label: 'Policy End',
                      value: Formatters.date(widget.client!.policyEndDate)),
                if (widget.client!.dateOfCommission != null)
                  _InfoRow(
                      label: 'D.O.C',
                      value: Formatters.date(widget.client!.dateOfCommission)),
                _InfoRow(
                    label: 'Created',
                    value:
                        Formatters.date(widget.client!.createdAt)),
              ],

              // ── Family Members Section ──
              if (!_isNew && !_isEditing) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Expanded(
                        child:
                            _SectionHeader(title: 'Family Members')),
                    TextButton.icon(
                      onPressed: _addFamilyMember,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_loadingFamily)
                  const Center(
                      child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ))
                else if (_familyMembers.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.border.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.family_restroom_rounded,
                            color: AppColors.textTertiary,
                            size: 36),
                        const SizedBox(height: 8),
                        Text('No family members added yet',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall),
                        const SizedBox(height: 4),
                        Text(
                          'Add family to track birthdays & get policy leads',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontSize: 11),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else
                  ...(_familyMembers.map((m) => _FamilyCard(
                        member: m,
                        onTap: () => _editFamilyMember(m),
                      ))),
              ],

              if (_isEditing) ...[
                const SizedBox(height: 32),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white),
                          )
                        : Text(
                            _isNew ? 'Add Client' : 'Save Changes'),
                  ),
                ),
                if (!_isNew)
                  TextButton(
                    onPressed: () =>
                        setState(() => _isEditing = false),
                    child: const Text('Cancel'),
                  ),
              ],

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helper Widgets ──

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style:
          Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(value,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

class _FamilyCard extends StatelessWidget {
  final Map<String, dynamic> member;
  final VoidCallback onTap;

  const _FamilyCard({required this.member, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = member['full_name'] as String? ?? 'Unknown';
    final relationship = member['relationship'] as String? ?? '';
    final dob = member['date_of_birth'] as String?;
    final anniversary = member['wedding_anniversary'] as String?;
    final phone = member['mobile_number'] as String?;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFEC4899).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person_rounded,
                  color: Color(0xFFEC4899), size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(name,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (relationship.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.primary
                                .withValues(alpha: 0.1),
                            borderRadius:
                                BorderRadius.circular(4),
                          ),
                          child: Text(relationship,
                              style: const TextStyle(
                                  fontSize: 9,
                                  color: AppColors.primary)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (dob != null)
                        Text('🎂 $dob  ',
                            style: const TextStyle(fontSize: 10)),
                      if (anniversary != null)
                        Text('💍 $anniversary',
                            style: const TextStyle(fontSize: 10)),
                      if (phone != null && phone.isNotEmpty)
                        Text('  📱 $phone',
                            style: const TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.edit_rounded,
                size: 16, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
