import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/core/encryption/sharing_keys.dart';

void main() {
  final sharing = SharingKeys();

  test('ECDH shared secrets match between two independent keypairs', () async {
    final ownerMaster = List<int>.generate(32, (i) => i);
    final recipientMaster = List<int>.generate(32, (i) => 255 - i);
    final ownerPair = await sharing.keyPairFromMasterKey(ownerMaster);
    final recipientPair = await sharing.keyPairFromMasterKey(recipientMaster);
    final ownerPub = await sharing.publicKeyOf(ownerPair);
    final recipientPub = await sharing.publicKeyOf(recipientPair);

    final s1 = await sharing.sharedSecret(myKeyPair: ownerPair, remotePublicKey: recipientPub);
    final s2 = await sharing.sharedSecret(myKeyPair: recipientPair, remotePublicKey: ownerPub);

    expect(await s1.extractBytes(), equals(await s2.extractBytes()));
  });

  test('same master key produces same public key', () async {
    final master = List<int>.generate(32, (i) => 42 + i);
    final pairA = await sharing.keyPairFromMasterKey(master);
    final pairB = await sharing.keyPairFromMasterKey(master);
    expect(await sharing.publicKeyOf(pairA), equals(await sharing.publicKeyOf(pairB)));
  });
}
