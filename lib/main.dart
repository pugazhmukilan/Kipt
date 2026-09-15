import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'core/constants/app_constants.dart';
import 'core/navigation/app_route_observer.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/preferences_helper.dart';
import 'data/database/database_helper.dart';
import 'data/repositories/item_repository.dart';
import 'data/repositories/image_storage_service.dart';
import 'data/repositories/notification_service.dart';
import 'data/repositories/item_pdf_service.dart';
import 'data/repositories/backup_service.dart';
import 'presentation/bloc/item/item_bloc.dart';
import 'presentation/bloc/notification/notification_bloc.dart';
import 'presentation/bloc/notification/notification_event.dart';
import 'presentation/bloc/backup/backup_bloc.dart';
import 'presentation/bloc/theme/theme_cubit.dart';
import 'presentation/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize critical services in parallel to reduce startup time
  await Future.wait([
    PreferencesHelper.init(),
    Future(() => tz.initializeTimeZones()),
  ]);

  // Initialize notification service in background (non-blocking)
  NotificationService().initialize().catchError((e) {
    // Silent fail - notifications can be initialized later if needed
  });

  runApp(const KiptApp());
}

class KiptApp extends StatelessWidget {
  const KiptApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize repositories
    final databaseHelper = DatabaseHelper();
    final itemRepository = ItemRepository(databaseHelper: databaseHelper);
    final imageStorageService = ImageStorageService();
    final notificationService = NotificationService();
    final backupService = BackupService(
      itemRepository: itemRepository,
      imageStorageService: imageStorageService,
    );

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: itemRepository),
        RepositoryProvider.value(value: imageStorageService),
        RepositoryProvider.value(value: notificationService),
        RepositoryProvider.value(value: backupService),
        RepositoryProvider.value(value: ItemPdfService()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => ItemBloc(itemRepository: itemRepository),
          ),
          BlocProvider(
            create: (context) =>
                NotificationBloc(notificationService: notificationService)
                  ..add(InitializeNotifications()),
          ),
          BlocProvider(
            create: (context) => BackupBloc(backupService: backupService),
          ),
          BlocProvider(create: (context) => ThemeCubit()),
        ],
        child: BlocBuilder<ThemeCubit, ThemeMode>(
          builder: (context, themeMode) {
            return MaterialApp(
              title: AppConstants.appName,
              debugShowCheckedModeBanner: false,
              navigatorObservers: [appRouteObserver],
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeMode,
              home: const SplashScreen(),
            );
          },
        ),
      ),
    );
  }
}
