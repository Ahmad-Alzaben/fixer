import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A contact chosen from the phone's address book.
class PickedContact {
  const PickedContact({
    required this.id,
    required this.name,
    required this.phones,
  });

  final String id;
  final String name;
  final List<String> phones;
}

class ContactsPermissionDenied implements Exception {
  const ContactsPermissionDenied();
}

/// Lets the user pick one contact (Adapter over the contacts plugin).
abstract interface class ContactsGateway {
  /// Null if the user cancelled. Throws [ContactsPermissionDenied].
  Future<PickedContact?> pick();
}

class DeviceContactsGateway implements ContactsGateway {
  const DeviceContactsGateway();

  @override
  Future<PickedContact?> pick() async {
    final status = await FlutterContacts.permissions.request(
      PermissionType.read,
    );
    if (status != PermissionStatus.granted &&
        status != PermissionStatus.limited) {
      throw const ContactsPermissionDenied();
    }
    final contact = await FlutterContacts.native.showPicker(
      properties: {ContactProperty.name, ContactProperty.phone},
    );
    if (contact == null) return null;
    final phones = [
      for (final p in contact.phones)
        if (p.number.trim().isNotEmpty) p.number.trim(),
    ];
    final name = contact.displayName?.trim() ?? '';
    return PickedContact(
      id: contact.id ?? '',
      name: name.isNotEmpty ? name : (phones.firstOrNull ?? 'Contact'),
      phones: phones,
    );
  }
}

final contactsGatewayProvider = Provider<ContactsGateway>(
  (ref) => const DeviceContactsGateway(),
);
