import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'core/vietnamese_localizations.dart';
import 'screens/role_selection_screen.dart';

void main() {
  runApp(const LMSApp());
}

class LMSApp extends StatelessWidget {
  const LMSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hỗ trợ học tập LMS',
      debugShowCheckedModeBanner: false,
      locale: const Locale('vi', 'VN'),
      supportedLocales: const [Locale('vi', 'VN')],
      localizationsDelegates: const [
        VietnameseMaterialDelegate(),
        VietnameseWidgetsDelegate(),
        VietnameseCupertinoDelegate(),
      ],
      theme: AppTheme.lightTheme,
      home: const RoleSelectionScreen(),
    );
  }
}
