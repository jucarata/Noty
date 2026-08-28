import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:noty/care/models/device_share_code.dart';
import 'package:noty/care/services/care_service.dart';
import 'package:noty/core/theme/app_colors.dart';

class AddDeviceScreen extends StatefulWidget {
  const AddDeviceScreen({super.key, this.careService});

  final CareService? careService;

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  late final CareService _care;
  late final MobileScannerController _scanner;

  var _busy = false;
  var _done = false;

  @override
  void initState() {
    super.initState();
    _care = widget.careService ?? CareService();
    _scanner = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: const [BarcodeFormat.qrCode],
    );
  }

  @override
  void dispose() {
    unawaited(_scanner.dispose());
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy || _done) {
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
      await _care.addDeviceFromSharePayload(payload);
      if (!mounted) {
        return;
      }
      setState(() {
        _done = true;
        _busy = false;
      });
    } on CareFailure catch (error) {
      await _resumeAfterError(error.message);
    } catch (_) {
      await _resumeAfterError(
        'No pudimos vincular el dispositivo. Intentémoslo de nuevo.',
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.azulNoty,
        title: const Text('Añadir miembro familiar'),
      ),
      body: SafeArea(child: _done ? _success(context) : _scannerBody(context)),
    );
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
      MobileScannerErrorCode.permissionDenied => 'Necesitamos la cámara para leer el código. Actívala en los ajustes del teléfono.',
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
                '¡Listo! Ya añadiste a este familiar.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(
                'Quedó unido a tu familia. Ya puedes enviarle recordatorios.',
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
