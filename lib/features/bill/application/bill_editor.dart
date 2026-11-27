import 'package:fixer/core/clock.dart';
import 'package:fixer/core/ids.dart';
import 'package:fixer/core/money/currency.dart';
import 'package:fixer/core/money/money.dart';
import 'package:fixer/features/bill/domain/bill.dart';
import 'package:fixer/features/bill/domain/bill_calculation.dart';
import 'package:fixer/features/bill/domain/bill_calculator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The bill currently being edited on the Split tab.
final billEditorProvider = NotifierProvider<BillEditor, Bill>(BillEditor.new);

final billCalculatorProvider = Provider<BillCalculator>(
  (ref) => const BillCalculator(),
);

/// Live results, recomputed whenever the bill changes.
final billCalculationProvider = Provider<BillCalculation>(
  (ref) => ref
      .watch(billCalculatorProvider)
      .calculate(ref.watch(billEditorProvider)),
);

/// Editing commands for the current bill. State is always a valid [Bill].
class BillEditor extends Notifier<Bill> {
  String _newId() => ref.read(idGeneratorProvider)();
  DateTime _now() => ref.read(clockProvider)();

  @override
  Bill build() => Bill(
    id: _newId(),
    currency: Currency.defaultCurrency,
    people: const [],
    createdAt: _now(),
  );

  void reset() => state = build();

  /// Continue editing a saved bill.
  void open(Bill bill) => state = bill;

  /// Start a new bill with the same people, items, fees and tags.
  /// Every id is new so the copy is saved as a separate bill.
  void duplicate(Bill bill) {
    state = bill.copyWith(
      id: _newId(),
      createdAt: _now,
      people: [
        for (final p in bill.people)
          p.copyWith(
            id: _newId(),
            items: [for (final i in p.items) i.copyWith(id: _newId())],
          ),
      ],
    );
  }

  void toggleTag(String tagId) {
    final tags = {...state.tagIds};
    if (!tags.remove(tagId)) tags.add(tagId);
    state = state.copyWith(tagIds: tags);
  }

  void setTitle(String title) {
    final trimmed = title.trim();
    state = state.copyWith(title: () => trimmed.isEmpty ? null : trimmed);
  }

  bool get canChangeCurrency => state.hasNoAmounts;

  void setCurrency(Currency currency) {
    if (!canChangeCurrency) {
      throw StateError('Currency can only change before amounts are entered');
    }
    state = state.copyWith(
      currency: currency,
      people: [
        for (final p in state.people)
          p.copyWith(
            items: [
              for (final i in p.items)
                i.copyWith(price: Money(i.price.minorUnits, currency)),
            ],
          ),
      ],
    );
  }

  // People ------------------------------------------------------------------

  /// Adds a person and returns their id. [phone] and [contactId] are set when
  /// the person comes from the phone's contacts.
  String addPerson(String name, {String? phone, String? contactId}) {
    final person = Person(
      id: _newId(),
      name: _validName(name),
      phone: phone,
      contactId: contactId,
    );
    state = state.copyWith(people: [...state.people, person]);
    return person.id;
  }

  void renamePerson(String personId, String name) {
    final valid = _validName(name);
    _updatePerson(personId, (p) => p.copyWith(name: valid));
  }

  /// Removes a person and returns a callback that puts them back in place.
  void Function() removePerson(String personId) {
    final index = state.people.indexWhere((p) => p.id == personId);
    if (index < 0) return () {};
    final removed = state.people[index];
    state = state.copyWith(people: [...state.people]..removeAt(index));
    return () {
      final people = [...state.people];
      people.insert(index.clamp(0, people.length), removed);
      state = state.copyWith(people: people);
    };
  }

  /// Marks [personId] as "Me" (clearing anyone else), or clears it if they
  /// already were.
  void toggleMe(String personId) {
    state = state.copyWith(
      people: [
        for (final p in state.people)
          p.copyWith(isMe: p.id == personId && !p.isMe),
      ],
    );
  }

  // Items -------------------------------------------------------------------

  /// Adds an item to a person and returns the item id.
  String addItem(String personId, Money price, {String? description}) {
    final item = BillItem(
      id: _newId(),
      price: price,
      description: _cleanDescription(description),
    );
    _updatePerson(personId, (p) => p.copyWith(items: [...p.items, item]));
    return item.id;
  }

  void updateItem(
    String personId,
    String itemId, {
    Money? price,
    String? description,
  }) {
    _updatePerson(
      personId,
      (p) => p.copyWith(
        items: [
          for (final i in p.items)
            if (i.id == itemId)
              i.copyWith(
                price: price,
                // null = keep the current description; '' clears it.
                description: description == null
                    ? null
                    : () => _cleanDescription(description),
              )
            else
              i,
        ],
      ),
    );
  }

  void removeItem(String personId, String itemId) {
    _updatePerson(
      personId,
      (p) => p.copyWith(items: p.items.where((i) => i.id != itemId).toList()),
    );
  }

  // Adjustments -------------------------------------------------------------

  void setServiceFee(Money value) => state = state.copyWith(serviceFee: value);
  void setDeliveryFee(Money value) =>
      state = state.copyWith(deliveryFee: value);
  void setDiscount(Money value) => state = state.copyWith(discount: value);

  // Helpers -----------------------------------------------------------------

  void _updatePerson(String personId, Person Function(Person) change) {
    state = state.copyWith(
      people: [for (final p in state.people) p.id == personId ? change(p) : p],
    );
  }

  static String _validName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(name, 'name', 'is blank');
    return trimmed;
  }

  static String? _cleanDescription(String? description) {
    final trimmed = description?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}
