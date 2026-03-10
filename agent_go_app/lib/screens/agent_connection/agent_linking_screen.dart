import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../config/theme/app_colors.dart';
import '../../services/agent_connection_service.dart';
import '../../models/agent_connection_model.dart';
import '../../components/common/empty_state.dart';
import 'package:share_plus/share_plus.dart';

class AgentLinkingScreen extends StatefulWidget {
  const AgentLinkingScreen({super.key});

  @override
  State<AgentLinkingScreen> createState() => _AgentLinkingScreenState();
}

class _AgentLinkingScreenState extends State<AgentLinkingScreen> {
  late final AgentConnectionService _service;
  final _codeCtrl = TextEditingController();
  
  List<AgentConnectionModel> _pendingRequests = [];
  List<AgentConnectionModel> _myConnections = [];
  List<AgentConnectionModel> _myManagers = [];
  bool _isLoading = true;
  String? _myAgentCode;

  @override
  void initState() {
    super.initState();
    _service = AgentConnectionService(Supabase.instance.client);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _service.getPendingRequests(),
        _service.getMyConnections(),
        _service.getManagers(),
        _service.getMyAgentCode(),
      ]);
      
      if (mounted) {
        setState(() {
          _pendingRequests = results[0] as List<AgentConnectionModel>;
          _myConnections = results[1] as List<AgentConnectionModel>;
          _myManagers = results[2] as List<AgentConnectionModel>;
          _myAgentCode = results[3] as String?;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendRequest() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) return;

    try {
      await _service.sendRequest(code);
      _codeCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('request_sent'.tr())),
        );
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString();
        // Clean up common Postgres/RPC error wrappers
        if (errorMsg.contains('PostgrestException(message: ')) {
          errorMsg = errorMsg.split('message: ').last.split(', code:').first;
        }
        _showErrorBottomSheet(errorMsg);
      }
    }
  }

  void _showErrorBottomSheet(String message) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('OK'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _respond(String id, String status) async {
    try {
      await _service.respondRequest(id, status);
      _loadData();
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('agent_linking_title'.tr()),
        centerTitle: true,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadData,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   _buildMyCodeCard(),
                   const SizedBox(height: 24),
                   _buildConnectForm(),
                   if (_pendingRequests.isNotEmpty) ...[
                     const SizedBox(height: 24),
                     _buildPendingRequests(),
                   ],
                   const SizedBox(height: 24),
                   _buildMyLinkedAgents(),
                   const SizedBox(height: 24),
                   _buildWhoManagesMe(),
                   const SizedBox(height: 100),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildMyCodeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'your_agent_code'.tr(),
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  _myAgentCode ?? 'loading'.tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
                if (_myAgentCode != null) {
                  Share.share(
                    'Join me on AgentGo! Connect with me using my Agent Code: $_myAgentCode to manage clients and dues efficiently.',
                    subject: 'AgentGo Connection Request',
                  );
                }
            },
            icon: const Icon(Icons.share_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'connect_with_agent'.tr(),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'enter_code_hint'.tr(),
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _codeCtrl,
                decoration: const InputDecoration(
                  hintText: 'Enter 8-digit code',
                  prefixIcon: Icon(Icons.pin_rounded),
                ),
                maxLength: 8,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              height: 52,
              margin: const EdgeInsets.only(bottom: 22),
              child: ElevatedButton(
                onPressed: _sendRequest,
                child: Text('connect'.tr()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPendingRequests() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'manage_access_requests'.tr(),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.warning),
        ),
        const SizedBox(height: 12),
        ..._pendingRequests.map((req) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.warning.withValues(alpha: 0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.warning.withValues(alpha: 0.1),
                  child: const Icon(Icons.person_add_disabled_rounded, color: AppColors.warning, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        req.managerName ?? 'Unknown Agent',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                        Text(
                          'wants_to_manage'.tr(),
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _respond(req.id, 'declined'),
                  child: Text('decline'.tr(), style: const TextStyle(color: AppColors.error)),
                ),
                ElevatedButton(
                  onPressed: () => _respond(req.id, 'accepted'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: Text('accept'.tr()),
                ),
              ],
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildMyLinkedAgents() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'agents_you_manage'.tr(),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (_myConnections.isEmpty)
           Text('no_agents_you_manage'.tr(), 
              style: const TextStyle(color: AppColors.textTertiary, fontSize: 13)),
        ..._myConnections.map((conn) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: const Icon(Icons.link_rounded, color: AppColors.primary),
          ),
          title: Text(conn.ownerName ?? 'Agent Account'),
          subtitle: Text('Code: ${conn.ownerAgentCode}'),
          trailing: IconButton(
            icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.error),
            onPressed: () => _service.removeConnection(conn.id).then((_) => _loadData()),
          ),
        )),
      ],
    );
  }

  Widget _buildWhoManagesMe() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'agents_managing_you'.tr(),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (_myManagers.isEmpty)
           Text('no_agents_manage_you'.tr(), 
              style: const TextStyle(color: AppColors.textTertiary, fontSize: 13)),
        ..._myManagers.map((conn) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: AppColors.secondary.withValues(alpha: 0.1),
            child: const Icon(Icons.verified_user_rounded, color: AppColors.secondary),
          ),
          title: Text(conn.managerName ?? 'manager_agent'.tr()),
          subtitle: Text('has_delegated_access'.tr()),
          trailing: IconButton(
            icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
            onPressed: () => _service.removeConnection(conn.id).then((_) => _loadData()),
          ),
        )),
      ],
    );
  }
}
