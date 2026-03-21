import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'config/supabase_config.dart';
import 'config/theme/app_theme.dart';
import 'screens/subscription/subscription_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/auth/blocked_screen.dart';
import 'screens/auth/deleted_screen.dart';
import 'screens/splash/app_loading_screen.dart';
import 'screens/splash/welcome_screen.dart';
import 'screens/profile/agent_profile_fetch_screen.dart';
import 'screens/clients/client_migration_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/user_model.dart';
import 'services/notification_service.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait on mobile
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

   // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  // Initialize Stripe (Placeholder Key - you should move this to a secure config)
  Stripe.publishableKey = "pk_test_51BTjY5A1X7vY5A1X7vY5A1X7vY5A1X7vY5A1X7vY5A1X7vY5A1X7vY5A1X7vY5A1X7v";
  await Stripe.instance.applySettings();

  // Initialize RevenueCat (Native In-App Purchases)
  await Purchases.setLogLevel(LogLevel.debug);
  if (Platform.isIOS) {
    await Purchases.configure(PurchasesConfiguration("appl_REPLACE_WITH_APPLE_API_KEY"));
  } else if (Platform.isAndroid) {
    await Purchases.configure(PurchasesConfiguration("goog_REPLACE_WITH_GOOGLE_API_KEY"));
  }

  // Initialize notifications
  await NotificationService.init();

  // Initialize localization
  await EasyLocalization.ensureInitialized();

  runApp(
    ProviderScope(
      child: EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('ta')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        child: const AgentGoApp(),
      ),
    ),
  );
}

class AgentGoApp extends StatelessWidget {
  const AgentGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          title: 'AgentGo',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: const AuthGate(),
        );
      },
    );
  }
}

/// Listens to auth state and shows Login or Home accordingly.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

 class _AuthGateState extends State<AuthGate> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
         if (session == null) {
          return const WelcomeScreen();
        }

        // Use FutureBuilder with a retry mechanism if data is missing
        return FutureBuilder<Map<String, dynamic>?>(
          future: Supabase.instance.client
              .from('user')
              .select()
              .eq('id', session.user.id)
              .maybeSingle(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const AppLoadingScreen();
            }

            if (profileSnapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text('Error loading profile: ${profileSnapshot.error}'),
                  ),
                ),
              );
            }

            // If profile is missing, it might be a new user where the trigger hasn't finished.
            // We'll show the loading screen and trigger a state rebuild in a bit.
            if (profileSnapshot.data == null) {
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) setState(() {});
              });
              return const AppLoadingScreen();
            }

            final userData = profileSnapshot.data!;
            final user = UserModel.fromJson(userData);

            if (user.status == 'deleted') {
              return const DeletedScreen();
            }

            if (user.status == 'blocked') {
              return const BlockedScreen();
            }

            // Check onboarding
            if (user.onboardingStep == OnboardingStep.profile) {
              return const AgentProfileFetchScreen();
            }

            if (user.onboardingStep == OnboardingStep.migration) {
              return const ClientMigrationScreen();
            }

            if (user.onboardingStep == OnboardingStep.payment) {
              return const SubscriptionScreen();
            }

            // Check subscription (Admin role might be exempt)
            final role = Supabase.instance.client.auth.currentUser?.userMetadata?['role'] ?? 'agent';
            if (role != 'admin' && user.subscriptionStatus == 'none') {
              return const SubscriptionScreen();
            }

            return const HomeScreen();
          },
        );
      },
    );
  }
}
