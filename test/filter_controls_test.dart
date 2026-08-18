import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/widgets/filter_controls.dart';

void main() {
  testWidgets('shared filter controls keep task center visual contract', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              HeaderFilterIconButton(
                key: const Key('inactive-button'),
                icon: Icons.search,
                active: false,
                tooltip: 'inactive',
                onPressed: () {},
              ),
              HeaderFilterIconButton(
                key: const Key('active-button'),
                icon: Icons.filter_alt_outlined,
                active: true,
                tooltip: 'active',
                onPressed: () {},
              ),
              CompactFilterChip(
                key: const Key('selected-chip'),
                label: 'selected',
                selected: true,
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const Key('inactive-button'))),
      const Size(34, 34),
    );
    final inactiveButton = tester.widget<IconButton>(
      find.descendant(
        of: find.byKey(const Key('inactive-button')),
        matching: find.byType(IconButton),
      ),
    );
    final activeButton = tester.widget<IconButton>(
      find.descendant(
        of: find.byKey(const Key('active-button')),
        matching: find.byType(IconButton),
      ),
    );
    expect(
      inactiveButton.style?.backgroundColor?.resolve(<WidgetState>{}),
      const Color(0xff0b202d),
    );
    expect(
      activeButton.style?.backgroundColor?.resolve(<WidgetState>{}),
      const Color(0xff8a6628),
    );
    expect(
      activeButton.style?.side?.resolve(<WidgetState>{})?.color,
      const Color(0xff315064),
    );
    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: find.byKey(const Key('active-button')),
              matching: find.byType(Icon),
            ),
          )
          .color,
      const Color(0xffffdc88),
    );

    final chipContainer = tester.widget<Container>(
      find.descendant(
        of: find.byKey(const Key('selected-chip')),
        matching: find.byType(Container),
      ),
    );
    expect(
      (chipContainer.decoration as BoxDecoration).color,
      const Color(0xff287e6a),
    );
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(const Key('selected-chip')),
              matching: find.byType(Text),
            ),
          )
          .style
          ?.color,
      Colors.white,
    );
  });
}
