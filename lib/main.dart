import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/sfx.dart';
import 'ui/game_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Прогреваем звуковой пул заранее, чтобы эффекты не запаздывали.
  Sfx.init();

  // Игра задумана вертикальной и занимает весь экран.
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const LitrDoDomaApp());
}

/// «Литр До Дома: Симулятор Очереди» — пиксельная городская аркада.
class LitrDoDomaApp extends StatelessWidget {
  const LitrDoDomaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Литр До Дома',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF19959C),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF000000),
      ),
      home: const GameScreen(),
    );
  }
}
