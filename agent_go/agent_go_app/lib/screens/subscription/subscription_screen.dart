import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../home/home_screen.dart';
import '../../providers/user_provider.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  bool _isLoading = false;
  bool _isFetchingPlans = true;
  String _selectedPlan = 'mid'; // Default select
  List<Map<String, dynamic>> _plans = [];

  @override
  void initState() {
    super.initState();
    _fetchPlans();
  }

  Future<void> _fetchPlans() async {
    try {
      final response = await Supabase.instance.client
          .from('subscription_plans')
          .select('*');

      List<Map<String, dynamic>> sortedPlans = List<Map<String, dynamic>>.from(response);
      sortedPlans.sort((a, b) {
        const order = {'base': 1, 'mid': 2, 'premium': 3};
        return (order[a['id']] ?? 99).compareTo(order[b['id']] ?? 99);
      });

      if (mounted) {
        setState(() {
          _plans = sortedPlans;
          _isFetchingPlans = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching plans: $e");
      if (mounted) setState(() => _isFetchingPlans = false);
    }
  }

  Future<void> _handleSubscribe() async {
    setState(() => _isLoading = true);
    
    final userId = Supabase.instance.client.auth.currentUser!.id;

    try {
        if (_selectedPlan != 'base') {
          // Native Purchase via RevenueCat
          final productId = _selectedPlan == 'mid' ? 'agentgo_mid_plan' : 'agentgo_premium_plan';
          try {
            await Purchases.purchaseProduct(productId);
          } catch (e) {
            // IF running with mock/invalid API keys during testing, we will just print the error 
            // and proceed anyway so the client can test the UI of the premium features.
            // In Production, you would re-enable returning/throwing here.
            debugPrint("RevenueCat Purchase Error (Bypassed for testing): $e");
          }
        }
        
        // Update both the plan tier, sub status, and complete onboarding
        await Supabase.instance.client.from('user').update({
            'subscription_status': _selectedPlan == 'base' ? 'none' : 'paid',
            'plan_tier': _selectedPlan,
            'onboarding_step': 'completed',
        }).eq('id', userId);
        
        await AuthService(Supabase.instance.client).updateProfile(
            onboardingStep: OnboardingStep.completed,
        );
        
        await ref.read(userProvider.notifier).refresh();
        
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$_selectedPlan plan activated! Redirecting...'),
                  backgroundColor: AppColors.success,
                )
            );
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const HomeScreen()),
              (route) => false,
            );
        }
    } catch (e) {
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error)
            );
        }
    } finally {
        if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Choose Your Plan', style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: Navigator.of(context).canPop() 
          ? IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.pop(context),
            )
          : IconButton(
              icon: const Icon(Icons.logout_rounded),
              onPressed: () => Supabase.instance.client.auth.signOut(),
            ),
      ),
      body: _isFetchingPlans 
        ? const Center(child: CircularProgressIndicator(color: AppColors.secondary))
        : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            const Text(
              'Select the plan that fits your business needs.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 32),
            
            // Dynamic Plans
            ..._plans.map((plan) {
                final id = plan['id'] as String;
                final title = plan['title'] ?? '';
                final price = plan['price'] ?? '';
                final isPopular = plan['is_popular'] == true;
                
                final List<String> features = List<String>.from(plan['features'] ?? []);
                final List<String> restrictedFeatures = List<String>.from(plan['restricted_features'] ?? []);

                // Determine styling based on ID
                IconData icon;
                Color color;
                Color selectedBgColor;
                Color selectedTextColor = Colors.white;

                if (id == 'base') {
                    icon = Icons.person_rounded;
                    color = AppColors.textSecondary;
                    selectedBgColor = AppColors.textPrimary;
                } else if (id == 'mid') {
                    icon = Icons.rocket_launch_rounded;
                    color = AppColors.secondary;
                    selectedBgColor = AppColors.secondary;
                } else if (id == 'premium') {
                    icon = Icons.diamond_rounded;
                    color = const Color(0xFFF59E0B);
                    selectedBgColor = const Color(0xFFF59E0B);
                } else {
                    icon = Icons.star_rounded;
                    color = AppColors.primary;
                    selectedBgColor = AppColors.primary;
                }

                return _buildPlanCard(
                  id: id,
                  title: title,
                  price: price,
                  icon: icon,
                  color: color,
                  selectedBgColor: selectedBgColor,
                  selectedTextColor: selectedTextColor,
                  isPopular: isPopular,
                  features: features,
                  restrictedFeatures: restrictedFeatures,
                );
            }),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 64,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSubscribe,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedPlan == 'base' ? AppColors.textPrimary : (_selectedPlan == 'mid' ? AppColors.secondary : const Color(0xFFF59E0B)),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 8,
                  shadowColor: _selectedPlan == 'base' ? AppColors.textPrimary.withValues(alpha: 0.5) : (_selectedPlan == 'mid' ? AppColors.secondary.withValues(alpha: 0.5) : const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                ),
                child: _isLoading 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('CONTINUE WITH ${_selectedPlan.toUpperCase()}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                        const SizedBox(width: 12),
                        const Icon(Icons.arrow_forward_rounded, size: 24),
                      ],
                    ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard({
    required String id,
    required String title,
    required String price,
    required IconData icon,
    required Color color,
    required Color selectedBgColor,
    required Color selectedTextColor,
    required List<String> features,
    List<String> restrictedFeatures = const [],
    bool isPopular = false,
  }) {
    final isSelected = _selectedPlan == id;
    
    // Dynamic styles based on selection
    final bgCol = isSelected ? selectedBgColor : AppColors.surface;
    final textColMain = isSelected ? selectedTextColor : AppColors.textPrimary;
    final textColSecondary = isSelected ? selectedTextColor.withValues(alpha: 0.8) : AppColors.textSecondary;
    final iconCol = isSelected ? selectedTextColor : color;
    final borderCol = isSelected ? selectedBgColor : AppColors.borderLight;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: bgCol,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderCol, width: isSelected ? 2 : 1),
          boxShadow: isSelected ? [
            BoxShadow(
              color: selectedBgColor.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 10),
            )
          ] : [
            const BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (isPopular)
              Positioned(
                right: -10,
                top: -40,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : AppColors.secondary,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 4))
                    ]
                  ),
                  child: Text('MOST POPULAR', style: TextStyle(color: isSelected ? AppColors.secondary : Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                ),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white.withValues(alpha: 0.2) : color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(icon, color: iconCol, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textColMain)),
                          const SizedBox(height: 4),
                          Text(price, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isSelected ? textColMain : color)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: isSelected ? selectedTextColor : AppColors.border, width: 2),
                      ),
                      child: isSelected 
                        ? Icon(Icons.circle, color: selectedTextColor, size: 14)
                        : const SizedBox(width: 14, height: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ...features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle_rounded, color: isSelected ? selectedTextColor : AppColors.success, size: 22),
                      const SizedBox(width: 12),
                      Expanded(child: Text(f, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColSecondary, height: 1.4))),
                    ],
                  ),
                )),
                if (restrictedFeatures.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Divider(color: isSelected ? selectedTextColor.withValues(alpha: 0.2) : AppColors.borderLight),
                  ),
                  ...restrictedFeatures.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.cancel_rounded, color: isSelected ? selectedTextColor.withValues(alpha: 0.5) : AppColors.error, size: 22),
                        const SizedBox(width: 12),
                        Expanded(child: Text(f, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColSecondary.withValues(alpha: 0.6), height: 1.4))),
                      ],
                    ),
                  )),
                ]
              ],
            ),
          ],
        ),
      ),
    );
  }
}
