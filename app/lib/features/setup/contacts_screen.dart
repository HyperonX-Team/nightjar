import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

import '../../core/constants.dart';
import '../../services/secure_store.dart';
import '../../theme/palette.dart';
import '../../theme/theme.dart';
import '../../theme/typography.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key, required this.store});

  final SetupStore store;

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<Contact> _contacts = const <Contact>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final contacts = await widget.store.readContacts();
    if (!mounted) {
      return;
    }
    setState(() {
      _contacts = contacts;
      _loading = false;
    });
  }

  Future<void> _edit({int? index}) async {
    final existing = index == null ? null : _contacts[index];
    final taken = [
      for (var i = 0; i < _contacts.length; i++)
        if (i != index) _contacts[i].phone,
    ];
    final result = await showModalBottomSheet<Contact>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Palette.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (context) => _ContactSheet(
        existing: existing,
        takenPhones: taken,
      ),
    );
    if (result == null) {
      return;
    }
    final next = [..._contacts];
    if (index == null) {
      next.add(result);
    } else {
      next[index] = result;
    }
    await widget.store.writeContacts(next);
    await _load();
  }

  Future<void> _remove(int index) async {
    final contact = _contacts[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove contact?'),
        content: Text(contact.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    final next = [..._contacts]..removeAt(index);
    await widget.store.writeContacts(next);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return SetupScaffold(
      title: 'Contacts',
      children: [
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: LinearProgressIndicator(),
          )
        else ...[
          for (var index = 0; index < ContactRules.required; index++)
            _slot(index),
          const SizedBox(height: 24),
          Text(
            'Your contacts receive a normal text message. Their carrier and '
            'their phone can see it.',
            style: AppTypography.secondary,
          ),
          const SizedBox(height: 12),
          Text(
            'Add all three. If one number is wrong, that person will not get '
            'your alert.',
            style: AppTypography.secondary,
          ),
        ],
      ],
    );
  }

  Widget _slot(int index) {
    final contact = index < _contacts.length ? _contacts[index] : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  '${index + 1}',
                  style: AppTypography.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: contact == null
                    ? const Text('Add contact', style: AppTypography.rowLabel)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(contact.name, style: AppTypography.rowLabel),
                          Text(
                            maskPhone(contact.phone),
                            style: AppTypography.secondary,
                          ),
                        ],
                      ),
              ),
              if (contact == null)
                TextButton(
                  onPressed: () => _edit(),
                  child: const Text('Add'),
                )
              else ...[
                TextButton(
                  onPressed: () => _edit(index: index),
                  child: const Text('Edit'),
                ),
                TextButton(
                  onPressed: () => _remove(index),
                  child: const Text('Remove'),
                ),
              ],
            ],
          ),
        ),
        const LedgerRule(color: Palette.rule),
      ],
    );
  }
}

String maskPhone(String phone) {
  if (phone.length <= 5) {
    return phone;
  }
  final head = phone.substring(0, 3);
  final tail = phone.substring(phone.length - 2);
  return '$head${'\u2022' * (phone.length - 5)}$tail';
}

class ContactValidation {
  const ContactValidation(this.contact, this.error);

  final Contact? contact;
  final String? error;
}

/// Name length and E.164 validation for one slot. A duplicate number in the
/// other slots is rejected (SPEC 11).
ContactValidation validateContact({
  required String name,
  required String rawPhone,
  required List<String> takenPhones,
}) {
  final trimmedName = name.trim();
  final raw = rawPhone.trim();
  if (raw.isEmpty) {
    return const ContactValidation(null, null);
  }
  try {
    final parsed = PhoneNumber.parse(raw);
    if (!parsed.isValid()) {
      return const ContactValidation(
        null,
        'Use the full number with country code.',
      );
    }
    final e164 = parsed.international;
    if (takenPhones.contains(e164)) {
      return const ContactValidation(null, 'That number is already added.');
    }
    if (trimmedName.isEmpty ||
        trimmedName.length > ContactRules.nameMaxLength) {
      return const ContactValidation(null, null);
    }
    return ContactValidation(Contact(name: trimmedName, phone: e164), null);
  } on PhoneNumberException {
    return const ContactValidation(
      null,
      'Use the full number with country code.',
    );
  }
}

class _ContactSheet extends StatefulWidget {
  const _ContactSheet({required this.existing, required this.takenPhones});

  final Contact? existing;
  final List<String> takenPhones;

  @override
  State<_ContactSheet> createState() => _ContactSheetState();
}

class _ContactSheetState extends State<_ContactSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _phone =
      TextEditingController(text: widget.existing?.phone ?? '');

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  ContactValidation get _validation => validateContact(
        name: _name.text,
        rawPhone: _phone.text,
        takenPhones: widget.takenPhones,
      );

  @override
  Widget build(BuildContext context) {
    final validation = _validation;
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: 24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.existing == null ? 'Add contact' : 'Edit contact',
            style: AppTypography.title,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            autofocus: widget.existing == null,
            maxLength: ContactRules.nameMaxLength,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              LengthLimitingTextInputFormatter(ContactRules.nameMaxLength),
            ],
            decoration: const InputDecoration(
              labelText: 'Name',
              counterText: '',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Phone number',
              helperText: 'Use the full number with country code.',
              errorText: validation.error,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: validation.contact == null
                ? null
                : () => Navigator.of(context).pop(validation.contact),
            child: const Text('Save'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
