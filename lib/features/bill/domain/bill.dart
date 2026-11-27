import 'package:fixer/core/money/currency.dart';
import 'package:fixer/core/money/money.dart';

/// One priced line on a person's order. Description is optional.
class BillItem {
  BillItem({required this.id, required this.price, this.description}) {
    if (price.isNegative) {
      throw ArgumentError.value(price, 'price', 'must not be negative');
    }
  }

  final String id;
  final String? description;
  final Money price;

  BillItem copyWith({
    String? id,
    Money? price,
    String? Function()? description,
  }) => BillItem(
    id: id ?? this.id,
    price: price ?? this.price,
    description: description != null ? description() : this.description,
  );
}

/// Someone sharing the bill. [isMe] marks the app owner for reports.
/// [phone] and [contactId] are set when the person was picked from contacts.
class Person {
  Person({
    required this.id,
    required this.name,
    this.isMe = false,
    this.phone,
    this.contactId,
    List<BillItem> items = const [],
  }) : items = List.unmodifiable(items);

  final String id;
  final String name;
  final bool isMe;
  final String? phone;
  final String? contactId;
  final List<BillItem> items;

  Person copyWith({
    String? id,
    String? name,
    bool? isMe,
    List<BillItem>? items,
  }) => Person(
    id: id ?? this.id,
    name: name ?? this.name,
    isMe: isMe ?? this.isMe,
    phone: phone,
    contactId: contactId,
    items: items ?? this.items,
  );
}

/// A label for grouping bills (Food, Electronics, ...). A bill can have
/// several.
class Tag {
  const Tag({required this.id, required this.name});

  final String id;
  final String name;
}

/// The source data for one bill. Totals are derived by `BillCalculator`,
/// never stored here.
class Bill {
  Bill({
    required this.id,
    required this.currency,
    required List<Person> people,
    this.title,
    this.createdAt,
    Set<String> tagIds = const {},
    Money? serviceFee,
    Money? deliveryFee,
    Money? discount,
  }) : people = List.unmodifiable(people),
       tagIds = Set.unmodifiable(tagIds),
       serviceFee = serviceFee ?? Money.zero(currency),
       deliveryFee = deliveryFee ?? Money.zero(currency),
       discount = discount ?? Money.zero(currency) {
    _checkAdjustment(this.serviceFee, 'serviceFee');
    _checkAdjustment(this.deliveryFee, 'deliveryFee');
    _checkAdjustment(this.discount, 'discount');
    for (final person in this.people) {
      for (final item in person.items) {
        if (item.price.currency.code != currency.code) {
          throw ArgumentError(
            'Item ${item.id} is in ${item.price.currency.code}, '
            'bill is in ${currency.code}',
          );
        }
      }
    }
    if (this.people.where((p) => p.isMe).length > 1) {
      throw ArgumentError('Only one person can be marked as Me');
    }
  }

  final String id;
  final String? title;
  final Currency currency;
  final List<Person> people;
  final Money serviceFee;
  final Money deliveryFee;
  final Money discount;

  /// When the bill was first saved; null for a bill never saved.
  final DateTime? createdAt;

  final Set<String> tagIds;

  /// Nullable fields ([title], [createdAt]) take a function so they can be
  /// set to null.
  Bill copyWith({
    String? id,
    Currency? currency,
    List<Person>? people,
    String? Function()? title,
    DateTime? Function()? createdAt,
    Set<String>? tagIds,
    Money? serviceFee,
    Money? deliveryFee,
    Money? discount,
  }) {
    final newCurrency = currency ?? this.currency;
    Money keep(Money m) => currency == null ? m : Money(m.minorUnits, currency);
    return Bill(
      id: id ?? this.id,
      currency: newCurrency,
      people: people ?? this.people,
      title: title != null ? title() : this.title,
      createdAt: createdAt != null ? createdAt() : this.createdAt,
      tagIds: tagIds ?? this.tagIds,
      serviceFee: serviceFee ?? keep(this.serviceFee),
      deliveryFee: deliveryFee ?? keep(this.deliveryFee),
      discount: discount ?? keep(this.discount),
    );
  }

  /// True when no item, fee or discount has a non-zero amount.
  bool get hasNoAmounts =>
      serviceFee.isZero &&
      deliveryFee.isZero &&
      discount.isZero &&
      people.every((p) => p.items.every((i) => i.price.isZero));

  /// Worth keeping in history: someone has at least one priced item.
  bool get hasItems => people.any((p) => p.items.isNotEmpty);

  Person? get me {
    for (final p in people) {
      if (p.isMe) return p;
    }
    return null;
  }

  void _checkAdjustment(Money value, String name) {
    if (value.isNegative) {
      throw ArgumentError.value(value, name, 'must not be negative');
    }
    if (value.currency.code != currency.code) {
      throw ArgumentError.value(value, name, 'must be in ${currency.code}');
    }
  }
}
