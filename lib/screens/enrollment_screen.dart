import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_colors.dart';
import '../controllers/enrollment_controller.dart';
import '../controllers/auth_controller.dart';
import '../models/period.dart';
import '../widgets/loading_overlay.dart';

class EnrollmentScreen extends StatefulWidget {
  const EnrollmentScreen({super.key});

  @override
  State<EnrollmentScreen> createState() => _EnrollmentScreenState();
}

class _EnrollmentScreenState extends State<EnrollmentScreen> {
  @override
  void initState() {
    super.initState();
    // Cargar períodos al iniciar la pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EnrollmentController>().loadPeriods();
    });
  }

  Future<void> _handleEnrollment() async {
    final enrollmentController = context.read<EnrollmentController>();
    final authController = context.read<AuthController>();
    
    final studentId = authController.currentUser?.id;
    
    if (studentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: No se pudo obtener ID de estudiante'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final success = await enrollmentController.enrollStudent(studentId);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(enrollmentController.successMessage ?? 'Matrícula exitosa'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 3),
          ),
        );
        
        // Esperar un momento y regresar al home
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(enrollmentController.errorMessage ?? 'Error al matricularse'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final enrollmentController = context.watch<EnrollmentController>();
    final authController = context.watch<AuthController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Matricularse - UAGRM'),
        backgroundColor: AppColors.primary,
      ),
      body: LoadingOverlay(
        isLoading: enrollmentController.isLoading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Información del estudiante
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Información del Estudiante',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(
                        icon: Icons.person,
                        label: 'Nombre:',
                        value: '${authController.currentUser?.firstName ?? ''} ${authController.currentUser?.lastName ?? ''}',
                      ),
                      const SizedBox(height: 8),
                      _InfoRow(
                        icon: Icons.email,
                        label: 'Email:',
                        value: authController.currentUser?.email ?? '',
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Selector de período
              const Text(
                'Selecciona el Período Académico',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              
              const SizedBox(height: 12),
              
              if (enrollmentController.hasPeriods)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.primary),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton(
                      value: enrollmentController.selectedPeriod,
                      isExpanded: true,
                      hint: const Text('Selecciona un período'),
                      items: enrollmentController.periods.map((period) {
                        return DropdownMenuItem(
                          value: period,
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: period.isActive ? AppColors.success : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Text(period.name),
                              if (period.isActive) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.success,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Activo',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: enrollmentController.isLoading
                          ? null
                          : (value) {
                              enrollmentController.setSelectedPeriod(value as Period?);
                            },
                    ),
                  ),
                )
              else if (!enrollmentController.isLoading)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.warning),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: AppColors.warning),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'No hay períodos disponibles',
                          style: TextStyle(color: AppColors.warning),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          enrollmentController.loadPeriods();
                        },
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              
              if (enrollmentController.selectedPeriod != null) ...[
                const SizedBox(height: 16),
                Card(
                  elevation: 1,
                  color: AppColors.primary.withOpacity(0.05),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Detalles del Período',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _InfoRow(
                          icon: Icons.date_range,
                          label: 'Inicio:',
                          value: enrollmentController.selectedPeriod!.startDate,
                        ),
                        const SizedBox(height: 4),
                        _InfoRow(
                          icon: Icons.event,
                          label: 'Fin:',
                          value: enrollmentController.selectedPeriod!.endDate,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              
              const SizedBox(height: 32),
              
              // Botón de matrícula
              ElevatedButton(
                onPressed: enrollmentController.isLoading ||
                        enrollmentController.selectedPeriod == null
                    ? null
                    : _handleEnrollment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 3,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'MATRICULARSE',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Mensajes de error/éxito
              if (enrollmentController.errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: AppColors.error),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          enrollmentController.errorMessage!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
