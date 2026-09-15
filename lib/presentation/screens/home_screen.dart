import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'items_list_screen.dart';
import '../../data/repositories/auth_service.dart';
import '../../core/navigation/app_route_observer.dart';
import '../../core/utils/image_picker_helper.dart';
import '../bloc/item/item_bloc.dart';
import '../bloc/item/item_event.dart';
import 'auth_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, RouteAware {
  bool _isShowingAuthScreen = false;
  bool _wasInBackground = false;
  bool _isSettingsActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is ModalRoute<void>) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    if (mounted) context.read<ItemBloc>().add(const LoadItems());
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Don't track lifecycle changes while showing auth screen or settings

    if (_isShowingAuthScreen || _isSettingsActive) return;

    // Track when app goes to background (not navigation events)
    if (state == AppLifecycleState.paused) {
      _wasInBackground = true;
    }

    // Re-authenticate when app comes back to foreground, unless the app was
    // only backgrounded by an OS-native picker (camera / gallery / file),
    // which is a normal flow inside the app, not the user leaving it.
    if (state == AppLifecycleState.resumed &&
        AuthService.isAppLockEnabled() &&
        _wasInBackground &&
        !ImagePickerHelper.isPickerActive) {
      _wasInBackground = false;
      _showAuthScreen();
    }
  }

  Future<void> _showAuthScreen() async {
    if (_isShowingAuthScreen) return;

    setState(() {
      _isShowingAuthScreen = true;
    });

    final authResult = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const AuthScreen(),
        fullscreenDialog: true,
      ),
    );

    setState(() {
      _isShowingAuthScreen = false;
    });

    // If authentication failed, user can try again by reopening the app
    if (authResult != true) {
      // Reset the background flag so it won't re-trigger until next background event
      _wasInBackground = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ItemsListScreen(
        onSettingsNavigationStart: () {
          setState(() {
            _isSettingsActive = true;
          });
        },
        onSettingsNavigationEnd: () {
          setState(() {
            _isSettingsActive = false;
            _wasInBackground = false; // Reset to prevent auth trigger
          });
        },
      ),
      // FAB is now inside ItemsListScreen to better integrate with scrolling
    );
  }
}
