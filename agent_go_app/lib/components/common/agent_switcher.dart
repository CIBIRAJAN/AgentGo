import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../providers/agent_provider.dart';
import '../../config/theme/app_colors.dart';

class AgentSwitcher extends ConsumerWidget {
  final bool isLight;
  const AgentSwitcher({super.key, this.isLight = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agentState = ref.watch(agentProvider);
    final selectedAgent = agentState.selectedAgent;
    
    // Hide ONLY if we are NOT loading AND we only have 1 (self) or 0 agents
    if (!agentState.isLoading && agentState.availableAgents.length <= 1) {
      return const SizedBox.shrink();
    }

    // While loading, show a small shimmer or loading indicator if desired, 
    // or just the current agent if we have it.

    return GestureDetector(
      onTap: () {
        _showAgentSelection(context, ref, agentState);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isLight 
              ? AppColors.primary.withValues(alpha: 0.1) 
              : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
             Icon(
              Icons.person_pin_rounded,
              size: 16,
              color: isLight ? AppColors.primary : Colors.white70,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                selectedAgent?.name ?? 'viewing_all_agents'.tr(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isLight ? AppColors.primary : Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 14,
              color: isLight ? AppColors.primary : Colors.white70,
            ),
          ],
        ),
      ),
    );
  }

  void _showAgentSelection(BuildContext context, WidgetRef ref, AgentState state) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Consumer(
        builder: (context, ref, child) {
          final state = ref.watch(agentProvider);
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'switch_agent_perspective'.tr(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.groups_rounded, color: AppColors.primary, size: 20),
                  ),
                  title: Text('all_managed_agents'.tr()),
                  subtitle: Text('combined_view_subtitle'.tr()),
                  selected: state.selectedAgent == null,
                  selectedColor: AppColors.primary,
                  trailing: state.selectedAgent == null ? const Icon(Icons.check_circle_rounded, color: AppColors.primary) : null,
                  onTap: () {
                    ref.read(agentProvider.notifier).selectAgent(null);
                    Navigator.pop(ctx);
                  },
                ),
                const Divider(height: 1, indent: 70),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: state.availableAgents.length,
                    itemBuilder: (context, index) {
                      final agent = state.availableAgents[index];
                      final isMe = index == 0; // The first agent in the list is always self from RPC
                      
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.secondary.withValues(alpha: 0.1),
                          child: Text(
                            agent.name.substring(0, 1).toUpperCase(),
                            style: const TextStyle(color: AppColors.secondary, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(isMe ? 'me_label'.tr(args: [agent.name]) : agent.name),
                        subtitle: Text('agent_code_label'.tr(args: [agent.agentCode])),
                        selected: state.selectedAgent?.id == agent.id,
                        selectedColor: AppColors.primary,
                        trailing: state.selectedAgent?.id == agent.id 
                            ? const Icon(Icons.check_circle_rounded, color: AppColors.primary) 
                            : null,
                        onTap: () {
                          ref.read(agentProvider.notifier).selectAgent(agent);
                          Navigator.pop(ctx);
                        },
                      );
                    }
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
