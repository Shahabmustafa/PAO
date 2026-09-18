class Province {
  final String name;
  final List<String> cities;

  const Province({required this.name, required this.cities});
}

const List<Province> kPakistanProvinces = [
  Province(
    name: 'Punjab',
    cities: [
      'Lahore',
      'Faisalabad',
      'Rawalpindi',
      'Multan',
      'Gujranwala',
      'Sialkot',
      'Bahawalpur',
      'Sargodha',
      'Sheikhupura',
      'Rahim Yar Khan',
    ],
  ),
  Province(
    name: 'Sindh',
    cities: [
      'Karachi',
      'Hyderabad',
      'Sukkur',
      'Larkana',
      'Nawabshah',
      'Mirpurkhas',
      'Jacobabad',
      'Shikarpur',
    ],
  ),
  Province(
    name: 'Khyber Pakhtunkhwa',
    cities: [
      'Peshawar',
      'Mardan',
      'Mingora',
      'Abbottabad',
      'Kohat',
      'Bannu',
      'Dera Ismail Khan',
      'Mansehra',
    ],
  ),
  Province(
    name: 'Balochistan',
    cities: [
      'Quetta',
      'Gwadar',
      'Turbat',
      'Khuzdar',
      'Sibi',
      'Chaman',
      'Hub',
      'Zhob',
    ],
  ),
  Province(
    name: 'Gilgit-Baltistan',
    cities: ['Gilgit', 'Skardu', 'Hunza', 'Ghanche', 'Astore'],
  ),
  Province(
    name: 'Azad Jammu & Kashmir',
    cities: ['Muzaffarabad', 'Mirpur', 'Rawalakot', 'Kotli', 'Bhimber'],
  ),
  Province(name: 'Islamabad Capital Territory', cities: ['Islamabad']),
];
