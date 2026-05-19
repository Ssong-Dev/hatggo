import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'screens/main_screen.dart';

void main() async {
  // Flutter 바인딩 초기화 보장
  WidgetsFlutterBinding.ensureInitialized();
  
  // iOS Widget을 위한 App Group ID 설정
  await HomeWidget.setAppGroupId('group.com.ssong.hatggo');
  
  runApp(
    // Riverpod 상태 관리를 위한 ProviderScope로 앱을 감쌉니다.
    const ProviderScope(
      child: HatggoApp(),
    ),
  );
}

class HatggoApp extends StatelessWidget {
  const HatggoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hatggo',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFFDFCF8), // Warm White background
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF9B89FF), // Lavender Purple
          primary: const Color(0xFF9B89FF),
          secondary: const Color(0xFF6BCEB4), // Mint Green
          background: const Color(0xFFFDFCF8),
          surface: Colors.white,
        ),
        useMaterial3: true,
        fontFamily: 'Hansol',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFDFCF8),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.black87,
            fontSize: 22,
            fontWeight: FontWeight.w600,
            fontFamily: 'Hansol',
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Color(0xFF9B89FF),
          unselectedItemColor: Colors.black38,
          elevation: 8,
        ),
      ),
      home: const MainScreen(),
    );
  }
}
