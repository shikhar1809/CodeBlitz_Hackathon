import 'package:flutter_test/flutter_test.dart';
import 'package:winger/features/family/family_crypto.dart';

void main() {
  // The same vector is produced by vault/src/family_crypto.js: phone, Home
  // Vault and family portal must derive identical keys from one code.
  const code = '0123456789ABCDEFGHJKMNPQRS';

  test('decodes the family code like the Vault does', () {
    final hex = FamilyCrypto.decode(code)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    expect(hex, '00443214c74254b635cf84653a56d7c6');
    // A generated code always round-trips (its 2 spare bits are zero).
    final fresh = FamilyCrypto.newCode();
    expect(FamilyCrypto.encode(FamilyCrypto.decode(fresh)), fresh);
    expect(FamilyCrypto.decode(FamilyCrypto.pretty(code).toLowerCase()), FamilyCrypto.decode(code));
  });

  test('derives the same household id, token and key as the Vault', () async {
    final k = await FamilyCrypto.derive(code);
    expect(k.householdId, 'c2d7b115c9d3a4fd');
    expect(k.accessToken, 'Gh7UsedNN59kUjaIt2J-RuNLDA4GLkNzwnl2i-b0D5E');
    expect(
      k.dataKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      '960bcdb0c0762257fbb39523b755ff8bce58a795fa45fd56f58dbba784939303',
    );
  });

  test('seal and open round-trip; the wrong record kind cannot open it', () async {
    final k = await FamilyCrypto.derive(FamilyCrypto.newCode());
    final box = await FamilyCrypto.seal(k.dataKey, 'Metformin 500', 'h:snapshot');
    expect(await FamilyCrypto.open(k.dataKey, box, 'h:snapshot'), 'Metformin 500');
    expect(() => FamilyCrypto.open(k.dataKey, box, 'h:event'), throwsA(anything));
  });

  test('bad codes are refused', () {
    expect(() => FamilyCrypto.decode('hello'), throwsFormatException);
    expect(FamilyCrypto.newCode().length, 26);
  });
}
