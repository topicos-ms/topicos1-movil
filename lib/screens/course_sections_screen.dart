import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/course_controller.dart';
import '../controllers/auth_controller.dart';
import '../models/course.dart';
import '../utils/app_colors.dart';
import '../widgets/loading_overlay.dart';

class CourseSectionsScreen extends StatefulWidget {
  const CourseSectionsScreen({super.key});

  @override
  State<CourseSectionsScreen> createState() => _CourseSectionsScreenState();
}

class _CourseSectionsScreenState extends State<CourseSectionsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSections();
    });
  }

  Future<void> _loadSections() async {
    final courseController = context.read<CourseController>();
    final studentId = context.read<AuthController>().currentUser?.id;

    if (studentId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: No se pudo obtener el ID del estudiante'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // PASO 3: Cargar las secciones de todas las materias seleccionadas
      await courseController.loadSectionsForSelectedCourses();

      if (mounted && courseController.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(courseController.errorMessage!),
            backgroundColor: Colors.red,
          ),
        );
      }

      if (!mounted) return;

      await courseController.loadEnrollmentId(studentId);

      if (mounted && courseController.enrollmentId == null) {
        final message = courseController.errorMessage ??
            'No se pudo obtener tu matricula activa. Intenta nuevamente.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar informacion: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _proceedToEnrollment() async {
    final courseController = context.read<CourseController>();

    // Validar que exista al menos un grupo seleccionado
    if (!courseController.canProceedToEnrollment) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes seleccionar al menos un grupo'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (courseController.state == CourseLoadingState.loadingEnrollmentId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Estamos obteniendo tu matricula. Intenta nuevamente en unos segundos.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (courseController.enrollmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            courseController.errorMessage ??
                'No se pudo obtener tu matricula activa. Intenta nuevamente.',
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    try {
      // PASO 6: Inscribir las materias en lote (recibe jobId)
      final jobId = await courseController.enrollSelectedCourses();

      if (jobId != null && mounted) {
        // Mostrar modal con opciones
        _showEnrollmentModal(jobId);
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

  void _showEnrollmentModal(String jobId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        String infoMessage =
            'la solicitud de inscripcion esta siendo procesada en el servidor';
        bool isQuerying = false;

        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> handleQuery() async {
              if (isQuerying) return;
              setState(() {
                isQuerying = true;
              });

              final status = await _checkEnrollmentResult(jobId);

              if (!mounted) return;

              final courseController = this.context.read<CourseController>();
              final hasResult = courseController.enrollmentResult != null;
              const pendingStatuses = {
                'delayed',
                'waiting',
                'active',
                'prioritized',
                'queued',
                'pending',
                'added',
              };
              const failureStatuses = {'failed', 'timeout', 'error', 'stalled'};

              if (status == 'completed' && hasResult) {
                setState(() => isQuerying = false);
                Navigator.of(dialogContext).pop();
                Navigator.of(this.context)
                    .pushReplacementNamed('/enrollment-confirmation');
                return;
              }

              if (status != null && failureStatuses.contains(status) && hasResult) {
                setState(() => isQuerying = false);
                Navigator.of(dialogContext).pop();
                Navigator.of(this.context)
                    .pushReplacementNamed('/enrollment-confirmation');
                return;
              }

              if (status != null && pendingStatuses.contains(status)) {
                setState(() {
                  infoMessage =
                      'Tu inscripcion sigue en proceso. Vuelve a consultar en unos instantes.';
                  isQuerying = false;
                });
                return;
              }

              if (status == null ||
                  (status != null && failureStatuses.contains(status) && !hasResult)) {
                final message = courseController.errorMessage ??
                    'No se pudo consultar el estado de la inscripcion.';
                setState(() {
                  infoMessage = message;
                  isQuerying = false;
                });
                return;
              }

              setState(() {
                isQuerying = false;
              });
            }

            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.primary),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Inscripcion en Proceso',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    infoMessage,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.schedule, color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Presiona "CONSULTAR INSCRIPCION" para verificar el estado.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(this.context).popUntil((route) => route.isFirst);
                    this.context.read<CourseController>().clearState();
                  },
                  child: const Text('VOLVER AL MENU PRINCIPAL'),
                ),
                ElevatedButton.icon(
                  onPressed: isQuerying ? null : handleQuery,
                  icon: isQuerying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(isQuerying ? 'CONSULTANDO...' : 'CONSULTAR INSCRIPCION'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.secondary.withOpacity(0.6),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<String?> _checkEnrollmentResult(String jobId) async {
    final courseController = context.read<CourseController>();

    try {
      final status = await courseController.checkEnrollmentResult(jobId);

      if (!mounted) {
        return null;
      }

      final hasResult = courseController.enrollmentResult != null;

      if (status == 'completed' && hasResult) {
        return status;
      }

      const pendingStatuses = {
        'delayed',
        'waiting',
        'active',
        'prioritized',
        'queued',
        'pending',
        'added',
      };

      if (status != null && pendingStatuses.contains(status)) {
        return status;
      }

      const failureStatuses = {'failed', 'timeout', 'error', 'stalled'};

      if (status != null && failureStatuses.contains(status)) {
        if (hasResult) {
          return status;
        } else {
          final message = courseController.errorMessage ?? 'No se pudo completar la inscripcion.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.red,
            ),
          );
          return status;
        }
      }

      if (status == null) {
        final message = courseController.errorMessage ?? 'No se pudo consultar el estado de la inscripcion.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      }
      return status;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al consultar la inscripcion: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
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
                'SELECCIONAR GRUPOS A INSCRIBIR',
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
    final selectedCourses = controller.selectedCourses;

    if (selectedCourses.isEmpty) {
      return const Center(
        child: Text('No hay materias seleccionadas'),
      );
    }

    return Column(
      children: [
        // Header con progreso
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: AppColors.primary.withOpacity(0.1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selecciona los grupos que deseas inscribir',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_getSelectedSectionsCount(controller)}/${selectedCourses.length} grupos seleccionados',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Lista de materias con sus secciones
        Expanded(
          child: ListView.builder(
            itemCount: selectedCourses.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              final course = selectedCourses[index];
              final sections = controller.getSectionsForCourse(course.courseId);
              return _buildCourseWithSections(course, sections, controller);
            },
          ),
        ),

        // Boton para inscribir
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
                onPressed: controller.canProceedToEnrollment
                    ? _proceedToEnrollment
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
                child: Text(
                  controller.canProceedToEnrollment
                      ? 'INSCRIBIR MATERIAS'
                      : 'SELECCIONA AL MENOS UN GRUPO',
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

  int _getSelectedSectionsCount(CourseController controller) {
    return controller.selectedCourses
        .where((c) => c.selectedSectionId != null)
        .length;
  }

  Widget _buildCourseWithSections(
    RecommendedCourse course,
    List<CourseSection> sections,
    CourseController controller,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header de la materia
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.code,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        course.name,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                if (course.selectedSectionId != null)
                  Icon(
                    Icons.check_circle,
                    color: AppColors.success,
                    size: 28,
                  ),
              ],
            ),
          ),

          // Lista de secciones
          if (sections.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'No hay grupos disponibles para esta materia',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sections.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final section = sections[index];
                final isSelected = course.selectedSectionId == section.id;
                return _buildSectionTile(course, section, isSelected, controller);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTile(
    RecommendedCourse course,
    CourseSection section,
    bool isSelected,
    CourseController controller,
  ) {
    final hasAvailability = section.quotaAvailable > 0;

    return InkWell(
      onTap: hasAvailability
          ? () => controller.selectSectionForCourse(course.courseId, section.id)
          : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.secondary.withOpacity(0.1)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            // Radio button
            Radio<String>(
              value: section.id,
              groupValue: course.selectedSectionId,
              onChanged: hasAvailability
                  ? (value) => controller.selectSectionForCourse(
                        course.courseId,
                        section.id,
                      )
                  : null,
              activeColor: AppColors.secondary,
            ),

            // Informacion de la seccion
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Grupo ${section.groupLabel}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: hasAvailability ? Colors.black : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: section.shift == 'Morning' 
                              ? Colors.blue.withOpacity(0.2)
                              : section.shift == 'Afternoon'
                                  ? Colors.orange.withOpacity(0.2)
                                  : Colors.purple.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          section.shift == 'Morning'
                              ? 'Turno Manana'
                              : section.shift == 'Afternoon'
                                  ? 'Turno Tarde'
                                  : 'Turno Noche',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: hasAvailability
                              ? Colors.green.withOpacity(0.2)
                              : Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${section.quotaAvailable}/${section.quotaMax} cupos',
                          style: TextStyle(
                            fontSize: 11,
                            color: hasAvailability ? Colors.green.shade800 : Colors.red.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          section.professor.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: hasAvailability ? Colors.black87 : Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (section.schedules.isNotEmpty)
                    ...section.schedules.map((schedule) => Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              const Icon(Icons.schedule, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                '${schedule.day}: ${schedule.timeRange}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: hasAvailability ? Colors.black87 : Colors.grey,
                                ),
                              ),
                              if (schedule.classroom.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.room, size: 14, color: Colors.grey),
                                const SizedBox(width: 2),
                                Text(
                                  schedule.classroom,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: hasAvailability ? Colors.black87 : Colors.grey,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )),
                  if (!hasAvailability)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'GRUPO LLENO - SIN CUPOS DISPONIBLES',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
