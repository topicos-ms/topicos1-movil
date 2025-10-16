import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'controllers/auth_controller.dart';
import 'controllers/enrollment_controller.dart';
import 'controllers/course_controller.dart';
import 'utils/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/enrollment_screen.dart';
import 'screens/courses_screen.dart';
import 'screens/academic_history_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Cargar variables de entorno
  await dotenv.load(fileName: ".env");
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(create: (_) => EnrollmentController()),
        ChangeNotifierProvider(create: (_) => CourseController()),
      ],
      child: MaterialApp(
        title: 'UAGRM',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        initialRoute: '/login',
        routes: {
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/home': (context) => const HomeScreen(),
          '/enrollment': (context) => const EnrollmentScreen(),
          '/courses': (context) => const CoursesScreen(),
          '/academic-history': (context) => const AcademicHistoryScreen(),
        },
      ),
    );
  }
}
