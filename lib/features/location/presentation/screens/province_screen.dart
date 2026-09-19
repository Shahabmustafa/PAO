import 'package:flutter/material.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/widgets/custom_dropdown_field.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/pakistan_location.dart';
import '../../../../core/l10n/l10n.dart';
import '../../domain/place_names.dart';

class ProvinceScreen extends StatefulWidget {
  const ProvinceScreen({super.key});

  @override
  State<ProvinceScreen> createState() => _ProvinceScreenState();
}

class _ProvinceScreenState extends State<ProvinceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _countryController = TextEditingController();
  final _addressController = TextEditingController();

  Province? _selectedProvince;
  String? _selectedCity;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _countryController.text = context.l10n.countryPakistan;
  }

  @override
  void dispose() {
    _countryController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _onContinuePressed() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.dashboard,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          context.l10n.selectYourLocation,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.addAddressToFinish,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  controller: _countryController,
                  label: context.l10n.country,
                  hint: context.l10n.country,
                  enabled: false,
                ),
                const SizedBox(height: 18),
                CustomDropdownField<Province>(
                  label: context.l10n.province,
                  hint: context.l10n.selectProvinceHint,
                  value: _selectedProvince,
                  items: kPakistanProvinces,
                  itemLabel: (province) => placeName(context, province.name),
                  onChanged: (province) {
                    setState(() {
                      _selectedProvince = province;
                      _selectedCity = null;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return context.l10n.provinceRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                CustomDropdownField<String>(
                  label: context.l10n.city,
                  hint: context.l10n.selectCityHint,
                  value: _selectedCity,
                  items: _selectedProvince?.cities ?? const [],
                  itemLabel: (city) => placeName(context, city),
                  onChanged: _selectedProvince == null
                      ? null
                      : (city) => setState(() => _selectedCity = city),
                  validator: (value) {
                    if (value == null) {
                      return context.l10n.cityRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                CustomTextField(
                  controller: _addressController,
                  label: context.l10n.address,
                  hint: context.l10n.enterAddressHint,
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return context.l10n.addressRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                PrimaryButton(
                  label: context.l10n.continueLabel,
                  onPressed: _onContinuePressed,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
