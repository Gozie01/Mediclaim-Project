import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'constants/app_theme.dart';
import 'screens/role_selector.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const MediClaimApp());
}

class MediClaimApp extends StatelessWidget {
  const MediClaimApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediClaim Chain',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const RoleSelectorScreen(),
    );
  }
}
