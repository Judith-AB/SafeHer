import 'package:flutter_test/flutter_test.dart';
import 'package:safeher/constants.dart';

void main() {
  test('coordinates are rounded to 3 decimals before upload', () {
    expect(AppConstants.roundCoord(9.931234), 9.931);
    expect(AppConstants.roundCoord(76.2675), closeTo(76.268, 1e-9));
  });

  test('category list matches the model and the Firestore rules', () {
    expect(AppConstants.categories,
        ['Assault', 'Stalking', 'Eve Teasing', 'Harassment', 'Unsafe Area']);
  });
}
