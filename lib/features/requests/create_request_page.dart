import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/enums.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/lookups.dart';
import '../../models/request.dart';
import '../../services/request_calculator.dart';
import '../../services/request_service.dart';

final _citiesProvider = FutureProvider((ref) => ref.watch(lookupServiceProvider).getCities());
final _governoratesProvider = FutureProvider((ref) => ref.watch(lookupServiceProvider).getGovernorates());

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

class CreateRequestPage extends ConsumerStatefulWidget {
  const CreateRequestPage({super.key});

  @override
  ConsumerState<CreateRequestPage> createState() => _CreateRequestPageState();
}

class _CreateRequestPageState extends ConsumerState<CreateRequestPage> {
  RequestType _requestType = RequestType.fieldVisit;

  Governorate? _firstFromGov;
  City? _firstFromCity;
  Governorate? _firstToGov;
  City? _firstToCity;
  DateTime _firstDateTravel = _today();

  Governorate? _secondFromGov;
  City? _secondFromCity;
  Governorate? _secondToGov;
  City? _secondToCity;
  DateTime _secondDateTravel = _today();

  final List<RequestExtraCost> _extraCosts = [];
  bool _isSubmitting = false;

  /// Any leg pointing at a real city (not "home address") — per business
  /// rule, this locks out the Tickets/Allowance extra-cost types.
  bool get _anyLocationChosen =>
      _firstFromGov != null || _firstToGov != null || _secondFromGov != null || _secondToGov != null;

  /// Tickets/Allowance already added — per business rule, this locks the
  /// trip legs to "home address" (no governorate/city selection).
  bool get _hasTicketsOrAllowance =>
      _extraCosts.any((e) => e.type == ExtraCostType.tickets || e.type == ExtraCostType.allowance);

  Future<void> _pickDate({required bool isFirst}) async {
    final today = _today();
    final picked = await showDatePicker(
      context: context,
      initialDate: isFirst ? _firstDateTravel : _secondDateTravel,
      // Once a month ends, requests for it can no longer be created —
      // only the current calendar month, up to today, is selectable.
      firstDate: DateTime(today.year, today.month, 1),
      lastDate: today,
    );
    if (picked == null) return;
    setState(() {
      if (isFirst) {
        _firstDateTravel = picked;
      } else {
        _secondDateTravel = picked;
      }
    });
  }

  List<ExtraCostType> _allowedExtraTypes(int titleId) {
    final usedTypes = _extraCosts.map((e) => e.type).toSet();
    return ExtraCostType.allowedFor(requestType: _requestType, titleId: titleId).where((t) {
      if (usedTypes.contains(t)) return false; // one of each type per request
      if (_anyLocationChosen && (t == ExtraCostType.tickets || t == ExtraCostType.allowance)) return false;
      return true;
    }).toList();
  }

  void _addExtraCost(List<ExtraCostType> allowedTypes) async {
    final profile = ref.read(myProfileProvider).value;
    final result = await showModalBottomSheet<RequestExtraCost>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddExtraCostSheet(
        allowedTypes: allowedTypes,
        employeeId: profile?.id,
      ),
    );
    if (result != null) {
      setState(() => _extraCosts.add(result));
    }
  }

  Future<void> _previewAndSubmit(Map<int, City> citiesById) async {
    setState(() => _isSubmitting = true);
    final input = NewRequestInput(
      requestType: _requestType,
      firstFromCityId: _firstFromCity?.id,
      firstToCityId: _firstToCity?.id,
      firstDateTravel: _firstDateTravel,
      secondFromCityId: _secondFromCity?.id,
      secondToCityId: _secondToCity?.id,
      secondDateTravel: _secondDateTravel,
      extraCosts: _extraCosts,
    );

    try {
      final preview = await ref.read(requestServiceProvider).previewRequest(input, citiesById);
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => _PreviewDialog(preview: preview),
      );
      if (confirmed == true) {
        final created = await ref.read(requestServiceProvider).submitRequest(input, preview);
        if (!mounted) return;
        ref.invalidate(requestCountsProvider);
        context.pop();
        context.push('/requests/${created.id}');
      }
    } on RequestValidationError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Something went wrong: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final citiesAsync = ref.watch(_citiesProvider);
    final governoratesAsync = ref.watch(_governoratesProvider);
    final profileAsync = ref.watch(myProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('New Expense Request')),
      body: citiesAsync.when(
        data: (cities) {
          return governoratesAsync.when(
            data: (governorates) {
              final citiesById = {for (final c in cities) c.id: c};
              final sortedGovs = [...governorates]..sort((a, b) => a.nameEn.compareTo(b.nameEn));
              final titleId = profileAsync.maybeWhen(data: (p) => p.titleId ?? 0, orElse: () => 0);
              final allowedExtraTypes = _allowedExtraTypes(titleId);
              final legsLocked = _hasTicketsOrAllowance;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text('Request Type', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: RequestType.values.map((t) {
                      final selected = _requestType == t;
                      return ChoiceChip(
                        label: Text(t.label),
                        selected: selected,
                        onSelected: (_) => setState(() => _requestType = t),
                        selectedColor: PharcoColors.orange,
                        labelStyle: TextStyle(color: selected ? Colors.white : PharcoColors.charcoal),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  const Text('Travel Trip', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  _GovernorateCityPicker(
                    label: 'From',
                    governorates: sortedGovs,
                    allCities: cities,
                    enabled: !legsLocked,
                    selectedGovernorate: _firstFromGov,
                    selectedCity: _firstFromCity,
                    onGovernorateChanged: (g) => setState(() {
                      _firstFromGov = g;
                      _firstFromCity = null;
                    }),
                    onCityChanged: (c) => setState(() => _firstFromCity = c),
                  ),
                  const SizedBox(height: 12),
                  _GovernorateCityPicker(
                    label: 'To',
                    governorates: sortedGovs,
                    allCities: cities,
                    enabled: !legsLocked,
                    selectedGovernorate: _firstToGov,
                    selectedCity: _firstToCity,
                    onGovernorateChanged: (g) => setState(() {
                      _firstToGov = g;
                      _firstToCity = null;
                    }),
                    onCityChanged: (c) => setState(() => _firstToCity = c),
                  ),
                  const SizedBox(height: 12),
                  _DatePickerTile(
                    label: 'Travel date',
                    date: _firstDateTravel,
                    onTap: () => _pickDate(isFirst: true),
                  ),
                  const SizedBox(height: 24),
                  const Text('Return Trip', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  _GovernorateCityPicker(
                    label: 'From',
                    governorates: sortedGovs,
                    allCities: cities,
                    enabled: !legsLocked,
                    selectedGovernorate: _secondFromGov,
                    selectedCity: _secondFromCity,
                    onGovernorateChanged: (g) => setState(() {
                      _secondFromGov = g;
                      _secondFromCity = null;
                    }),
                    onCityChanged: (c) => setState(() => _secondFromCity = c),
                  ),
                  const SizedBox(height: 12),
                  _GovernorateCityPicker(
                    label: 'To',
                    governorates: sortedGovs,
                    allCities: cities,
                    enabled: !legsLocked,
                    selectedGovernorate: _secondToGov,
                    selectedCity: _secondToCity,
                    onGovernorateChanged: (g) => setState(() {
                      _secondToGov = g;
                      _secondToCity = null;
                    }),
                    onCityChanged: (c) => setState(() => _secondToCity = c),
                  ),
                  const SizedBox(height: 12),
                  _DatePickerTile(
                    label: 'Return date',
                    date: _secondDateTravel,
                    onTap: () => _pickDate(isFirst: false),
                  ),
                  if (legsLocked) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Travel/Return locations are disabled because a Tickets or Allowance '
                      'extra cost is already added — remove it to pick a location instead.',
                      style: TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Extra Costs', style: TextStyle(fontWeight: FontWeight.w700)),
                      TextButton.icon(
                        onPressed: allowedExtraTypes.isEmpty ? null : () => _addExtraCost(allowedExtraTypes),
                        icon: const Icon(Icons.add),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                  if (_anyLocationChosen)
                    const Text(
                      'Tickets and Allowance aren\'t available once a travel location is chosen.',
                      style: TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ..._extraCosts.asMap().entries.map((entry) {
                    final i = entry.key;
                    final cost = entry.value;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(cost.type.label),
                      subtitle: Text('EGP ${cost.amount.toStringAsFixed(2)}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: PharcoColors.danger),
                        onPressed: () => setState(() => _extraCosts.removeAt(i)),
                      ),
                    );
                  }),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : () => _previewAndSubmit(citiesById),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Preview & Submit'),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Failed to load governorates: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load cities: $e')),
      ),
    );
  }
}

/// Two-step location picker: choose a governorate (or "Home address" to skip
/// city selection entirely), then a city within it, sorted alphabetically.
class _GovernorateCityPicker extends StatelessWidget {
  final String label;
  final List<Governorate> governorates;
  final List<City> allCities;
  final bool enabled;
  final Governorate? selectedGovernorate;
  final City? selectedCity;
  final ValueChanged<Governorate?> onGovernorateChanged;
  final ValueChanged<City?> onCityChanged;

  const _GovernorateCityPicker({
    required this.label,
    required this.governorates,
    required this.allCities,
    required this.enabled,
    required this.selectedGovernorate,
    required this.selectedCity,
    required this.onGovernorateChanged,
    required this.onCityChanged,
  });

  @override
  Widget build(BuildContext context) {
    final citiesInGov = selectedGovernorate == null
        ? const <City>[]
        : (allCities.where((c) => c.governorateId == selectedGovernorate!.id).toList()
          ..sort((a, b) => a.nameEn.compareTo(b.nameEn)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<Governorate?>(
          value: selectedGovernorate,
          decoration: InputDecoration(labelText: label),
          isExpanded: true,
          items: [
            const DropdownMenuItem<Governorate?>(value: null, child: Text('Home address')),
            ...governorates.map((g) => DropdownMenuItem<Governorate?>(value: g, child: Text(g.nameEn))),
          ],
          onChanged: enabled ? onGovernorateChanged : null,
        ),
        if (selectedGovernorate != null) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<City?>(
            value: selectedCity,
            decoration: const InputDecoration(labelText: 'City'),
            isExpanded: true,
            items: citiesInGov.map((c) => DropdownMenuItem<City?>(value: c, child: Text(c.nameEn))).toList(),
            onChanged: enabled ? onCityChanged : null,
          ),
        ],
      ],
    );
  }
}

class _DatePickerTile extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;
  const _DatePickerTile({required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text('${date.day}/${date.month}/${date.year}'),
      ),
    );
  }
}

class _AddExtraCostSheet extends ConsumerStatefulWidget {
  final List<ExtraCostType> allowedTypes;
  final String? employeeId;
  const _AddExtraCostSheet({required this.allowedTypes, required this.employeeId});

  @override
  ConsumerState<_AddExtraCostSheet> createState() => _AddExtraCostSheetState();
}

class _AddExtraCostSheetState extends ConsumerState<_AddExtraCostSheet> {
  late ExtraCostType _type = widget.allowedTypes.first;
  final _amountController = TextEditingController();
  XFile? _receiptFile;
  bool _isUploading = false;

  Future<void> _pickReceipt(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(source: source, imageQuality: 80);
      if (picked != null) {
        setState(() => _receiptFile = picked);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open camera/gallery: $e')));
      }
    }
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) return;
    if (_receiptFile == null) return;

    String? invoiceImagePath;
    if (_receiptFile != null && widget.employeeId != null) {
      setState(() => _isUploading = true);
      try {
        invoiceImagePath =
            await ref.read(storageServiceProvider).uploadReceipt(_receiptFile!, widget.employeeId!);
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop(
      RequestExtraCost(type: _type, amount: amount, invoiceImagePath: invoiceImagePath),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Add Extra Cost', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 16),
          DropdownButtonFormField<ExtraCostType>(
            value: _type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: widget.allowedTypes.map((t) => DropdownMenuItem(value: t, child: Text(t.label))).toList(),
            onChanged: (t) => setState(() => _type = t!),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount (EGP)'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickReceipt(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Camera'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickReceipt(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _receiptFile != null ? 'Receipt attached ✓' : 'A receipt photo is required to add an extra cost.',
            style: TextStyle(color: _receiptFile != null ? PharcoColors.success : Colors.black54),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: (_isUploading || _receiptFile == null) ? null : _submit,
            child: _isUploading
                ? const SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _PreviewDialog extends StatelessWidget {
  final RequestPreview preview;
  const _PreviewDialog({required this.preview});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm Expense Request'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _line('Travel distance', '${preview.travelDistance.toStringAsFixed(1)} km'),
          _line('Return distance', '${preview.returnDistance.toStringAsFixed(1)} km'),
          _line('Billable distance', '${preview.finalDistance.toStringAsFixed(1)} km'),
          _line('Distance cost', 'EGP ${preview.costOfDistance.toStringAsFixed(2)}'),
          _line('Meals (${preview.mealsCount})', 'EGP ${preview.costOfMeals.toStringAsFixed(2)}'),
          _line('Extra costs', 'EGP ${preview.extraCost.toStringAsFixed(2)}'),
          const Divider(),
          _line('Total', 'EGP ${preview.requestAmount.toStringAsFixed(2)}', bold: true),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Submit')),
      ],
    );
  }

  Widget _line(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(value, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
          ],
        ),
      );
}
