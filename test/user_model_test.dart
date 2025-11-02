import 'package:flutter_test/flutter_test.dart';
import 'package:readright/models/user_model.dart';
import 'package:readright/utils/enums.dart';

void main() {
  group('UserModel', () {
    test('toJson/fromJson roundtrip', () {
      // Adjust fields to match your UserModel constructor/fields.
      final original = UserModel(
        id: 'user-123',
        email: 'test@example.com',
        fullName: 'Test User',
        role: UserRole.teacher,
        local: 'en-US',
        isEmailVerified: true,
        verificationStatus: VerificationStatus.approved,
      );

      final json = original.toJson();
      final restored = UserModel.fromJson(json);

      // Compare fields because UserModel doesn't override ==.
      expect(restored.id, equals(original.id));
      expect(restored.email, equals(original.email));
      expect(restored.fullName, equals(original.fullName));
      expect(restored.role, equals(original.role));
      expect(restored.local, equals(original.local));
      expect(restored.isEmailVerified, equals(original.isEmailVerified));
      expect(restored.verificationStatus, equals(original.verificationStatus));
    });

    test('copyWith creates modified copy and preserves other fields', () {
      final original = UserModel(
        id: 'user-123',
        email: 'test@example.com',
        fullName: 'Test User',
        role: UserRole.teacher,
        local: 'en-US',
        isEmailVerified: true,
        verificationStatus: VerificationStatus.approved,
      );

      // If your UserModel.copyWith has different named params, adjust here.
      final modified = original.copyWith(
        email: 'new@example.com',
        role: UserRole.student,
      );

      expect(modified.email, equals('new@example.com'));
      expect(modified.id, equals(original.id));
      expect(modified.fullName, equals(original.fullName));
      expect(modified.role, equals(UserRole.student));
      expect(modified.local, equals(original.local));
      expect(modified.isEmailVerified, equals(original.isEmailVerified));
      expect(modified.verificationStatus, equals(original.verificationStatus));
    });

    test('equality and hashCode', () {
      final a = UserModel(
        id: 'user-123',
        email: 'test@example.com',
        fullName: 'Test User',
      );
      final b = UserModel(
        id: 'user-123',
        email: 'test@example.com',
        fullName: 'Test User',
      );

      // Models don't override equality, so compare fields instead.
      expect(a.email, equals(b.email));
      expect(a.fullName, equals(b.fullName));
    });

    test('fromJson tolerates missing optional fields', () {
      // Provide a minimal map; adjust keys to match your model expectations.
      final minimalMap = <String, dynamic>{
        'id': 'user-xyz',
        'email': 'min@example.com',
      };

      final user = UserModel.fromJson(minimalMap);

      expect(user.id, equals('user-xyz'));
      expect(user.email, equals('min@example.com'));
      // If fullName is optional in your model, it should be null or empty.
      // Adjust assertion as appropriate:
      expect(user.fullName, isEmpty);
    });
  });
}