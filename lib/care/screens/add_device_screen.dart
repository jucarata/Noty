import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:noty/care/services/care_service.dart';
import 'package:noty/core/theme/app_colors.dart';

enum _AddDevicePhase { scanning, naming, done }

class AddDeviceScreen extends StatefulWidget {
  const AddDeviceScreen({super.key, this.careService});

  final CareService? careService;

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  late final CareService _care;
  late final MobileScannerController _scanner;
  late final TextEditingController _nameController;
  late final FocusNode _nameFocus;

  var _phase = _AddDevicePhase.scanning;
  var _busy = false;
  String? _pendingPayload;
  String _chosenName = '';

  @override
  void initState() {
    super.initState();
    _care = widget.careService ?? CareService();
    _nameController = TextEditingController();
    _nameFocus = FocusNode();
    _scanner = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: const [BarcodeFormat.qrCode],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    unawaited(_scanner.dispose());
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy || _phase != _AddDevicePhase.scanning) {
      return;
    }

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) {
      return;
    }
    final payload = barcodes.first.rawValue;
    if (payload == null || payload.isEmpty) {
      return;
    }

    setState(() => _busy = true);
    await _scanner.stop();

    try {
      await _care.validateSharePayload(payload);
      if (!mounted) {
        return;
      }
      setState(() {
        _pendingPayload = payload;
        _phase = _AddDevicePhase.naming;
        _busy = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _nameFocus.requestFocus();
        }
      });
    } on CareFailure catch (error) {
      await _resumeAfterError(error.message);
    } catch (_) {
      await _resumeAfterError(
        'No pudimos leer el código. Intentémoslo de nuevo.',
      );
    }
  }

  Future<void> _backToScanner() async {
    if (_busy) {
      return;
    }
    _nameController.clear();
    _pendingPayload = null;
    setState(() => _phase = _AddDevicePhase.scanning);
    try {
      await _scanner.start();
    } catch (_) {
      // errorBuilder de MobileScanner mostrará el fallo de cámara.
    }
  }

  Future<void> _submitName() async {
    final payload = _pendingPayload;
    if (_busy || payload == null) {
      return;
    }

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Ponle un nombre a este teléfono para reconocerlo en tu familia.',
            ),
          ),
        );
      return;
    }

    setState(() => _busy = true);
    try {
      await _care.addDeviceFromSharePayload(payload, customName: name);
      if (!mounted) {
        return;
      }
      setState(() {
        _chosenName = name;
        _phase = _AddDevicePhase.done;
        _busy = false;
      });
    } on CareFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'No pudimos vincular el dispositivo. Intentémoslo de nuevo.',
            ),
          ),
        );
    }
  }

  Future<void> _resumeAfterError(String message) async {
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
    try {
      await _scanner.start();
    } catch (_) {
      // errorBuilder de MobileScanner mostrará el fallo de cámara.
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _phase != _AddDevicePhase.naming,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          unawaited(_backToScanner());
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: AppColors.azulNoty,
          title: Text(
            _phase == _AddDevicePhase.naming
                ? 'Nombre del teléfono'
                : 'Añadir miembro familiar',
          ),
        ),
        body: SafeArea(child: _body(context)),
      ),
    );
  }

  Widget _body(BuildContext context) {
    return switch (_phase) {
      _AddDevicePhase.scanning => _scannerBody(context),
      _AddDevicePhase.naming => _nameForm(context),
      _AddDevicePhase.done => _success(context),
    };
  }

  Widget _scannerBody(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _scanner,
          onDetect: _onDetect,
          errorBuilder: _cameraError,
          placeholderBuilder: (context) {
            return const Center(child: CircularProgressIndicator());
          },
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.blanco,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.grisClaro),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Text(
                  'Escanea el código de vinculación de tu familiar para acompañarlo.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(color: AppColors.grisMedio),
                ),
              ),
            ),
          ),
        ),
        if (_busy)
          const ColoredBox(
            color: Color(0x66000000),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _cameraError(BuildContext context, MobileScannerException error) {
    final message = switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied =>
        'Necesitamos la cámara para leer el código. Actívala en los ajustes del teléfono.',
      MobileScannerErrorCode.unsupported =>
        'Este dispositivo no puede leer códigos. Prueba en un teléfono.',
      _ => 'No pudimos abrir la cámara. Intentémoslo de nuevo.',
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: AppColors.grisMedio),
          ),
        ),
      ),
    );
  }

  Widget _nameForm(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '¿Cómo quieres llamar a este teléfono?',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Así lo reconocerás cuando le envíes recordatorios.',
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(color: AppColors.grisMedio),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _nameController,
                  focusNode: _nameFocus,
                  enabled: !_busy,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  autofocus: true,
                  maxLength: 60,
                  onSubmitted: (_) => unawaited(_submitName()),
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    hintText: 'Ej. Celular de la abuela',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: _busy ? null : () => unawaited(_submitName()),
                  child: const Text('Añadir a mi familia'),
                ),
                if (_busy) ...[
                  const SizedBox(height: 16),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _success(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.verde,
              size: 72,
            ),
            const SizedBox(height: 24),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(
                '¡Listo! Añadiste a $_chosenName.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(
                'Ya puedes enviarle recordatorios.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: AppColors.grisMedio),
              ),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Listo'),
            ),
          ],
        ),
      ),
    );
  }
}
