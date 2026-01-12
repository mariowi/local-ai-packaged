import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as sdk;
import 'package:livekit_components/livekit_components.dart' as components;
import 'package:provider/provider.dart';

import 'controllers/app_ctrl.dart';
import 'controllers/audio_filter_ctrl.dart';
import 'controllers/tool_status_ctrl.dart';
import 'controllers/wake_word_state_ctrl.dart';
import 'screens/agent_screen.dart';
import 'screens/setup_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/config_service.dart';
import 'ui/color_pallette.dart' show LKColorPaletteLight, LKColorPaletteDark;
import 'widgets/app_layout_switcher.dart';
import 'widgets/session_error_banner.dart';

class CaalApp extends StatefulWidget {
  final ConfigService configService;

  const CaalApp({super.key, required this.configService});

  @override
  State<CaalApp> createState() => _CaalAppState();
}

class _CaalAppState extends State<CaalApp> {
  AppCtrl? _appCtrl;

  @override
  void initState() {
    super.initState();
    _initializeAppCtrl();
  }

  void _initializeAppCtrl() {
    if (widget.configService.isConfigured) {
      _appCtrl = AppCtrl(
        serverUrl: widget.configService.serverUrl,
      );
    }
  }

  void _onConfigured() {
    setState(() {
      _appCtrl = AppCtrl(
        serverUrl: widget.configService.serverUrl,
      );
    });
  }

  @override
  void dispose() {
    _appCtrl?.dispose();
    super.dispose();
  }

  ThemeData buildTheme({required bool isLight}) {
    final colorPallete = isLight ? LKColorPaletteLight() : LKColorPaletteDark();

    return ThemeData(
      useMaterial3: true,
      cardColor: colorPallete.bg2,
      inputDecorationTheme: InputDecorationTheme(
        fillColor: colorPallete.bg2,
        hintStyle: TextStyle(
          color: colorPallete.fg4,
          fontSize: 14,
        ),
      ),
      buttonTheme: ButtonThemeData(
        disabledColor: Colors.red,
        colorScheme: ColorScheme.dark(
          primary: Colors.white,
          secondary: Colors.white,
          surface: const Color(0xFF45997C),
        ),
      ),
      colorScheme: isLight
          ? const ColorScheme.light(
              primary: Colors.black,
              secondary: Colors.black,
              surface: Colors.white,
            )
          : const ColorScheme.dark(
              primary: Colors.white,
              secondary: Colors.white,
              surface: Color(0xFF1A1A1A),
            ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show setup screen if not configured
    if (_appCtrl == null) {
      return ChangeNotifierProvider.value(
        value: widget.configService,
        child: MaterialApp(
          title: 'CAAL',
          theme: buildTheme(isLight: true),
          darkTheme: buildTheme(isLight: false),
          themeMode: ThemeMode.dark,
          home: SetupScreen(
            configService: widget.configService,
            onConfigured: _onConfigured,
          ),
        ),
      );
    }

    // Normal app flow with AppCtrl
    return ChangeNotifierProvider.value(
      value: widget.configService,
      child: ChangeNotifierProvider.value(
        value: _appCtrl!,
        child: Consumer<AppCtrl>(
          builder: (ctx, appCtrl, _) {
            final toolStatusCtrl = ToolStatusCtrl(room: appCtrl.room);
            final wakeWordStateCtrl = WakeWordStateCtrl(
              room: appCtrl.room,
              serverUrl: widget.configService.serverUrl,
            );
            final audioFilterCtrl = AudioFilterCtrl(room: appCtrl.room);

            return MultiProvider(
              key: ValueKey(appCtrl.sessionKey),
              providers: [
                ChangeNotifierProvider<sdk.Session>.value(value: appCtrl.session),
                ChangeNotifierProvider<components.RoomContext>.value(value: appCtrl.roomContext),
                ChangeNotifierProvider<ToolStatusCtrl>.value(value: toolStatusCtrl),
                ChangeNotifierProvider<WakeWordStateCtrl>.value(value: wakeWordStateCtrl),
                ChangeNotifierProvider<AudioFilterCtrl>.value(value: audioFilterCtrl),
              ],
              child: components.SessionContext(
                session: appCtrl.session,
                child: MaterialApp(
                  title: 'CAAL',
                  theme: buildTheme(isLight: true),
                  darkTheme: buildTheme(isLight: false),
                  themeMode: ThemeMode.dark,
                  home: Builder(
                    builder: (ctx) => Center(
                      child: Container(
                        constraints: BoxConstraints(maxWidth: 620),
                        child: Stack(
                          children: [
                            Selector<AppCtrl, AppScreenState>(
                              selector: (ctx, appCtx) => appCtx.appScreenState,
                              builder: (ctx, screen, _) => AppLayoutSwitcher(
                                frontBuilder: (ctx) => const WelcomeScreen(),
                                backBuilder: (ctx) => const AgentScreen(),
                                isFront: screen == AppScreenState.welcome,
                              ),
                            ),
                            const SessionErrorBanner(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
