import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'screens/auth_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/shell.dart';
import 'services/api.dart';
import 'services/auth_service.dart';
import 'services/pot_repository.dart';
import 'state/app_state.dart';
import 'theme.dart';
import 'widgets/brand.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var firebaseReady = false;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    firebaseReady = true;
  } catch (e) {
    debugPrint('Firebase not configured, running in demo mode: $e');
  }
  final state = AppState(
    auth: firebaseReady ? FirebaseAuthService() : LocalAuthService(),
    pots: firebaseReady ? FirestorePotRepository() : LocalPotRepository(),
    api: WorkerApi(),
  );
  await state.init();
  runApp(ChangeNotifierProvider.value(value: state, child: const PotfolioApp()));
}

class PotfolioApp extends StatelessWidget {
  const PotfolioApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Potfolio',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const _Gate(),
      );
}

class _Gate extends StatelessWidget {
  const _Gate();
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return ValueListenableBuilder<AppUser?>(
      valueListenable: s.auth.user,
      builder: (context, user, _) {
        if (!s.ready) return const _Splash();
        if (!s.onboarded) return const OnboardingScreen();
        if (user == null) return const AuthScreen();
        return const Shell();
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: PColors.cream,
        body: Center(child: PotfolioMark(size: 88, background: PColors.cream)),
      );
}
