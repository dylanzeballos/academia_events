// lib/features/purchases/views/class_enroll_detail_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../providers/dance_class_provider.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_feedback.dart';
import '../../../../shared/widgets/loading_indicator.dart';

class ClassEnrollDetailView extends ConsumerStatefulWidget {
  const ClassEnrollDetailView({super.key, this.classId});

  final String? classId;

  @override
  ConsumerState<ClassEnrollDetailView> createState() =>
      _ClassEnrollDetailViewState();
}

class _ClassEnrollDetailViewState extends ConsumerState<ClassEnrollDetailView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  String? _selectedClassId;
  int _selectedPackSessions = 12; // 8 o 12 sesiones por defecto

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _selectedClassId = widget.classId;
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _confirmEnrollment({required bool isVip, required double price}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardBg,
        title: Text(
          isVip ? 'Confirmar Pase VIP' : 'Confirmar Inscripción',
          style: TextStyle(
            color: context.textOnBg,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isVip
                  ? 'Acceso total e ilimitado a todas las clases por 30 días.'
                  : 'Paquete de $_selectedPackSessions sesiones regulares.',
              style: TextStyle(color: context.textMuted),
            ),
            const SizedBox(height: 12),
            Text(
              'Total a pagar: ${price.toInt()} BOB',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: TextStyle(color: context.textMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              Navigator.pop(ctx);
              AppFeedback.success(
                context,
                isVip
                    ? '¡Bienvenido a la membresía VIP!'
                    : 'Inscripción registrada con éxito.',
              );
              Navigator.pop(context);
            },
            child: const Text('Completar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(orgClassesProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.cardBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: context.textOnBg,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Inscripciones',
          style: TextStyle(
            color: context.textOnBg,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: context.textMuted,
          tabs: const [
            Tab(text: 'POR SESIONES'),
            Tab(text: 'PASE VIP ILIMITADO'),
          ],
        ),
      ),
      body: classesAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => Center(
          child: Text('Error: $e', style: TextStyle(color: context.textMuted)),
        ),
        data: (classes) {
          if (classes.isEmpty) {
            return Center(
              child: Text(
                'No hay clases disponibles para inscribirse.',
                style: TextStyle(color: context.textMuted),
              ),
            );
          }

          // ── VALIDACIÓN SEGURA DEL DROPDOWN ──
          // Evita error si vino el ID de la organización o un ID no existente
          final exists = classes.any((c) => c.id == _selectedClassId);
          if (!exists) {
            _selectedClassId = classes.first.id;
          }

          final currentClass = classes.firstWhere(
            (c) => c.id == _selectedClassId,
            orElse: () => classes.first,
          );

          return TabBarView(
            controller: _tabCtrl,
            children: [
              // ── PESTAÑA 1: TODAS LAS CLASES Y PAQUETES DE SESIONES ──
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '1. Selecciona tu Clase',
                      style: TextStyle(
                        color: context.textOnBg,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: context.cardBg,
                        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                        border: Border.all(color: context.divider),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedClassId,
                          isExpanded: true,
                          dropdownColor: context.cardBg,
                          style: TextStyle(color: context.textOnBg, fontSize: 14),
                          items: classes.map((c) {
                            return DropdownMenuItem(
                              value: c.id,
                              child: Text('${c.title} (${c.price.toInt()} BOB)'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedClassId = val);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      '2. Paquete de Sesiones',
                      style: TextStyle(
                        color: context.textOnBg,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _PackCard(
                            title: '8 Clases',
                            subtitle: '2 veces por semana',
                            price: (currentClass.price * 0.8).toInt(),
                            isSelected: _selectedPackSessions == 8,
                            onTap: () => setState(() => _selectedPackSessions = 8),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PackCard(
                            title: '12 Clases',
                            subtitle: '3 veces por semana',
                            price: currentClass.price.toInt(),
                            isSelected: _selectedPackSessions == 12,
                            onTap: () => setState(() => _selectedPackSessions = 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Resumen
                    Card(
                      color: context.cardBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                        side: BorderSide(color: context.divider),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _SummaryRow(
                              label: 'Clase',
                              value: currentClass.title,
                            ),
                            _SummaryRow(
                              label: 'Sesiones incluidas',
                              value: '$_selectedPackSessions clases',
                            ),
                            _SummaryRow(label: 'Vigencia', value: '30 días'),
                            const Divider(height: 20),
                            _SummaryRow(
                              label: 'Total',
                              value:
                                  '${_selectedPackSessions == 8 ? (currentClass.price * 0.8).toInt() : currentClass.price.toInt()} BOB',
                              isBold: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    AppButton(
                      label: 'Inscribirme ahora',
                      onPressed: () => _confirmEnrollment(
                        isVip: false,
                        price: _selectedPackSessions == 8
                            ? currentClass.price * 0.8
                            : currentClass.price,
                      ),
                    ),
                  ],
                ),
              ),

              // ── PESTAÑA 2: MEMBRESÍA VIP DIRECTA ──
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withValues(alpha: 0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'PASE VIP ALL-ACCESS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black26,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'ILIMITADO',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '350 BOB / mes',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Entrena todos los días en cualquier disciplina',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      'Lo que incluye tu membresía VIP:',
                      style: TextStyle(
                        color: context.textOnBg,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const _VipBenefitItem(
                      icon: Icons.all_inclusive,
                      title: 'Sesiones ilimitadas',
                      desc: 'Acceso a todas las clases de la academia.',
                    ),
                    const _VipBenefitItem(
                      icon: Icons.qr_code_rounded,
                      title: 'Check-in Preferencial',
                      desc:
                          'Acceso rápido con escáner QR sin límite de asistencias al día.',
                    ),
                    const _VipBenefitItem(
                      icon: Icons.stars_rounded,
                      title: 'Talleres y Eventos VIP',
                      desc:
                          'Descuentos exclusivos y reporte de asistencia VIP mensual.',
                    ),
                    const SizedBox(height: 24),

                    AppButton(
                      label: 'Obtener Pase VIP Ilimitado',
                      onPressed: () => _confirmEnrollment(
                        isVip: true,
                        price: 350.0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PackCard extends StatelessWidget {
  const _PackCard({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final int price;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isSelected
          ? AppColors.primary.withValues(alpha: 0.1)
          : context.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        side: BorderSide(
          color: isSelected ? AppColors.primary : context.divider,
          width: isSelected ? 1.8 : 1.0,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? AppColors.primary : context.textOnBg,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(color: context.textMuted, fontSize: 11),
              ),
              const SizedBox(height: 10),
              Text(
                '$price BOB',
                style: TextStyle(
                  color: context.textOnBg,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  final String label;
  final String value;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: context.textMuted, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              color: isBold ? AppColors.primary : context.textOnBg,
              fontSize: isBold ? 16 : 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _VipBenefitItem extends StatelessWidget {
  const _VipBenefitItem({
    required this.icon,
    required this.title,
    required this.desc,
  });

  final IconData icon;
  final String title;
  final String desc;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.textOnBg,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(color: context.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}