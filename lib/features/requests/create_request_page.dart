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

class CreateRequestPage extends ConsumerStatefulWidget {
  const CreateRequestPage({super.key});

  @override
  ConsumerState<CreateRequestPage> createState() => _CreateRequestPageState();
}

class _CreateRequestPageState extends ConsumerState<CreateRequestPage> {
  RequestType _requestType = RequestType.fieldVisit;
  City? _firstFromCity;
  City? _firstToCity;
  DateTime _firstDateTravel = DateTime.now();
  City? _secondFromCity;
  City? _secondToCity;
  DateTime _secondDateTravel = DateTime.now();
  final List<RequestExtraCost> _extraCosts = [];
  bool _isSubmitting = false;

  Future<void> _pickDate({required bool isFirst}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFirst ? _firstDateTravel : _secondDateTravel,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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

  void _addExtraCost() async {
    final profile = ref.read(myProfileProvider).value;
    final result = await showModalBottomSheet<RequestExtraCost>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddExtraCostSheet(
        requestType: _requestType,
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
    final profileAsync = ref.watch(myProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('New Expense Request')),
      body: citiesAsync.when(
        data: (cities) {
          final citiesById = {for (final c in cities) c.id: c};
          final allowedExtraTypes = profileAsync.maybeWhen(
            data: (p) => ExtraCostType.allowedFor(requestType: _requestType, titleId: p.titleId ?? 0),
            orElse: () => ExtraCostType.values,
          );

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
              const Text('Outbound Trip', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              _CityDropdown(
                label: 'From (blank = home address)',
                cities: cities,
                value: _firstFromCity,
                onChanged: (c) => setState(() => _firstFromCity = c),
              ),
              const SizedBox(height: 12),
              _CityDropdown(
                label: 'To (blank = home address)',
                cities: cities,
                value: _firstToCity,
                onChanged: (c) => setState(() => _firstToCity = c),
              ),
              const SizedBox(height: 12),
              _DatePickerTile(
                label: 'Outbound date',
                date: _firstDateTravel,
                onTap: () => _pickDate(isFirst: true),
              ),
              const SizedBox(height: 24),
              const Text('Return Trip', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              _CityDropdown(
                label: 'From (blank = home address)',
                cities: cities,
                value: _secondFromCity,
                onChanged: (c) => setState(() => _secondFromCity = c),
              ),
              const SizedBox(height: 12),
              _CityDropdown(
                label: 'To (blank = home address)',
                cities: cities,
                value: _secondToCity,
                onChanged: (c) => setState(() => _secondToCity = c),
              ),
              const SizedBox(height: 12),
              _DatePickerTile(
                label: 'Return date',
                date: _secondDateTravel,
                onTap: () => _pickDate(isFirst: false),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Extra Costs', style: TextStyle(fontWeight: FontWeight.w700)),
                  TextButton.icon(
                    onPressed: allowedExtraTypes.isEmpty ? null : _addExtraCost,
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  ),
                ],
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
        error: (e, _) => Center(child: Text('Failed to load cities: $e')),
      ),
    );
  }
}

class _CityDropdown extends StatelessWidget {
  final String label;
  final List<City> cities;
  final City? value;
  final ValueChanged<City?> onChanged;

  const _CityDropdown({required this.label, required this.cities, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<City?>(
      value: value,
      decoration: InputDecoration(labelText: label),
      isExpanded: true,
      items: [
        const DropdownMenuItem<City?>(value: null, child: Text('Home address')),
        ...cities.map((c) => DropdownMenuItem<City?>(value: c, child: Text(c.nameEn))),
      ],
      onChanged: onChanged,
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
  final RequestType requestType;
  final String? employeeId;
  const _AddExtraCostSheet({required this.requestType, required this.employeeId});

  @override
  ConsumerState<_AddExtraCostSheet> createState() => _AddExtraCostSheetState();
}

class _AddExtraCostSheetState extends ConsumerState<_AddExtraCostSheet> {
  ExtraCostType _type = ExtraCostType.tollGate;
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
    final allowed = ExtraCostType.allowedFor(requestType: widget.requestType, titleId: 0);
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
            value: allowed.contains(_type) ? _type : allowed.first,
            decoration: const InputDecoration(labelText: 'Type'),
            items: allowed.map((t) => DropdownMenuItem(value: t, child: Text(t.label))).toList(),
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
          if (_receiptFile != null) ...[
            const SizedBox(height: 8),
            const Text('Receipt attached ✓', style: TextStyle(color: PharcoColors.success)),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isUploading ? null : _submit,
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
