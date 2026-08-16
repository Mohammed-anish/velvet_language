import 'dart:typed_data';
import 'package:velvet_cmp/runtime/runtime.dart';
import 'package:velvet_cmp/runtime/class_object.dart';
import 'package:crypto/crypto.dart';
import 'package:crypto/src/hash_sink.dart';
import 'package:crypto/src/digest_sink.dart';
import 'package:crypto/src/hash.dart';
import 'package:crypto/src/sha512_fastsinks.dart';
import 'package:crypto/src/hmac.dart';
import 'package:crypto/src/sha512_slowsinks.dart';

class CryptoRegistry {
  static void register() {
    Runtime.register('Digest', (klass) {
      klass.define('toString', (args) {
        return (args[0] as Digest).toString();
      });
    });
    Runtime.register('HashSink', (klass) {
      klass.define('updateHash', (args) {
        return (args[0] as HashSink).updateHash(args[1] as Uint32List);
      });
      klass.define('add', (args) {
        return (args[0] as HashSink).add(args[1] as List<int>);
      });
      klass.define('close', (args) {
        return (args[0] as HashSink).close();
      });
    });
    Runtime.register('DigestSink', (klass) {
      klass.define('add', (args) {
        return (args[0] as DigestSink).add(args[1] as Digest);
      });
      klass.define('close', (args) {
        return (args[0] as DigestSink).close();
      });
    });
    Runtime.register('Hash', (klass) {
      klass.define('convert', (args) {
        return (args[0] as Hash).convert(((args[1] as KlassInstance).getField('_nativeData') as List).cast<int>());
      });
      klass.define('startChunkedConversion', (args) {
        return (args[0] as Hash).startChunkedConversion(args[1] as Sink<Digest>);
      });
    });
    Runtime.register('Sha384Sink', (klass) {
    });
    Runtime.register('Sha512Sink', (klass) {
    });
    Runtime.register('Sha512224Sink', (klass) {
    });
    Runtime.register('Sha512256Sink', (klass) {
    });
    Runtime.register('Hmac', (klass) {
      klass.define('convert', (args) {
        return (args[0] as Hmac).convert(args[1] as List<int>);
      });
      klass.define('startChunkedConversion', (args) {
        return (args[0] as Hmac).startChunkedConversion(args[1] as Sink<Digest>);
      });
    });
    Runtime.register('Sha384Sink', (klass) {
    });
    Runtime.register('Sha512Sink', (klass) {
    });
    Runtime.register('Sha512224Sink', (klass) {
    });
    Runtime.register('Sha512256Sink', (klass) {
    });
  }
}
