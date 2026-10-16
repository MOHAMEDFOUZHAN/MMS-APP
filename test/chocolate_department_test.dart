import 'package:flutter_test/flutter_test.dart';
import 'package:mms_app/data/models/batch_model.dart';
import 'package:mms_app/data/models/user_profile_model.dart';
import 'package:mms_app/data/repositories/auth_repository.dart';

void main() {
  group('Chocolate Department Verification Suite', () {
    test('1. UserProfileModel correctly identifies CHOCOLATE_USER role and username', () {
      final chocProfile = UserProfileModel(
        id: 'user-choc-123',
        username: 'chocolate',
        fullName: 'Chocolate Department',
        role: 'CHOCOLATE_USER',
      );

      expect(chocProfile.isChocolateUser, isTrue);
      expect(chocProfile.isTeaUser, isFalse);
      expect(chocProfile.isAdmin, isFalse);

      final teaProfile = UserProfileModel(
        id: 'user-tea-123',
        username: 'bm',
        fullName: 'Tea Department',
        role: 'TEA_USER',
      );

      expect(teaProfile.isChocolateUser, isFalse);
      expect(teaProfile.isTeaUser, isTrue);
    });

    test('2. AuthRepository maps chocolate usernames to chocolate@benchmarkmms.com', () {
      final authRepo = AuthRepository();

      expect(authRepo.mapUsernameToEmail('chocolate'), equals('chocolate@benchmarkmms.com'));
      expect(authRepo.mapUsernameToEmail('CHOCOLATE'), equals('chocolate@benchmarkmms.com'));
      expect(authRepo.mapUsernameToEmail('cho'), equals('chocolate@benchmarkmms.com'));
      expect(authRepo.mapUsernameToEmail('choco'), equals('chocolate@benchmarkmms.com'));
      expect(authRepo.mapUsernameToEmail('chocolate@benchmarkmms.com'), equals('chocolate@benchmarkmms.com'));
      expect(authRepo.mapUsernameToEmail('CHOCOLATE@BENCHMARKMMS.COM'), equals('chocolate@benchmarkmms.com'));
    });

    test('3. BatchModel serializes and deserializes rackLocation properly', () {
      final now = DateTime.now();
      final batch = BatchModel(
        id: 101,
        batchNo: '99',
        batchDate: now,
        materialCode: 'CHOC-DARK-80',
        description: 'Dark Chocolate 80% Bar',
        category: 'CHOCOLATE',
        uom: 'kg',
        rackLocation: 'RACK C-1',
        receivedQuantity: 50.0,
        availableQuantity: 50.0,
      );

      expect(batch.rackLocation, equals('RACK C-1'));

      final json = batch.toJson();
      expect(json['rack_location'], equals('RACK C-1'));
      expect(json['category'], equals('CHOCOLATE'));

      json['id'] = 101;
      final parsed = BatchModel.fromJson(json);
      expect(parsed.id, equals(101));
      expect(parsed.batchNo, equals('99'));
      expect(parsed.rackLocation, equals('RACK C-1'));
      expect(parsed.category, equals('CHOCOLATE'));

      final updated = parsed.copyWith(rackLocation: 'COLD SHELF B-2');
      expect(updated.rackLocation, equals('COLD SHELF B-2'));
    });

    test('4. Admin and Owner profiles are strictly isolated from Chocolate and Tea terminals', () {
      final adminProfile = const UserProfileModel(
        id: 'admin-1',
        username: 'admin',
        fullName: 'Administrator',
        role: 'ADMIN',
      );
      expect(adminProfile.isAdmin, isTrue);
      expect(adminProfile.isTeaUser, isFalse);
      expect(adminProfile.isChocolateUser, isFalse);

      final ownerProfile = const UserProfileModel(
        id: 'owner-1',
        username: 'owner',
        fullName: 'System Owner',
        role: 'OWNER',
      );
      expect(ownerProfile.isOwner, isTrue);
      expect(ownerProfile.isAdmin, isFalse);
      expect(ownerProfile.isTeaUser, isFalse);
      expect(ownerProfile.isChocolateUser, isFalse);

      final authRepo = AuthRepository();
      expect(authRepo.mapUsernameToEmail('admin'), equals('admin@benchmarkmms.com'));
      expect(authRepo.mapUsernameToEmail('owner'), equals('owner@benchmarkmms.com'));
      expect(authRepo.mapUsernameToEmail('bm'), equals('bm@benchmarkmms.com'));
      expect(authRepo.mapUsernameToEmail('tea'), equals('bm@benchmarkmms.com'));
      expect(authRepo.mapUsernameToEmail('chocolate'), equals('chocolate@benchmarkmms.com'));
      expect(authRepo.mapUsernameToEmail('cho'), equals('chocolate@benchmarkmms.com'));
    });
  });
}
