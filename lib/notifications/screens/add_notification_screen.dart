import 'dart:async';

import 'package:flutter/material.dart';
import 'package:noty/care/models/device_share_code.dart';
import 'package:noty/care/models/linked_device.dart';
import 'package:noty/care/services/care_service.dart';
import 'package:noty/core/theme/app_colors.dart';
import 'package:noty/notifications/widgets/notification_device_tile.dart';

/// Alta visual de un recordatorio, en dos pasos.
class AddNotificationScreen extends StatefulWidget {
  const AddNotificationScreen({super.key, this.careService});

  final CareService? careService;

  @override
  State<AddNotificationScreen> createState() => _AddNotificationScreenState();
}

class _AddNotificationScreenState extends State<AddNotificationScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  late final CareService _care;

  var _step = 1;
  TimeOfDay? _time;
  var _timeZoneId = _TimeZoneOption.defaultId;

  var _loadingDevices = false;
  List<LinkedDevice> _devices = const [];
  String? _devicesError;
  final _selectedDeviceIds = <String>{};

  bool get _canContinue {
    return _nameController.text.trim().isNotEmpty && _time != null;
  }

  bool get _canSave => _selectedDeviceIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _care = widget.careService ?? CareService();
    _nameController.addListener(_onFieldsChanged);
  }

  @override
  void dispose() {
    _nameController.removeListener(_onFieldsChanged);
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onFieldsChanged() {
    setState(() {});
  }

  void _onBack() {
    if (_step == 2) {
      setState(() => _step = 1);
      return;
    }
    Navigator.of(context).pop();
  }

  void _goToStep2() {
    if (!_canContinue) {
      return;
    }
    setState(() => _step = 2);
    unawaited(_loadDevices());
  }

  Future<void> _loadDevices() async {
    setState(() {
      _loadingDevices = true;
      _devicesError = null;
    });

    try {
      final devices = await _care.listFamilyMembers();
      if (!mounted) {
        return;
      }
      setState(() {
        _devices = devices;
        _selectedDeviceIds.removeWhere(
          (id) => devices.every((device) => device.id != id),
        );
        _loadingDevices = false;
      });
    } on CareFailure catch (error) {
      _failDevices(error.message);
    } catch (_) {
      _failDevices(
        'No pudimos cargar los dispositivos. Intentémoslo de nuevo.',
      );
    }
  }

  void _failDevices(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _loadingDevices = false;
      _devicesError = message;
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
      helpText: 'Elige la hora',
      cancelText: 'Cancelar',
      confirmText: 'Listo',
      hourLabelText: 'Hora',
      minuteLabelText: 'Minutos',
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _time = picked);
  }

  void _save() {
    // Visual-only: todavía no se guarda el recordatorio.
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 1,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _onBack();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: AppColors.azulNoty,
          leading: IconButton(
            onPressed: _onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: const Text('Añadir notificación'),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StepProgress(step: _step),
                const SizedBox(height: 24),
                Expanded(
                  child: _step == 1 ? _stepOne(context) : _stepTwo(context),
                ),
                const SizedBox(height: 16),
                _actions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepOne(BuildContext context) {
    return ListView(
      children: [
        Text(
          '¿Qué hay que recordar?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'El nombre y la hora son necesarios. La descripción, si quieres.',
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: AppColors.grisMedio),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Nombre',
            hintText: 'Ej. Tomar Losartan',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _descriptionController,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.newline,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Descripción (opcional)',
            hintText: 'Ej. Tomar Losartan 500 mg',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 16),
        _TimeField(time: _time, onTap: _pickTime),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _timeZoneId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Zona horaria'),
          items: [
            for (final zone in _TimeZoneOption.all)
              DropdownMenuItem(
                value: zone.id,
                child: Text(zone.label, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (value) {
            if (value == null) {
              return;
            }
            _timeZoneId = value;
          },
        ),
      ],
    );
  }

  Widget _stepTwo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '¿En qué teléfonos sonará?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Marca los dispositivos que recibirán este recordatorio.',
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: AppColors.grisMedio),
        ),
        const SizedBox(height: 24),
        Expanded(child: _devicesBody(context)),
      ],
    );
  }

  Widget _devicesBody(BuildContext context) {
    if (_loadingDevices) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_devicesError != null) {
      return _message(
        context,
        text: _devicesError!,
        actionLabel: 'Intentar de nuevo',
        onAction: _loadDevices,
      );
    }

    if (_devices.isEmpty) {
      return _message(
        context,
        text: 'Todavía no hay dispositivos vinculados. Cuando añadas un familiar, podrás enviarle este recordatorio.',
      );
    }

    return ListView.separated(
      itemCount: _devices.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final device = _devices[index];
        return NotificationDeviceTile(
          key: ValueKey(device.id),
          name: device.displayName,
          phoneDescription: device.phoneDescription,
          selected: _selectedDeviceIds.contains(device.id),
          onChanged: (selected) {
            setState(() {
              if (selected) {
                _selectedDeviceIds.add(device.id);
              } else {
                _selectedDeviceIds.remove(device.id);
              }
            });
          },
        );
      },
    );
  }

  Widget _message(
    BuildContext context, {
    required String text,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: AppColors.grisMedio),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _actions() {
    if (_step == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            onPressed: _canContinue ? _goToStep2 : null,
            child: const Text('Continuar'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _onBack, child: const Text('Volver')),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: _canSave ? _save : null,
          child: const Text('Guardar notificación'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: _onBack, child: const Text('Volver')),
      ],
    );
  }
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Paso $step de 2',
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(color: AppColors.azulNoty),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _bar(active: true)),
            const SizedBox(width: 8),
            Expanded(child: _bar(active: step == 2)),
          ],
        ),
      ],
    );
  }

  Widget _bar({required bool active}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: active ? AppColors.azulNoty : AppColors.grisClaro,
        borderRadius: BorderRadius.circular(99),
      ),
      child: const SizedBox(height: 6),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({required this.time, required this.onTap});

  final TimeOfDay? time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = time == null ? 'Elige la hora' : _formatTime(time!);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Hora',
          floatingLabelBehavior: FloatingLabelBehavior.always,
          suffixIcon: Icon(Icons.schedule_rounded),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: time == null ? AppColors.grisMedio : AppColors.grisOscuro,
          ),
        ),
      ),
    );
  }

  static String _formatTime(TimeOfDay time) {
    var hour = time.hourOfPeriod;
    if (hour == 0) {
      hour = 12;
    }
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'a. m.' : 'p. m.';
    return '$hour:$minute $period';
  }
}

class _TimeZoneOption {
  const _TimeZoneOption(this.id, this.label);

  final String id;
  final String label;

  static const defaultId = 'America/Bogota';

  static const all = [
    _TimeZoneOption('America/Bogota', 'Colombia (Bogotá)'),
    _TimeZoneOption('America/Mexico_City', 'México (Ciudad de México)'),
    _TimeZoneOption('America/Guatemala', 'Guatemala'),
    _TimeZoneOption('America/Costa_Rica', 'Costa Rica'),
    _TimeZoneOption('America/Panama', 'Panamá'),
    _TimeZoneOption('America/Lima', 'Perú (Lima)'),
    _TimeZoneOption('America/Guayaquil', 'Ecuador (Guayaquil)'),
    _TimeZoneOption('America/Caracas', 'Venezuela (Caracas)'),
    _TimeZoneOption('America/Santo_Domingo', 'República Dominicana'),
    _TimeZoneOption('America/Santiago', 'Chile (Santiago)'),
    _TimeZoneOption(
      'America/Argentina/Buenos_Aires',
      'Argentina (Buenos Aires)',
    ),
    _TimeZoneOption('America/Sao_Paulo', 'Brasil (São Paulo)'),
    _TimeZoneOption('America/New_York', 'Este de EE. UU.'),
    _TimeZoneOption('America/Chicago', 'Centro de EE. UU.'),
    _TimeZoneOption('America/Denver', 'Montaña, EE. UU.'),
    _TimeZoneOption('America/Los_Angeles', 'Pacífico, EE. UU.'),
    _TimeZoneOption('Europe/Madrid', 'España (Madrid)'),
    _TimeZoneOption('UTC', 'UTC'),
  ];
}
