import 'dart:async';

import 'package:flutter/material.dart';
import 'package:noty/care/models/device_share_code.dart';
import 'package:noty/care/models/linked_device.dart';
import 'package:noty/care/screens/add_device_screen.dart';
import 'package:noty/care/services/care_service.dart';
import 'package:noty/core/theme/app_colors.dart';
import 'package:noty/devices/widgets/linked_device_card.dart';

/// Lista de dispositivos vinculados a quien cuida. Solo con cuenta real.
class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key, this.careService, this.isSelected = true});

  final CareService? careService;
  final bool isSelected;

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  late final CareService _care;

  var _loading = true;
  List<LinkedDevice> _devices = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _care = widget.careService ?? CareService();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant DevicesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final showSpinner = _devices.isEmpty && _error == null;
    if (showSpinner) {
      setState(() => _loading = true);
    }

    try {
      final devices = await _care.listLinkedDevices();
      if (!mounted) {
        return;
      }
      setState(() {
        _devices = devices;
        _error = null;
        _loading = false;
      });
    } on CareFailure catch (error) {
      _fail(error.message);
    } catch (_) {
      _fail('No pudimos cargar tus dispositivos. Intentémoslo de nuevo.');
    }
  }

  void _fail(String message) {
    if (!mounted) {
      return;
    }

    setState(() {
      _loading = false;
      if (_devices.isEmpty) {
        _error = message;
      }
    });

    if (_devices.isEmpty) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openAddDevice() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AddDeviceScreen(careService: _care),
      ),
    );
    if (mounted) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dispositivos',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Las personas que acompañas desde Noty.',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: AppColors.grisMedio),
              ),
              const SizedBox(height: 24),
              Expanded(child: _body(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _message(
        context,
        text: _error!,
        actionLabel: 'Intentar de nuevo',
        onAction: _load,
      );
    }

    if (_devices.isEmpty) {
      return _message(
        context,
        text: 'Todavía no hay dispositivos vinculados. Cuando alguien muestre su código, puedes añadirlo aquí.',
        actionLabel: 'Añadir un dispositivo',
        onAction: _openAddDevice,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: _devices.length + 1,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          if (index == _devices.length) {
            return OutlinedButton(
              onPressed: _openAddDevice,
              child: const Text('Añadir un dispositivo'),
            );
          }

          final device = _devices[index];
          return LinkedDeviceCard(
            key: ValueKey(device.id),
            customName: device.displayName,
            brandModel: device.brandModel,
            lastSeenLabel: device.lastSeenLabel,
          );
        },
      ),
    );
  }

  Widget _message(
    BuildContext context, {
    required String text,
    required String actionLabel,
    required VoidCallback onAction,
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
            const SizedBox(height: 24),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
