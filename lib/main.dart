import 'package:flutter/material.dart' hide Text;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'models/user_model.dart';
import 'screens/auth_screen.dart';
import 'screens/leader_home_screen.dart';
import 'screens/scouter_home_screen.dart';
import 'screens/strategy_home_screen.dart';
import 'services/auth_service.dart';
import 'services/data_repository.dart';
import 'services/local_db_service.dart';
import 'services/sync_service.dart';
import 'services/locale_service.dart';
import 'services/app_settings_service.dart';
import 'services/pit_scouting_service.dart';
import 'theme/elysium_theme.dart';

import 'package:google_fonts/google_fonts.dart';

import 'widgets/localized_text.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );

    await LocalDbService.instance.initialize();
    await AuthService.instance.restoreSession();
    await DataRepository.instance.start();
    await SyncService.instance.initialize();
    await LocaleService.instance.initialize();
    await AppSettingsService.instance.initialize();
    await PitScoutingService.instance.initialize();
  } catch (e) {
    // Never show a blank screen: tell the user what went wrong.
    runApp(_StartupError(error: e));
    return;
  }

  runApp(const FrcScoutingApp());
}

class FrcScoutingApp extends StatelessWidget {
  const FrcScoutingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        LocaleService.instance,
        AppSettingsService.instance,
      ]),
      builder: (context, _) {
        final locale = LocaleService.instance.locale;
        return MaterialApp(
          title: 'Elysium 1937 Scouting App',
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('he')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: Elysium.theme().copyWith(
            textTheme: locale.languageCode == 'he'
                ? GoogleFonts.assistantTextTheme(Elysium.theme().textTheme)
                : Elysium.theme().textTheme,
          ),
          darkTheme: Elysium.darkTheme().copyWith(
            textTheme: locale.languageCode == 'he'
                ? GoogleFonts.assistantTextTheme(Elysium.darkTheme().textTheme)
                : Elysium.darkTheme().textTheme,
          ),
          themeMode: AppSettingsService.instance.themeMode,
          themeAnimationDuration: Duration.zero,
          builder: (context, child) => Directionality(
            textDirection: locale.languageCode == 'he'
                ? TextDirection.rtl
                : TextDirection.ltr,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
          debugShowCheckedModeBanner: false,
          home: ListenableBuilder(
            listenable: Listenable.merge([
              AuthService.instance,
              LocaleService.instance,
            ]),
            builder: (context, _) {
              final user = AuthService.instance.currentUser;
              if (user == null) return AuthScreen();
              switch (user.role) {
                case UserRole.strategy:
                  return StrategyHomeScreen();
                case UserRole.leader:
                  return LeaderHomeScreen();
                default:
                  return ScouterHomeScreen();
              }
            },
          ),
        );
      },
    );
  }
}

class _StartupError extends StatelessWidget {
  final Object error;
  const _StartupError({required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: Elysium.theme(),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ElysiumFullLogo(height: 120),
                  const SizedBox(height: 20),
                  const Text(
                    'The app could not start',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Elysium.muted),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Check lib/config/supabase_config.dart (URL and publishable key).',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Elysium.muted),
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
