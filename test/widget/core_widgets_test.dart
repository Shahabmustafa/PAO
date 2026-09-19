import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pao/core/theme/app_colors.dart';
import 'package:pao/core/theme/app_icons.dart';
import 'package:pao/core/widgets/app_avatar.dart';
import 'package:pao/core/widgets/app_icon.dart';
import 'package:pao/core/widgets/app_snackbar.dart';
import 'package:pao/core/widgets/custom_dropdown_field.dart';
import 'package:pao/core/widgets/custom_text_field.dart';
import 'package:pao/core/widgets/primary_button.dart';
import 'package:pao/core/widgets/terms_acceptance_checkbox.dart';

import '../helpers/test_app.dart';

void main() {
  group('PrimaryButton', () {
    testWidgets('shows its label and fires onPressed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        testApp(PrimaryButton(label: 'Login', onPressed: () => taps++)),
      );

      expect(find.text('Login'), findsOneWidget);
      await tester.tap(find.byType(ElevatedButton));

      expect(taps, 1);
    });

    testWidgets('while loading: spinner instead of label, taps ignored', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        testApp(
          PrimaryButton(label: 'Login', isLoading: true, onPressed: () => taps++),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Login'), findsNothing);
      await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
      expect(taps, 0);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
    });

    testWidgets('with no handler it is disabled but still shows the label', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(const PrimaryButton(label: 'Continue', onPressed: null)),
      );

      expect(find.text('Continue'), findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
    });
  });

  group('CustomTextField', () {
    testWidgets('renders the label and hint', (tester) async {
      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: CustomTextField(
              controller: TextEditingController(),
              label: 'Email',
              hint: 'Enter your email',
            ),
          ),
        ),
      );

      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Enter your email'), findsOneWidget);
    });

    testWidgets('writes typed text to its controller', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: CustomTextField(controller: controller, label: 'L', hint: 'H'),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'hello');

      expect(controller.text, 'hello');
    });

    testWidgets('shows the validator error inside a Form', (tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: Form(
              key: formKey,
              child: CustomTextField(
                controller: TextEditingController(),
                label: 'Name',
                hint: 'H',
                validator: (v) => (v == null || v.isEmpty) ? 'Name is required' : null,
              ),
            ),
          ),
        ),
      );

      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();

      expect(find.text('Name is required'), findsOneWidget);
    });

    testWidgets('obscured fields are single-line even if maxLines is set', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: CustomTextField(
              controller: TextEditingController(),
              label: 'Password',
              hint: 'H',
              obscureText: true,
              maxLines: 4,
            ),
          ),
        ),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.obscureText, isTrue);
      expect(field.maxLines, 1);
    });

    testWidgets('can be disabled', (tester) async {
      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: CustomTextField(
              controller: TextEditingController(text: 'Pakistan'),
              label: 'Country',
              hint: 'H',
              enabled: false,
            ),
          ),
        ),
      );

      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    });
  });

  group('CustomDropdownField', () {
    testWidgets('lists the items and reports the selection', (tester) async {
      String? chosen;
      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: CustomDropdownField<String>(
              label: 'City',
              hint: 'Select your city',
              items: const ['Lahore', 'Karachi'],
              itemLabel: (c) => c,
              onChanged: (v) => chosen = v,
            ),
          ),
        ),
      );

      expect(find.text('City'), findsOneWidget);
      expect(find.text('Select your city'), findsOneWidget);

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Karachi').last);
      await tester.pumpAndSettle();

      expect(chosen, 'Karachi');
    });
  });

  group('AppIcon', () {
    testWidgets('renders an SVG at the requested size', (tester) async {
      await tester.pumpWidget(
        testApp(
          const Scaffold(
            body: AppIcon(AppIcons.search, size: 30, color: Colors.red),
          ),
        ),
      );
      await tester.pump();

      final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(svg.width, 30);
      expect(svg.height, 30);
    });
  });

  group('AppAvatar', () {
    testWidgets('without a URL it shows the bundled default photo', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(const Scaffold(body: AppAvatar(radius: 30))),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as AssetImage).assetName, 'assets/images/profile.jpg');
      expect(tester.getSize(find.byType(AppAvatar)), const Size(60, 60));
    });
  });

  group('AppSnackbar', () {
    testWidgets('shows the message as a toast that closes itself', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => AppSnackbar.show(context, 'Product posted'),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await pumpUntilToastVisible(tester);
      expect(find.text('Product posted'), findsOneWidget);

      await settleToasts(tester);
      expect(find.text('Product posted'), findsNothing);
    });

    testWidgets('error variant shows the message too', (tester) async {
      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => AppSnackbar.show(
                  context,
                  'Something failed',
                  icon: Icons.error_outline,
                  color: AppColors.error,
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await pumpUntilToastVisible(tester);
      expect(find.text('Something failed'), findsOneWidget);

      await settleToasts(tester);
    });
  });

  group('TermsAcceptanceCheckbox', () {
    testWidgets('shows the agreement text with both links', (tester) async {
      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: TermsAcceptanceCheckbox(value: false, onChanged: (_) {}),
          ),
        ),
      );

      expect(find.textContaining('I agree to the', findRichText: true), findsOneWidget);
      expect(find.textContaining('Terms & Conditions', findRichText: true), findsOneWidget);
      expect(find.textContaining('Privacy Policy', findRichText: true), findsOneWidget);
    });

    testWidgets('reports toggles through onChanged', (tester) async {
      bool? received;
      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: TermsAcceptanceCheckbox(
              value: false,
              onChanged: (v) => received = v,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(Checkbox));

      expect(received, isTrue);
    });

    testWidgets('reflects the current value', (tester) async {
      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: TermsAcceptanceCheckbox(value: true, onChanged: (_) {}),
          ),
        ),
      );

      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    });
  });
}
