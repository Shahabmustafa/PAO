import 'package:flutter/material.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/widgets/custom_dropdown_field.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/pakistan_location.dart';

class ProvinceScreen extends StatefulWidget {
  const ProvinceScreen({super.key});

  @override
  State<ProvinceScreen> createState() => _ProvinceScreenState();
}

class _ProvinceScreenState extends State<ProvinceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _countryController = TextEditingController(text: 'Pakistan');
  final _addressController = TextEditingController();

  Province? _selectedProvince;
  String? _selectedCity;

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
        title: const Text(
          'Select Your Location',
          style: TextStyle(fontWeight: FontWeight.bold),
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
                  'Add your address to finish setting up your account',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  controller: _countryController,
                  label: 'Country',
                  hint: 'Country',
                  enabled: false,
                ),
                const SizedBox(height: 18),
                CustomDropdownField<Province>(
                  label: 'Province',
                  hint: 'Select your province',
                  value: _selectedProvince,
                  items: kPakistanProvinces,
                  itemLabel: (province) => province.name,
                  onChanged: (province) {
                    setState(() {
                      _selectedProvince = province;
                      _selectedCity = null;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Province is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                CustomDropdownField<String>(
                  label: 'City',
                  hint: 'Select your city',
                  value: _selectedCity,
                  items: _selectedProvince?.cities ?? const [],
                  itemLabel: (city) => city,
                  onChanged: _selectedProvince == null
                      ? null
                      : (city) => setState(() => _selectedCity = city),
                  validator: (value) {
                    if (value == null) {
                      return 'City is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                CustomTextField(
                  controller: _addressController,
                  label: 'Address',
                  hint: 'Enter your address',
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Address is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                PrimaryButton(label: 'Continue', onPressed: _onContinuePressed),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
