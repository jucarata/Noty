import 'dart:async';

import 'package:flutter/material.dart';
import 'package:noty/care/models/linked_device.dart';
import 'package:noty/care/screens/add_device_screen.dart';
import 'package:noty/care/services/care_service.dart';
import 'package:noty/core/theme/app_colors.dart';
import 'package:noty/family/widgets/family_member_card.dart';
import 'package:noty/notifications/services/notificator.dart';

/// Familiares acompañados vinculados a quien cuida. Solo con cuenta real.
class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key, this.careService, this.isSelected = true});

  final CareService? careService;
  final bool isSelected;

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  late final CareService _care;

  var _loading = true;
  List<LinkedDevice> _members = const [];
  String? _error;
  String? _unlinkingId;

  @override
  void initState() {
    super.initState();
    _care = widget.careService ?? CareService();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant FamilyScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final showSpinner = _members.isEmpty && _error == null;
    if (showSpinner) {
      setState(() => _loading = true);
    }

    try {
      final members = await _care.listFamilyMembers();
      if (!mounted) {
        return;
      }
      setState(() {
        _members = members;
        _error = null;
        _loading = false;
        _unlinkingId = null;
      });
    } on CareFailure catch (error) {
      _fail(error.message);
    } catch (_) {
      _fail('No pudimos cargar tu familia. Intentémoslo de nuevo.');
    }
  }

  void _fail(String message) {
    if (!mounted) {
      return;
    }

    setState(() {
      _loading = false;
      _unlinkingId = null;
      if (_members.isEmpty) {
        _error = message;
      }
    });

    if (_members.isEmpty) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmUnlink(LinkedDevice member) async {
    if (_unlinkingId != null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('¿Desvincular a ${member.displayName}?'),
          content: const Text(
            'Dejará de estar en tu familia y ya no le llegarán los '
            'recordatorios que le enviaste. Si más adelante usa otro teléfono, '
            'puedes volver a añadirlo con su código.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
              ),
              child: const Text('Desvincular'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _unlinkingId = member.id);
    try {
      await _care.unlinkFamilyDevice(member.id);
      try {
        await Notificator.instance.refresh();
      } catch (_) {
        // La lista de familia ya se actualiza; las alarmas se alinean al sync.
      }
      if (!mounted) {
        return;
      }
      await _load();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Listo. ${member.displayName} ya no está en tu familia.',
            ),
          ),
        );
    } on CareFailure catch (error) {
      _failUnlink(error.message);
    } catch (_) {
      _failUnlink(
        'No pudimos desvincular este familiar. Intentémoslo de nuevo.',
      );
    }
  }

  void _failUnlink(String message) {
    if (!mounted) {
      return;
    }
    setState(() => _unlinkingId = null);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openAddMember() async {
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Familia',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton.filled(
                    onPressed: _openAddMember,
                    tooltip: 'Añadir miembro familiar',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.azulNoty,
                      foregroundColor: AppColors.blanco,
                      minimumSize: const Size(48, 48),
                    ),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Los familiares a tu cargo y el teléfono con el que los acompañas.',
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

    if (_members.isEmpty) {
      return _message(
        context,
        text:
            'Todavía no hay familiares vinculados. Pulsa + para añadir el primero.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: _members.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final member = _members[index];
          return FamilyMemberCard(
            key: ValueKey(member.id),
            name: member.displayName,
            phoneModel: member.brandModel,
            unlinking: _unlinkingId == member.id,
            onUnlink: _unlinkingId == null
                ? () => unawaited(_confirmUnlink(member))
                : null,
          );
        },
      ),
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
}
