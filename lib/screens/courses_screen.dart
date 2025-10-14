import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/course_controller.dart';
import '../controllers/auth_controller.dart';
import '../models/course.dart';
import '../utils/app_colors.dart';
import '../widgets/loading_overlay.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final authController = context.read<AuthController>();
    final courseController = context.read<CourseController>();
    final studentId = authController.currentUser?.id;

    if (studentId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: No se pudo obtener el ID del estudiante'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      // Primero obtener el enrollment_id
      await courseController.loadEnrollmentId(studentId);
      
      if (courseController.enrollmentId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No tienes una matrícula activa. Por favor, matricúlate primero.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      // Luego cargar las materias recomendadas
      await courseController.loadRecommendedCourses(studentId);
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _enrollCourses() async {
    final courseController = context.read<CourseController>();
    
    try {
      await courseController.enrollSelectedCourses();
      
      if (mounted && courseController.successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(courseController.successMessage!),
            backgroundColor: Colors.green,
          ),
        );
        
        // Volver al home después de 2 segundos
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CourseController>(
      builder: (context, controller, child) {
        return LoadingOverlay(
          isLoading: controller.isLoading,
          child: Scaffold(
            appBar: AppBar(
              title: const Text(
                'INSCRIBIR MATERIAS',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            body: _buildBody(controller),
          ),
        );
      },
    );
  }

  Widget _buildBody(CourseController controller) {
    // Mostrar error si existe
    if (controller.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 64,
              ),
              const SizedBox(height: 20),
              Text(
                controller.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text('REINTENTAR'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Mostrar lista de materias
    if (controller.courses.isEmpty && !controller.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.school_outlined,
              color: Colors.grey,
              size: 64,
            ),
            const SizedBox(height: 20),
            const Text(
              'No hay materias recomendadas disponibles',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('RECARGAR'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header con información
        if (controller.courses.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: AppColors.primary.withOpacity(0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${controller.courses.length} materias disponibles',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (controller.selectedCourses.isNotEmpty)
                  Text(
                    '${controller.selectedCourses.length} materias seleccionadas',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.secondary,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
        ],

        // Lista de materias
        Expanded(
          child: ListView.builder(
            itemCount: controller.courses.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              final course = controller.courses[index];
              return _buildCourseCard(course, index, controller);
            },
          ),
        ),

        // Botón de inscripción
        if (controller.courses.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: controller.selectedCourses.isEmpty ? null : _enrollCourses,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                  child: Text(
                    controller.selectedCourses.isEmpty
                        ? 'SELECCIONA AL MENOS UNA MATERIA'
                        : 'INSCRIBIR ${controller.selectedCourses.length} MATERIA(S)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCourseCard(RecommendedCourse course, int index, CourseController controller) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: course.isSelected ? AppColors.secondary : Colors.transparent,
          width: 2,
        ),
      ),
      child: CheckboxListTile(
        value: course.isSelected,
        onChanged: (value) {
          controller.toggleCourseSelection(index);
        },
        activeColor: AppColors.secondary,
        title: Text(
          '${course.code} - ${course.name}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.stars,
                  size: 14,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 4),
                Text('${course.credits} créditos'),
                const SizedBox(width: 16),
                Icon(
                  Icons.layers,
                  size: 14,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 4),
                Text(course.levelName),
              ],
            ),
            if (course.prerequisites.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 14,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Requisitos: ${course.prerequisites.join(", ")}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Limpiar el estado del controlador al salir
    context.read<CourseController>().clearState();
    super.dispose();
  }
}

