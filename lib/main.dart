import 'package:flutter/material.dart';

import 'data/score_repository.dart';
import 'screens/history_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = ScoreRepository();
  await repository.open();
  runApp(RingScoreApp(repository: repository));
}

class RingScoreApp extends StatelessWidget {
  const RingScoreApp({required this.repository, super.key});

  final ScoreRepository repository;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF17231F);
    const forest = Color(0xFF245B48);
    return MaterialApp(
      title: 'RingScore',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: forest,
          brightness: Brightness.light,
          surface: const Color(0xFFF7F8F4),
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F8F4),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF7F8F4),
          foregroundColor: ink,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            color: ink,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.1,
          ),
          titleLarge: TextStyle(color: ink, fontWeight: FontWeight.w700),
          titleMedium: TextStyle(color: ink, fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(color: ink),
          bodyMedium: TextStyle(color: Color(0xFF64716B)),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: Color(0xFFE7EBE5)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: forest,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 54),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
            ),
          ),
        ),
      ),
      home: HistoryScreen(repository: repository),
    );
  }
}
