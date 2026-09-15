import 'package:flutter_test/flutter_test.dart';
import 'package:pharco_app/core/enums.dart';

void main() {
  test('extra cost types are restricted for standalone requests', () {
    final allowed = ExtraCostType.allowedFor(requestType: RequestType.standalone, titleId: 3);
    expect(allowed, [ExtraCostType.tollGate]);
  });

  test('extra cost types include Uber for senior titles on non-field visits', () {
    final allowed = ExtraCostType.allowedFor(requestType: RequestType.training, titleId: 3);
    expect(allowed, ExtraCostType.values);
  });
}
