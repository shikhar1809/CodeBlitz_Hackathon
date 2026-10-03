import 'package:flutter/material.dart';

import 'state/app_state.dart';
import 'ui/chat_screen.dart';
import 'ui/check_in_overlay.dart';
import 'ui/home_screen.dart';
import 'ui/onboarding_screen.dart';
import 'ui/profile_screen.dart';
import 'ui/theme.dart';
import 'ui/wallpaper_screen.dart';
import 'ui/widgets.dart';

class WingerApp extends StatelessWidget {
  final AppState state;
  const WingerApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) => AppScope(
        state: state,
        child: MaterialApp(
          title: 'Wallpapers',
          debugShowCheckedModeBanner: false,
          theme: W.theme(),
          builder: (context, child) => PortraitFrame(child: child!),
          home: const RootGate(),
        ),
      );
}

/// Locked: the wallpaper disguise. Not set up: onboarding. Otherwise Winger.
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    if (app.locked) return const WallpaperScreen();
    if (!app.settings.onboarded) return const OnboardingScreen();
    return const _Shell();
  }
}

class _Shell extends StatefulWidget {
  const _Shell();
  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  int _tab = 0;
  final _navKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final pages = const [HomeScreen(), ChatScreen(), ProfileScreen()];
    return Stack(children: [
      Scaffold(
        body: Column(children: [
          const SafeArea(bottom: false, child: StatusLine()),
          Expanded(
            child: Navigator(
              key: _navKey,
              onGenerateRoute: (_) => MaterialPageRoute(
                builder: (_) => _TabBody(tab: _tab, pages: pages, onTab: (t) => setState(() => _tab = t)),
              ),
            ),
          ),
        ]),
      ),
      if (app.showCheckIn) const Positioned.fill(child: CheckInOverlay()),
      if (app.banner != null)
        Positioned(
          left: 16,
          right: 16,
          bottom: 100,
          child: Material(
            color: W.text,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(app.banner!, style: const TextStyle(color: Colors.white)),
            ),
          ),
        ),
    ]);
  }
}

class _TabBody extends StatefulWidget {
  final int tab;
  final List<Widget> pages;
  final ValueChanged<int> onTab;
  const _TabBody({required this.tab, required this.pages, required this.onTab});
  @override
  State<_TabBody> createState() => _TabBodyState();
}

class _TabBodyState extends State<_TabBody> {
  late int _tab = widget.tab;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: _tab, children: widget.pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          backgroundColor: Colors.white,
          indicatorColor: W.containerHighest,
          onDestinationSelected: (t) {
            setState(() => _tab = t);
            widget.onTab(t);
          },
          destinations: const [
            NavigationDestination(icon: Icon(WIcons.homeOff), selectedIcon: Icon(WIcons.home, color: W.plum), label: 'Home'),
            NavigationDestination(icon: Icon(WIcons.helpOff), selectedIcon: Icon(WIcons.help, color: W.plum), label: 'Help'),
            NavigationDestination(
                icon: Icon(WIcons.profileOff), selectedIcon: Icon(WIcons.profile, color: W.plum), label: 'Profile'),
          ],
        ),
      );
}
