import 'dart:async';

import 'package:flutter/material.dart';
import 'package:noty/care/models/device_share_code.dart';
import 'package:noty/care/models/linked_device.dart';
import 'package:noty/care/screens/add_device_screen.dart';
import 'package:noty/care/services/care_service.dart';
import 'package:noty/core/theme/app_colors.dart';
import 'package:noty/family/widgets/family_member_card.dart';

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
              Text(
                'Familia',
                style: Theme.of(context).textTheme.headlineSmall,
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
            'Todavía no hay familiares vinculados. Cuando alguien de tu familia muestre su código, puedes añadirlo aquí.',
        actionLabel: 'Añadir miembro familiar',
        onAction: _openAddMember,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: _members.length + 1,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          if (index == _members.length) {
            return OutlinedButton(
              onPressed: _openAddMember,
              child: const Text('Añadir miembro familiar'),
            );
          }

          final member = _members[index];
          return FamilyMemberCard(
            key: ValueKey(member.id),
            name: member.displayName,
            phoneDescription: member.phoneDescription,
            lastSeenLabel: member.lastSeenLabel,
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
