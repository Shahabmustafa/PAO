import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pao/core/routes/app_routes.dart';
import 'package:pao/features/add_item/presentation/screens/add_item_screen.dart';
import 'package:pao/features/location/domain/pakistan_location.dart';
import 'package:pao/features/location/presentation/screens/province_screen.dart';
import 'package:pao/features/settings/presentation/screens/edit_profile_screen.dart';

import '../helpers/test_app.dart';

Finder byHint(String hint) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.hintText == hint,
);

void main() {
  setUpAll(initFakeSupabase);

  group('ProvinceScreen', () {
    Future<void> pumpProvince(WidgetTester tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(
        testApp(
          const ProvinceScreen(),
          onGenerateRoute: (settings) => MaterialPageRoute(
            settings: settings,
            builder: (_) => Scaffold(body: Text('went to ${settings.name}')),
          ),
        ),
      );
    }

    // Tap the dropdown itself: its hint text sits underneath the field's
    // decoration, so tapping the text reports a (harmless) hit-test warning.
    final provinceField = find.byType(DropdownButtonFormField<Province>);
    final cityField = find.byType(DropdownButtonFormField<String>);

    Future<void> choose(WidgetTester tester, Finder dropdown, String option) async {
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text(option).last);
      await tester.pumpAndSettle();
    }

    testWidgets('shows a fixed country and empty selectors', (tester) async {
      await pumpProvince(tester);

      expect(find.text('Select Your Location'), findsOneWidget);
      expect(find.text('Pakistan'), findsOneWidget);
      expect(find.text('Select your province'), findsOneWidget);
      expect(find.text('Select your city'), findsOneWidget);
    });

    testWidgets('Continue with nothing chosen shows all three errors', (
      tester,
    ) async {
      await pumpProvince(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
      await tester.pump();

      expect(find.text('Province is required'), findsOneWidget);
      expect(find.text('City is required'), findsOneWidget);
      expect(find.text('Address is required'), findsOneWidget);
    });

    testWidgets('the city list is disabled until a province is picked', (
      tester,
    ) async {
      await pumpProvince(tester);

      final city = tester.widget<DropdownButtonFormField<String>>(cityField);
      expect(city.onChanged, isNull);
    });

    testWidgets('cities follow the chosen province', (tester) async {
      await pumpProvince(tester);

      await choose(tester, provinceField, 'Sindh');
      await tester.tap(cityField);
      await tester.pumpAndSettle();

      final sindh = kPakistanProvinces.firstWhere((p) => p.name == 'Sindh');
      for (final city in sindh.cities.take(3)) {
        expect(find.text(city), findsWidgets, reason: city);
      }
      expect(find.text('Lahore'), findsNothing, reason: 'a Punjab city');
    });

    testWidgets('changing province resets the chosen city', (tester) async {
      await pumpProvince(tester);
      await choose(tester, provinceField, 'Punjab');
      await choose(tester, cityField, 'Lahore');
      expect(find.text('Lahore'), findsOneWidget);

      await choose(tester, provinceField, 'Sindh');

      expect(find.text('Lahore'), findsNothing);
      expect(find.text('Select your city'), findsOneWidget);
    });

    testWidgets('a complete form continues to the dashboard', (tester) async {
      await pumpProvince(tester);
      await choose(tester, provinceField, 'Punjab');
      await choose(tester, cityField, 'Lahore');
      await tester.enterText(byHint('Enter your address'), 'House 1, Street 2');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
      await tester.pumpAndSettle();

      expect(find.text('went to ${AppRoutes.dashboard}'), findsOneWidget);
    });
  });

  group('AddItemScreen', () {
    Future<void> pumpAdd(WidgetTester tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(testApp(const AddItemScreen()));
    }

    testWidgets('shows the form', (tester) async {
      await pumpAdd(tester);

      expect(find.text('Add Product'), findsOneWidget);
      expect(find.text('Give something away for free'), findsOneWidget);
      expect(find.text('Photos'), findsOneWidget);
      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Description'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Condition'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Post for Free'), findsOneWidget);
    });

    testWidgets('offers every category except "All"', (tester) async {
      await pumpAdd(tester);

      expect(find.text('Electronics'), findsOneWidget);
      expect(find.text('Books'), findsOneWidget);
      expect(find.text('All'), findsNothing);
    });

    testWidgets('conditions are New, Used and Old, defaulting to New', (
      tester,
    ) async {
      await pumpAdd(tester);

      final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip));
      final byLabel = {
        for (final chip in chips) (chip.label as Text).data: chip.selected,
      };
      expect(byLabel['New'], isTrue);
      expect(byLabel['Used'], isFalse);
      expect(byLabel['Old'], isFalse);

      await tester.ensureVisible(find.text('Used'));
      await tester.tap(find.text('Used'));
      await tester.pump();
      expect(
        tester
            .widgetList<ChoiceChip>(find.byType(ChoiceChip))
            .firstWhere((chip) => (chip.label as Text).data == 'Used')
            .selected,
        isTrue,
      );

      await tester.ensureVisible(find.text('Old'));
      await tester.tap(find.text('Old'));
      await tester.pump();

      final after = {
        for (final chip in tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)))
          (chip.label as Text).data: chip.selected,
      };
      expect(after['Old'], isTrue);
      expect(after['New'], isFalse);
    });

    testWidgets('title and description are required', (tester) async {
      await pumpAdd(tester);

      await tester.ensureVisible(find.text('Post for Free'));
      await tester.tap(find.text('Post for Free'));
      await tester.pump();

      expect(find.text('Title is required'), findsOneWidget);
      expect(find.text('Description is required'), findsOneWidget);
    });

    testWidgets('a category must be chosen', (tester) async {
      await pumpAdd(tester);
      await tester.enterText(byHint('e.g. Wireless Headphones'), 'Lamp');
      await tester.enterText(byHint('Describe the item and its condition'), 'Desk lamp');

      await tester.ensureVisible(find.text('Post for Free'));
      await tester.tap(find.text('Post for Free'));
      await pumpUntilToastVisible(tester);

      expect(find.text('Please select a category'), findsOneWidget);
      await settleToasts(tester);
    });

    testWidgets('posting while signed out explains why it failed', (
      tester,
    ) async {
      await pumpAdd(tester);
      await tester.enterText(byHint('e.g. Wireless Headphones'), 'Lamp');
      await tester.enterText(byHint('Describe the item and its condition'), 'Desk lamp');
      await tester.ensureVisible(find.text('Books'));
      await tester.tap(find.text('Books'));
      await tester.pump();

      await tester.ensureVisible(find.text('Post for Free'));
      await tester.tap(find.text('Post for Free'));
      await pumpUntilToastVisible(tester);

      expect(find.text('You must be logged in to post an item.'), findsOneWidget);
      await settleToasts(tester);
    });

    testWidgets('renders in dark mode without layout errors', (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(
        testApp(const AddItemScreen(), themeMode: ThemeMode.dark),
      );

      expect(find.text('Give something away for free'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('EditProfileScreen', () {
    Future<void> pumpEdit(WidgetTester tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(testApp(const EditProfileScreen()));
      await tester.pump();
    }

    testWidgets('shows the profile fields', (tester) async {
      await pumpEdit(tester);

      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Phone (optional)'), findsOneWidget);
      expect(find.text('Bio (optional)'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Save Changes'), findsOneWidget);
    });

    testWidgets('name and email are required', (tester) async {
      await pumpEdit(tester);

      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pump();

      expect(find.text('Name is required'), findsOneWidget);
      expect(find.text('Email is required'), findsOneWidget);
    });

    testWidgets('email must look valid', (tester) async {
      await pumpEdit(tester);

      await tester.enterText(byHint('Enter your full name'), 'Ali');
      await tester.enterText(byHint('Enter your email'), 'nope');
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pump();

      expect(find.text('Enter a valid email'), findsOneWidget);
    });

    testWidgets('phone and bio are optional', (tester) async {
      await pumpEdit(tester);

      await tester.enterText(byHint('Enter your full name'), 'Ali');
      await tester.enterText(byHint('Enter your email'), 'a@b.com');
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pump();

      expect(find.text('Name is required'), findsNothing);
      expect(find.text('Email is required'), findsNothing);
      // Signed out: saving is refused with a toast rather than crashing.
      await pumpUntilToastVisible(tester);
      expect(
        find.text('You must be logged in to update your profile.'),
        findsOneWidget,
      );
      await settleToasts(tester);
    });
  });
}
