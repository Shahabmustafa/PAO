import 'package:flutter/widgets.dart';

const Map<String, String> _urduPlaceNames = {
  // Provinces & territories
  'Punjab': 'پنجاب',
  'Sindh': 'سندھ',
  'Khyber Pakhtunkhwa': 'خیبر پختونخوا',
  'Balochistan': 'بلوچستان',
  'Gilgit-Baltistan': 'گلگت بلتستان',
  'Azad Jammu & Kashmir': 'آزاد جموں و کشمیر',
  'Islamabad Capital Territory': 'وفاقی دارالحکومت اسلام آباد',
  // Cities
  'Lahore': 'لاہور',
  'Faisalabad': 'فیصل آباد',
  'Rawalpindi': 'راولپنڈی',
  'Multan': 'ملتان',
  'Gujranwala': 'گوجرانوالہ',
  'Sialkot': 'سیالکوٹ',
  'Bahawalpur': 'بہاولپور',
  'Sargodha': 'سرگودھا',
  'Sheikhupura': 'شیخوپورہ',
  'Rahim Yar Khan': 'رحیم یار خان',
  'Karachi': 'کراچی',
  'Hyderabad': 'حیدرآباد',
  'Sukkur': 'سکھر',
  'Larkana': 'لاڑکانہ',
  'Nawabshah': 'نواب شاہ',
  'Mirpurkhas': 'میرپور خاص',
  'Jacobabad': 'جیکب آباد',
  'Shikarpur': 'شکارپور',
  'Peshawar': 'پشاور',
  'Mardan': 'مردان',
  'Mingora': 'مینگورہ',
  'Abbottabad': 'ایبٹ آباد',
  'Kohat': 'کوہاٹ',
  'Bannu': 'بنوں',
  'Dera Ismail Khan': 'ڈیرہ اسماعیل خان',
  'Mansehra': 'مانسہرہ',
  'Quetta': 'کوئٹہ',
  'Gwadar': 'گوادر',
  'Turbat': 'تربت',
  'Khuzdar': 'خضدار',
  'Sibi': 'سبی',
  'Chaman': 'چمن',
  'Hub': 'حب',
  'Zhob': 'ژوب',
  'Gilgit': 'گلگت',
  'Skardu': 'سکردو',
  'Hunza': 'ہنزہ',
  'Ghanche': 'غانچے',
  'Astore': 'استور',
  'Muzaffarabad': 'مظفرآباد',
  'Mirpur': 'میرپور',
  'Rawalakot': 'راولاکوٹ',
  'Kotli': 'کوٹلی',
  'Bhimber': 'بھمبر',
  'Islamabad': 'اسلام آباد',
};

/// Display name for a province or city, which the app keeps as its English
/// name in data. Falls back to the English name for anything not listed.
String placeName(BuildContext context, String name) {
  if (Localizations.localeOf(context).languageCode == 'ur') {
    return _urduPlaceNames[name] ?? name;
  }
  return name;
}
