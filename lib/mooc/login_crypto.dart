import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/export.dart';

const _sm4Key = [
  0xbc,
  0x60,
  0xb8,
  0xb9,
  0xe4,
  0xff,
  0xef,
  0xfa,
  0x21,
  0x9e,
  0x5a,
  0xd7,
  0x7f,
  0x11,
  0xf9,
  0xe2,
];

const _sm4Sbox = [
  0xd6,
  0x90,
  0xe9,
  0xfe,
  0xcc,
  0xe1,
  0x3d,
  0xb7,
  0x16,
  0xb6,
  0x14,
  0xc2,
  0x28,
  0xfb,
  0x2c,
  0x05,
  0x2b,
  0x67,
  0x9a,
  0x76,
  0x2a,
  0xbe,
  0x04,
  0xc3,
  0xaa,
  0x44,
  0x13,
  0x26,
  0x49,
  0x86,
  0x06,
  0x99,
  0x9c,
  0x42,
  0x50,
  0xf4,
  0x91,
  0xef,
  0x98,
  0x7a,
  0x33,
  0x54,
  0x0b,
  0x43,
  0xed,
  0xcf,
  0xac,
  0x62,
  0xe4,
  0xb3,
  0x1c,
  0xa9,
  0xc9,
  0x08,
  0xe8,
  0x95,
  0x80,
  0xdf,
  0x94,
  0xfa,
  0x75,
  0x8f,
  0x3f,
  0xa6,
  0x47,
  0x07,
  0xa7,
  0xfc,
  0xf3,
  0x73,
  0x17,
  0xba,
  0x83,
  0x59,
  0x3c,
  0x19,
  0xe6,
  0x85,
  0x4f,
  0xa8,
  0x68,
  0x6b,
  0x81,
  0xb2,
  0x71,
  0x64,
  0xda,
  0x8b,
  0xf8,
  0xeb,
  0x0f,
  0x4b,
  0x70,
  0x56,
  0x9d,
  0x35,
  0x1e,
  0x24,
  0x0e,
  0x5e,
  0x63,
  0x58,
  0xd1,
  0xa2,
  0x25,
  0x22,
  0x7c,
  0x3b,
  0x01,
  0x21,
  0x78,
  0x87,
  0xd4,
  0x00,
  0x46,
  0x57,
  0x9f,
  0xd3,
  0x27,
  0x52,
  0x4c,
  0x36,
  0x02,
  0xe7,
  0xa0,
  0xc4,
  0xc8,
  0x9e,
  0xea,
  0xbf,
  0x8a,
  0xd2,
  0x40,
  0xc7,
  0x38,
  0xb5,
  0xa3,
  0xf7,
  0xf2,
  0xce,
  0xf9,
  0x61,
  0x15,
  0xa1,
  0xe0,
  0xae,
  0x5d,
  0xa4,
  0x9b,
  0x34,
  0x1a,
  0x55,
  0xad,
  0x93,
  0x32,
  0x30,
  0xf5,
  0x8c,
  0xb1,
  0xe3,
  0x1d,
  0xf6,
  0xe2,
  0x2e,
  0x82,
  0x66,
  0xca,
  0x60,
  0xc0,
  0x29,
  0x23,
  0xab,
  0x0d,
  0x53,
  0x4e,
  0x6f,
  0xd5,
  0xdb,
  0x37,
  0x45,
  0xde,
  0xfd,
  0x8e,
  0x2f,
  0x03,
  0xff,
  0x6a,
  0x72,
  0x6d,
  0x6c,
  0x5b,
  0x51,
  0x8d,
  0x1b,
  0xaf,
  0x92,
  0xbb,
  0xdd,
  0xbc,
  0x7f,
  0x11,
  0xd9,
  0x5c,
  0x41,
  0x1f,
  0x10,
  0x5a,
  0xd8,
  0x0a,
  0xc1,
  0x31,
  0x88,
  0xa5,
  0xcd,
  0x7b,
  0xbd,
  0x2d,
  0x74,
  0xd0,
  0x12,
  0xb8,
  0xe5,
  0xb4,
  0xb0,
  0x89,
  0x69,
  0x97,
  0x4a,
  0x0c,
  0x96,
  0x77,
  0x7e,
  0x65,
  0xb9,
  0xf1,
  0x09,
  0xc5,
  0x6e,
  0xc6,
  0x84,
  0x18,
  0xf0,
  0x7d,
  0xec,
  0x3a,
  0xdc,
  0x4d,
  0x20,
  0x79,
  0xee,
  0x5f,
  0x3e,
  0xd7,
  0xcb,
  0x39,
  0x48,
];

const _sm4Fk = [0xa3b1bac6, 0x56aa3350, 0x677d9197, 0xb27022dc];
const _mask32 = 0xffffffff;
const _rsaPublicKey =
    'MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQC5gsH+AA4XWONB5TDcUd+xCz7e'
    'jOFHZKlcZDx+pF1i7Gsvi1vjyJoQhRtRSn950x498VUkx7rUxg1/ScBVfrRxQOZ8'
    'xFBye3pjAzfb22+RCuYApSVpJ3OO3KsEuKExftz9oFBv3ejxPlYc5yq7YiBO8XlT'
    'nQN0Sa4R4qhPO3I2MQIDAQAB';

/// Encrypts the login protocol's JSON request envelope as the official web
/// client does.
String encryptMoocParams(Map<String, Object?> value) =>
    _hex(_sm4EcbPkcs7(utf8.encode(jsonEncode(value)), _sm4Key));

String encryptMoocPassword(String password) {
  final outer =
      ASN1Parser(base64Decode(_rsaPublicKey)).nextObject() as ASN1Sequence;
  final bits = outer.elements![1] as ASN1BitString;
  final sequence =
      ASN1Parser(Uint8List.fromList(bits.stringValues!)).nextObject()
          as ASN1Sequence;
  final modulus = (sequence.elements![0] as ASN1Integer).integer!;
  final exponent = (sequence.elements![1] as ASN1Integer).integer!;
  final random = FortunaRandom()..seed(KeyParameter(_randomBytes(32)));
  final cipher = PKCS1Encoding(RSAEngine())
    ..init(
      true,
      ParametersWithRandom(
        PublicKeyParameter<RSAPublicKey>(RSAPublicKey(modulus, exponent)),
        random,
      ),
    );
  return base64Encode(cipher.process(utf8.encode(password)));
}

/// Solves the server's short VDF challenge off the UI isolate.
Future<Map<String, Object>> solveMoocProof(Map<String, dynamic> info) async {
  if (info['hashFunc'] != 'VDF_FUNCTION') {
    throw const FormatException('MOOC 登录验证方式不受支持。');
  }
  final values = Map<String, dynamic>.of(info);
  return Isolate.run(() => _solveMoocProof(values));
}

String moocProofSignature(String value, int seed) =>
    '${_murmur3(utf8.encode(value), seed & _mask32)}';

Map<String, Object> _solveMoocProof(Map<String, dynamic> info) {
  final sid = info['sid'];
  final args = info['args'];
  if (sid is! String || sid.isEmpty || args is! Map<String, dynamic>) {
    throw const FormatException('MOOC 登录验证数据格式不正确。');
  }
  final modulusText = _hexText(args['mod']);
  final initialText = _hexText(args['x']);
  final puzzle = args['puzzle'];
  final target = _boundedInt(args['t'], minimum: 0, maximum: 10000000);
  final minTime = _boundedInt(info['minTime'], minimum: 0, maximum: 30000);
  final maxTime = _boundedInt(
    info['maxTime'],
    minimum: minTime,
    maximum: 30000,
  );
  if (puzzle is! String || puzzle.isEmpty) {
    throw const FormatException('MOOC 登录验证数据缺少题目。');
  }

  final modulus = BigInt.parse(modulusText, radix: 16);
  var value = BigInt.parse(initialText, radix: 16);
  if (modulus <= BigInt.zero || value >= modulus) {
    throw const FormatException('MOOC 登录验证数据超出有效范围。');
  }

  final watch = Stopwatch()..start();
  var count = 0;
  while (count < target || watch.elapsedMilliseconds < minTime) {
    value = (value * value) % modulus;
    count++;
    if (watch.elapsedMilliseconds > maxTime) break;
  }
  final elapsed = watch.elapsedMilliseconds;
  final x = value.toRadixString(16);
  final encoded = 'runTimes=$count&spendTime=$elapsed&t=$count&x=$x';
  return {
    'puzzle': puzzle,
    'spendTime': elapsed,
    'runTimes': count,
    'sid': sid,
    'args': jsonEncode({
      'x': x,
      't': count,
      'sign': _murmur3(utf8.encode(encoded), count & _mask32),
    }),
  };
}

Uint8List _sm4EcbPkcs7(List<int> source, List<int> key) {
  if (key.length != 16) throw ArgumentError.value(key, 'key');
  final padding = 16 - source.length % 16;
  final input = Uint8List.fromList([
    ...source,
    ...List.filled(padding, padding),
  ]);
  final roundKeys = _sm4RoundKeys(key);
  final output = Uint8List(input.length);
  for (var offset = 0; offset < input.length; offset += 16) {
    final block = _sm4Crypt(input.sublist(offset, offset + 16), roundKeys);
    output.setRange(offset, offset + 16, block);
  }
  return output;
}

List<int> _sm4RoundKeys(List<int> key) {
  final state = List<int>.filled(36, 0);
  for (var index = 0; index < 4; index++) {
    state[index] = _readWord(key, index * 4) ^ _sm4Fk[index];
  }
  final roundKeys = List<int>.filled(32, 0);
  for (var index = 0; index < 32; index++) {
    var roundConstant = 0;
    for (var byte = 0; byte < 4; byte++) {
      roundConstant = (roundConstant << 8) | ((index * 4 + byte) * 7 & 0xff);
    }
    final next =
        state[index] ^
        _linearKeyTransform(
          _substitute(
            state[index + 1] ^
                state[index + 2] ^
                state[index + 3] ^
                roundConstant,
          ),
        );
    state[index + 4] = next;
    roundKeys[index] = next;
  }
  return roundKeys;
}

Uint8List _sm4Crypt(List<int> block, List<int> roundKeys) {
  final state = List<int>.filled(36, 0);
  for (var index = 0; index < 4; index++) {
    state[index] = _readWord(block, index * 4);
  }
  for (var index = 0; index < 32; index++) {
    final key = roundKeys[index];
    state[index + 4] =
        state[index] ^
        _linearTransform(
          _substitute(
            state[index + 1] ^ state[index + 2] ^ state[index + 3] ^ key,
          ),
        );
  }
  final output = Uint8List(16);
  for (var index = 0; index < 4; index++) {
    _writeWord(output, index * 4, state[35 - index]);
  }
  return output;
}

int _substitute(int value) {
  final b0 = _sm4Sbox[(value >> 24) & 0xff];
  final b1 = _sm4Sbox[(value >> 16) & 0xff];
  final b2 = _sm4Sbox[(value >> 8) & 0xff];
  final b3 = _sm4Sbox[value & 0xff];
  return (b0 << 24) | (b1 << 16) | (b2 << 8) | b3;
}

int _linearTransform(int value) =>
    value ^
    _rotateLeft(value, 2) ^
    _rotateLeft(value, 10) ^
    _rotateLeft(value, 18) ^
    _rotateLeft(value, 24);

int _linearKeyTransform(int value) =>
    value ^ _rotateLeft(value, 13) ^ _rotateLeft(value, 23);

int _rotateLeft(int value, int shift) =>
    ((value << shift) | ((value & _mask32) >> (32 - shift))) & _mask32;

int _readWord(List<int> bytes, int offset) =>
    (bytes[offset] << 24) |
    (bytes[offset + 1] << 16) |
    (bytes[offset + 2] << 8) |
    bytes[offset + 3];

void _writeWord(Uint8List bytes, int offset, int value) {
  bytes[offset] = (value >> 24) & 0xff;
  bytes[offset + 1] = (value >> 16) & 0xff;
  bytes[offset + 2] = (value >> 8) & 0xff;
  bytes[offset + 3] = value & 0xff;
}

Uint8List _randomBytes(int length) {
  final random = Random.secure();
  return Uint8List.fromList(
    List<int>.generate(length, (_) => random.nextInt(256)),
  );
}

String _hexText(Object? value) {
  if (value is! String ||
      value.isEmpty ||
      value.length.isOdd ||
      !RegExp(r'^[0-9a-fA-F]+$').hasMatch(value)) {
    throw const FormatException('MOOC 登录验证数据格式不正确。');
  }
  return value;
}

int _boundedInt(Object? value, {required int minimum, required int maximum}) {
  final parsed = switch (value) {
    int value => value,
    num value when value == value.truncate() => value.toInt(),
    String value => int.tryParse(value),
    _ => null,
  };
  if (parsed == null || parsed < minimum || parsed > maximum) {
    throw const FormatException('MOOC 登录验证参数超出有效范围。');
  }
  return parsed;
}

String _hex(List<int> bytes) =>
    bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();

int _murmur3(List<int> bytes, int seed) {
  var hash = seed & _mask32;
  var offset = 0;
  while (offset + 4 <= bytes.length) {
    var value =
        bytes[offset] |
        (bytes[offset + 1] << 8) |
        (bytes[offset + 2] << 16) |
        (bytes[offset + 3] << 24);
    offset += 4;
    value = (value * 0xcc9e2d51) & _mask32;
    value = _rotateLeft(value, 15);
    value = (value * 0x1b873593) & _mask32;
    hash ^= value;
    hash = _rotateLeft(hash, 13);
    hash = (hash * 5 + 0xe6546b64) & _mask32;
  }
  var tail = 0;
  final remainder = bytes.length - offset;
  if (remainder == 3) {
    tail ^= bytes[offset + 2] << 16;
  }
  if (remainder >= 2) {
    tail ^= bytes[offset + 1] << 8;
  }
  if (remainder >= 1) {
    tail ^= bytes[offset];
    tail = (tail * 0xcc9e2d51) & _mask32;
    tail = _rotateLeft(tail, 15);
    tail = (tail * 0x1b873593) & _mask32;
    hash ^= tail;
  }
  hash ^= bytes.length;
  hash ^= hash >> 16;
  hash = (hash * 0x85ebca6b) & _mask32;
  hash ^= hash >> 13;
  hash = (hash * 0xc2b2ae35) & _mask32;
  hash ^= hash >> 16;
  return hash & _mask32;
}
