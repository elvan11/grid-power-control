import 'package:app/core/widgets/gp_responsive.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('page padding keeps only horizontal in all breakpoints', () {
    final compact = GpResponsiveBreakpoints.pagePaddingFor(
      GpWindowSize.compact,
    );
    final medium = GpResponsiveBreakpoints.pagePaddingFor(GpWindowSize.medium);
    final expanded = GpResponsiveBreakpoints.pagePaddingFor(
      GpWindowSize.expanded,
    );

    expect(compact, const EdgeInsets.symmetric(horizontal: 16));
    expect(compact.vertical, 0);

    expect(medium, const EdgeInsets.symmetric(horizontal: 24));
    expect(medium.vertical, 0);

    expect(expanded, const EdgeInsets.symmetric(horizontal: 32));
    expect(expanded.vertical, 0);
  });
}
