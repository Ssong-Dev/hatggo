import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'screens/main_screen.dart';

void main() async {
  // Flutter 바인딩 초기화 보장
  WidgetsFlutterBinding.ensureInitialized();
  
  // iOS Widget을 위한 App Group ID 설정
  await HomeWidget.setAppGroupId('group.com.yourcompany.hatggo');
  
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        // pubspec.yaml에 선언한 fontFamily(Hansol)를 전역 기본 폰트로 설정합니다.
        fontFamily: 'Hansol',
      ),
      home: const MainScreen(),
    );
  }
}
