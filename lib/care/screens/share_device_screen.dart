import 'package:flutter/material.dart';
import 'package:noty/care/models/device_share_code.dart';
import 'package:noty/care/services/care_service.dart';
import 'package:noty/core/theme/app_colors.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ShareDeviceScreen extends StatefulWidget {
  const ShareDeviceScreen({super.key, this.careService});

  final CareService? careService;

  @override
  State<ShareDeviceScreen> createState() => _ShareDeviceScreenState();
}

class _ShareDeviceScreenState extends State<ShareDeviceScreen> {
  late final CareService _care;

  var _loading = true;
  DeviceShareCode? _code;
  String? _error;

  @override
  void initState() {
    super.initState();
    _care = widget.careService ?? CareService();
    _load();
  }

  Future<void> _load() async {
    try {
      final code = await _care.shareThisDevice();
      if (!mounted) {
        return;
      }
      setState(() {
        _code = code;
        _error = null;
        _loading = false;
      });
    } on CareFailure catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('No pudimos preparar el código. Intentémoslo de nuevo.');
    }
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _error = message;
      _loading = false;
    });
  }

  Future<void> _retry() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.azulNoty,
        title: const Text('Compartir este dispositivo'),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _body(context),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) {
      return const CircularProgressIndicator();
    }

    if (_error != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.grisMedio),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _retry, child: const Text('Intentar de nuevo')),
        ],
      );
    }

    final payload = _code?.qrPayload;
    if (payload == null) {
      return const SizedBox.shrink();
    }

    final qrSize = (MediaQuery.sizeOf(context).width - 80).clamp(200.0, 280.0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Text(
            'Que la otra persona escanee este código para enviarte recordatorios.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.grisMedio),
          ),
        ),
        const SizedBox(height: 32),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.blanco,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.grisClaro),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: QrImageView(
              data: payload,
              size: qrSize,
              backgroundColor: AppColors.blanco,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: AppColors.azulNoty,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: AppColors.azulNoty,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
