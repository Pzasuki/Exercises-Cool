import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:exercises_app/features/library/widgets/search_field.dart';
import 'package:exercises_app/state/library_controller.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('probe2', (tester) async {
    final exercises = await loadExercises(tester);

    Widget host(double insetBottom) => MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => LibraryController(exercises)),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                viewInsets: EdgeInsets.only(bottom: insetBottom),
              ),
              child: const Scaffold(body: SearchField()),
            ),
          ),
        );

    await tester.pumpWidget(host(0));
    await tester.showKeyboard(find.byType(EditableText).first);
    final editable = tester.state<EditableTextState>(
      find.byType(EditableText).first,
    );
    // ignore: avoid_print
    print('A focused=${editable.widget.focusNode.hasFocus}');

    await tester.pumpWidget(host(400));
    final ctx = tester.element(find.byType(SearchField));
    // ignore: avoid_print
    print('B insets400: mq=${MediaQuery.of(ctx).viewInsets.bottom} '
        'focused=${editable.widget.focusNode.hasFocus}');

    await tester.pumpWidget(host(0));
    // ignore: avoid_print
    print('C insets0: mq=${MediaQuery.of(ctx).viewInsets.bottom} '
        'focused=${editable.widget.focusNode.hasFocus}');
  });
}
