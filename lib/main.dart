import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';
import 'pages/chat_page.dart';
import 'pages/settings_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().initialize();
  await NotificationService().requestPermissionIfNeeded();
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
  );
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('theme');
    if (saved != null) {
      setState(() {
        _themeMode = saved == 'dark' ? ThemeMode.dark : ThemeMode.light;
      });
    }
  }

  void _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
    await prefs.setString(
        'theme', _themeMode == ThemeMode.dark ? 'dark' : 'light');
  }

  bool get _isDark => _themeMode == ThemeMode.dark;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'hertz',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: AppShell(
        isDark: _isDark,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;

  const AppShell({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _showSettings = false;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 600;

    final shellContent = Stack(
      children: [
        Positioned.fill(
          child: ChatPage(
            onNavigateSettings: () => setState(() => _showSettings = true),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !_showSettings,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              opacity: _showSettings ? 1.0 : 0.0,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                offset: _showSettings ? Offset.zero : const Offset(0.08, 0),
                child: SettingsPage(
                  isDark: widget.isDark,
                  onToggleTheme: widget.onToggleTheme,
                  onBack: () => setState(() => _showSettings = false),
                ),
              ),
            ),
          ),
        ),
      ],
    );

    if (isDesktop) {
      return PopScope(
        canPop: !_showSettings,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (_showSettings) {
            setState(() => _showSettings = false);
          }
        },
        child: Scaffold(
          backgroundColor:
              widget.isDark ? Colors.black : const Color(0xFFF9FAFB),
          body: Center(
            child: Container(
              width: 400,
              height: 850,
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.black : Colors.white,
                border: Border.all(
                  color: widget.isDark
                      ? const Color(0xFF27272A)
                      : Colors.black,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
              clipBehavior: Clip.hardEdge,
              child: shellContent,
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: !_showSettings,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_showSettings) {
          setState(() => _showSettings = false);
        }
      },
      child: shellContent,
    );
  }
}
