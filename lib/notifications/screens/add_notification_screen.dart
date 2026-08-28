import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:noty/care/models/device_share_code.dart';
import 'package:noty/care/models/linked_device.dart';
import 'package:noty/care/services/care_service.dart';
import 'package:noty/core/theme/app_colors.dart';
import 'package:noty/notifications/widgets/notification_device_tile.dart';

enum _RepeatMode { once, everyDay, weekdays }

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
  final _runDaysController = TextEditingController();

  late final CareService _care;

  var _step = 1;
  TimeOfDay? _time;
  var _timeZoneId = _TimeZoneOption.defaultId;
  var _startDate = DateUtils.dateOnly(DateTime.now());
  var _repeatMode = _RepeatMode.once;
  var _neverEnds = false;
  final _selectedWeekdays = {..._WeekdayOption.ids};

  var _loadingDevices = false;
  List<LinkedDevice> _devices = const [];
  String? _devicesError;
  final _selectedDeviceIds = <String>{};

  bool get _hasValidRunDays {
    final days = int.tryParse(_runDaysController.text.trim());
    return days != null && days > 0;
  }

  bool get _repeats => _repeatMode != _RepeatMode.once;

  bool get _hasDurationIfNeeded {
    return !_repeats || _neverEnds || _hasValidRunDays;
  }

  bool get _hasWeekdaysIfNeeded {
    return _repeatMode != _RepeatMode.weekdays || _selectedWeekdays.isNotEmpty;
  }

  bool get _canContinue {
    return _nameController.text.trim().isNotEmpty &&
        _time != null &&
        _hasDurationIfNeeded &&
        _hasWeekdaysIfNeeded;
  }

  bool get _canSave => _selectedDeviceIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _care = widget.careService ?? CareService();
    _nameController.addListener(_onFieldsChanged);
    _runDaysController.addListener(_onFieldsChanged);
  }

  @override
  void dispose() {
    _nameController.removeListener(_onFieldsChanged);
    _runDaysController.removeListener(_onFieldsChanged);
    _nameController.dispose();
    _descriptionController.dispose();
    _runDaysController.dispose();
    super.dispose();
  }

  void _onFieldsChanged() {
    setState(() {});
  }

  void _selectRepeatMode(_RepeatMode mode) {
    if (_repeatMode == mode) {
      return;
    }
    setState(() => _repeatMode = mode);
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

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate.isBefore(today) ? today : _startDate,
      firstDate: today,
      lastDate: DateTime(today.year + 5),
      helpText: 'Elige el día de inicio',
      cancelText: 'Cancelar',
      confirmText: 'Listo',
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _startDate = DateUtils.dateOnly(picked));
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
          'El nombre y la hora son necesarios. Si se repite, también cuánto durará.',
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: AppColors.grisMedio),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            label: _RequiredLabel('Nombre'),
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
        _DateField(date: _startDate, onTap: _pickDate),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _timeZoneId,
          isExpanded: true,
          decoration: const InputDecoration(
            label: _RequiredLabel('Zona horaria'),
          ),
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
        const SizedBox(height: 16),
        _CheckRow(
          label: 'Solo una vez',
          helper: 'Sonará el día de inicio, a esa hora.',
          value: _repeatMode == _RepeatMode.once,
          onChanged: (selected) {
            if (selected) {
              _selectRepeatMode(_RepeatMode.once);
            }
          },
        ),
        const SizedBox(height: 16),
        _CheckRow(
          label: 'Todos los días',
          helper: 'Sonará cada día a la hora elegida.',
          value: _repeatMode == _RepeatMode.everyDay,
          onChanged: (selected) {
            if (selected) {
              _selectRepeatMode(_RepeatMode.everyDay);
            }
          },
        ),
        const SizedBox(height: 16),
        _CheckRow(
          label: 'Elegir los días',
          helper: 'Sonará solo los días que marques.',
          value: _repeatMode == _RepeatMode.weekdays,
          onChanged: (selected) {
            if (selected) {
              _selectRepeatMode(_RepeatMode.weekdays);
            }
          },
        ),
        if (_repeatMode == _RepeatMode.weekdays) ...[
          const SizedBox(height: 12),
          _WeekdayPicker(
            selectedIds: _selectedWeekdays,
            onChanged: (id, selected) {
              setState(() {
                if (selected) {
                  _selectedWeekdays.add(id);
                } else {
                  _selectedWeekdays.remove(id);
                }
              });
            },
          ),
        ],
        if (_repeats) ...[
          const SizedBox(height: 16),
          _DurationChoice(
            daysController: _runDaysController,
            neverEnds: _neverEnds,
            onNeverEndsChanged: (value) => setState(() => _neverEnds = value),
          ),
        ],
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

class _DurationChoice extends StatelessWidget {
  const _DurationChoice({
    required this.daysController,
    required this.neverEnds,
    required this.onNeverEndsChanged,
  });

  final TextEditingController daysController;
  final bool neverEnds;
  final ValueChanged<bool> onNeverEndsChanged;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: daysController,
              enabled: !neverEnds,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                label: const _RequiredLabel('Días de ejecución'),
                hintText: 'Ej. 7',
                fillColor: neverEnds ? AppColors.grisClaro : AppColors.blanco,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: _NeverEndsCard(
              value: neverEnds,
              onChanged: onNeverEndsChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _NeverEndsCard extends StatelessWidget {
  const _NeverEndsCard({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: value,
      label: 'Nunca termina',
      child: Material(
        color: AppColors.blanco,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: value ? AppColors.azulMedio : AppColors.grisClaro,
                width: value ? 2 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(left: 12, right: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Nunca termina',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Checkbox(
                    value: value,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    onChanged: (selected) => onChanged(selected ?? false),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WeekdayOption {
  const _WeekdayOption(this.id, this.label);

  final int id;
  final String label;

  static const all = [
    _WeekdayOption(DateTime.monday, 'Lunes'),
    _WeekdayOption(DateTime.tuesday, 'Martes'),
    _WeekdayOption(DateTime.wednesday, 'Miércoles'),
    _WeekdayOption(DateTime.thursday, 'Jueves'),
    _WeekdayOption(DateTime.friday, 'Viernes'),
    _WeekdayOption(DateTime.saturday, 'Sábado'),
    _WeekdayOption(DateTime.sunday, 'Domingo'),
  ];

  static Set<int> get ids => {for (final day in all) day.id};
}

class _WeekdayPicker extends StatelessWidget {
  const _WeekdayPicker({required this.selectedIds, required this.onChanged});

  final Set<int> selectedIds;
  final void Function(int id, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < _WeekdayOption.all.length; index += 2) ...[
          if (index > 0) const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _chip(index)),
              const SizedBox(width: 8),
              Expanded(
                child: index + 1 < _WeekdayOption.all.length
                    ? _chip(index + 1)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _chip(int index) {
    final day = _WeekdayOption.all[index];
    final selected = selectedIds.contains(day.id);

    return Material(
      color: AppColors.blanco,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => onChanged(day.id, !selected),
        borderRadius: BorderRadius.circular(16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.azulMedio : AppColors.grisClaro,
              width: selected ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(left: 12, right: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    day.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Checkbox(
                  value: selected,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  onChanged: (value) => onChanged(day.id, value ?? false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.label,
    this.helper,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String? helper;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: AppColors.blanco,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: value ? AppColors.azulMedio : AppColors.grisClaro,
              width: value ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: theme.textTheme.titleMedium),
                      if (helper != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          helper!,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: AppColors.grisMedio,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Checkbox(
                  value: value,
                  onChanged: (selected) => onChanged(selected ?? false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RequiredLabel extends StatelessWidget {
  const _RequiredLabel(this.text);

  final String text;

  static const _asterisk = TextStyle(
    color: Color(0xFFDC2626),
    fontWeight: FontWeight.w700,
  );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$text, obligatorio',
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          text: text,
          children: const [TextSpan(text: ' *', style: _asterisk)],
        ),
      ),
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
          label: _RequiredLabel('Hora'),
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

class _DateField extends StatelessWidget {
  const _DateField({required this.date, required this.onTap});

  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: const InputDecoration(
          label: _RequiredLabel('Fecha de inicio'),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          suffixIcon: Icon(Icons.calendar_today_rounded),
        ),
        child: Text(
          _formatDate(date),
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: AppColors.grisOscuro),
        ),
      ),
    );
  }

  static const _months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  static String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = DateTime(date.year, date.month, date.day);
    final month = _months[picked.month - 1];

    if (picked == today) {
      return 'Hoy, ${picked.day} de $month';
    }
    if (picked == today.add(const Duration(days: 1))) {
      return 'Mañana, ${picked.day} de $month';
    }
    if (picked.year == now.year) {
      return '${picked.day} de $month';
    }
    return '${picked.day} de $month de ${picked.year}';
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
