import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'package:velvet_cmp/runtime/class_object.dart';
import 'package:velvet_cmp/runtime/runtime.dart';
import 'package:path/path.dart' as p;
import 'package:velvet_cmp/bindings/crypto/crypto_registry.dart';
import 'package:crypto/crypto.dart';

class OuterFunctionRegistry {
  static void register() {
    CryptoRegistry.register();
    
    Runtime.bindPrimitive(md5.runtimeType, 'Hash');
    Runtime.bindPrimitive(sha1.runtimeType, 'Hash');
    Runtime.bindPrimitive(sha256.runtimeType, 'Hash');
    Runtime.bindPrimitive(md5.convert([]).runtimeType, 'Digest');

    Runtime.register("CryptoHelper", (klass) {
      klass.defineStatic('getMd5', (args) => md5);
    });


    Runtime.register("Process", (klass) {
      klass.defineStatic('run', (args) {
          var res = Process.runSync(args[0] as String, (args[1] as KlassInstance).getField('_nativeData') as List<String>);
          return res.stdout.toString();
      });
      klass.defineStatic('args', (args) => Platform.executableArguments);
      klass.defineStatic('cwd', (args) => Directory.current.path);
      klass.defineStatic('sleep', (args) {
          sleep(Duration(milliseconds: (args[0] as num).toInt()));
          return null;
      });
      klass.defineStatic('exit', (args) => exit((args[0] as num).toInt()));
    });

    Runtime.register("Platform", (klass) {
      klass.defineStatic('env', (args) => Platform.environment[args[0] as String]);
      klass.defineStatic('os', (args) => Platform.operatingSystem);
    });

    Runtime.register("Path", (klass) {
      klass.defineStatic('join', (args) => p.join(args[0] as String, args[1] as String));
      klass.defineStatic('basename', (args) => p.basename(args[0] as String));
      klass.defineStatic('dirname', (args) => p.dirname(args[0] as String));
      klass.defineStatic('extension', (args) => p.extension(args[0] as String));
    });

    Runtime.register("DateTime", (klass) {
      klass.defineStatic('now', (args) => DateTime.now());
      klass.define('year', (args) => (args[0] as DateTime).year);
      klass.define('month', (args) => (args[0] as DateTime).month);
      klass.define('day', (args) => (args[0] as DateTime).day);
      klass.define('hour', (args) => (args[0] as DateTime).hour);
      klass.define('minute', (args) => (args[0] as DateTime).minute);
      klass.define('second', (args) => (args[0] as DateTime).second);
      klass.define('millisecondsSinceEpoch', (args) => (args[0] as DateTime).millisecondsSinceEpoch);
      klass.define('toIso8601String', (args) => (args[0] as DateTime).toIso8601String());
    });

    Runtime.register("NativeRandom", (klass) {
      klass.defineStatic('create', (args) => math.Random());
      klass.defineStatic('createWithSeed', (args) => math.Random((args[0] as num).toInt()));
      klass.defineStatic('nextDouble', (args) => (args[0] as math.Random).nextDouble());
      klass.defineStatic('nextInt', (args) => (args[0] as math.Random).nextInt((args[1] as num).toInt()));
      klass.defineStatic('nextBool', (args) => (args[0] as math.Random).nextBool());
    });

    Runtime.register("Object", (klass) {
      klass.define('string', (args) => args[0].toString());
      klass.define('hash', (args) => args[0].hashCode);
    });

    Runtime.register("Person", (klass) {
      klass.define("exec", (args) {
        return 'exec called';
      });
    });

    Runtime.register("File", (klass) {
      klass.define('create', (args) {
          var instance = args[0] as KlassInstance;
          File(instance.getField('path') as String).createSync(recursive: true);
          return null;
      });
      klass.define('delete', (args) {
          var instance = args[0] as KlassInstance;
          File(instance.getField('path') as String).deleteSync();
          return null;
      });
      klass.define('exists', (args) {
          var instance = args[0] as KlassInstance;
          return File(instance.getField('path') as String).existsSync();
      });
      klass.define('readAsString', (args) {
          var instance = args[0] as KlassInstance;
          return File(instance.getField('path') as String).readAsStringSync();
      });
      klass.define('writeAsString', (args) {
          var instance = args[0] as KlassInstance;
          File(instance.getField('path') as String).writeAsStringSync(args[1] as String);
          return null;
      });
      klass.define('appendAsString', (args) {
          var instance = args[0] as KlassInstance;
          File(instance.getField('path') as String).writeAsStringSync(args[1] as String, mode: FileMode.append);
          return null;
      });
    });

    List<String> _buildCurlArgs(String url, String method, dynamic headersMap, {String? body}) {
        List<String> args = ['-s', '-X', method, '-w', '\n%{http_code}', url];
        if (headersMap is KlassInstance && headersMap.name == 'Map') {
            var rawMap = headersMap.getField('_nativeData') as Map;
            rawMap.forEach((key, value) {
                args.addAll(['-H', '$key: $value']);
            });
        }
        if (body != null) {
            args.addAll(['-d', body]);
        }
        return args;
    }

    Map<String, dynamic> _parseCurlResponse(ProcessResult res) {
        var parts = res.stdout.toString().split('\n');
        var statusCodeStr = parts.removeLast();
        var body = parts.join('\n');
        return {
            'statusCode': int.tryParse(statusCodeStr) ?? 500,
            'body': body
        };
    }

    Runtime.register("Http", (klass) {
      klass.define('get', (args) {
          var res = Process.runSync('curl', _buildCurlArgs(args[1] as String, 'GET', args[2]));
          return _parseCurlResponse(res);
      });
      klass.define('post', (args) {
          var res = Process.runSync('curl', _buildCurlArgs(args[1] as String, 'POST', args[3], body: args[2] as String));
          return _parseCurlResponse(res);
      });
      klass.define('put', (args) {
          var res = Process.runSync('curl', _buildCurlArgs(args[1] as String, 'PUT', args[3], body: args[2] as String));
          return _parseCurlResponse(res);
      });
      klass.define('delete', (args) {
          var res = Process.runSync('curl', _buildCurlArgs(args[1] as String, 'DELETE', args[2]));
          return _parseCurlResponse(res);
      });
    });

    Runtime.register("JSON", (klass) {
      klass.define('stringify', (args) {
          var obj = args[1];
          return jsonEncode(obj, toEncodable: (e) {
              if (e is KlassInstance) {
                  if (e.name == 'Map' || e.name == 'List') {
                      return e.getField('_nativeData');
                  }
                  return e.fields;
              }
              return e.toString();
          });
      });
      klass.define('parse', (args) {
          return jsonDecode(args[1] as String);
      });
    });

    Runtime.register("List", (klass) {
      klass.define('add', (args) {
        var instance = args[0] as KlassInstance;
        var list = instance.getField('_nativeData') as List;
        list.add(args[1]);
        return null;
      });
      klass.define('get', (args) {
        var instance = args[0] as KlassInstance;
        var list = instance.getField('_nativeData') as List;
        return list[args[1]];
      });
      klass.define('set', (args) {
        var instance = args[0] as KlassInstance;
        var list = instance.getField('_nativeData') as List;
        list[args[1]] = args[2];
        return null;
      });
      klass.define('length', (args) {
        var instance = args[0] as KlassInstance;
        var list = instance.getField('_nativeData') as List;
        return list.length;
      });
    });

    Runtime.register("Map", (klass) {
      klass.define('put', (args) {
        var instance = args[0] as KlassInstance;
        var map = instance.getField('_nativeData') as Map;
        map[args[1]] = args[2];
        return null;
      });
      klass.define('get', (args) {
        var instance = args[0] as KlassInstance;
        var map = instance.getField('_nativeData') as Map;
        return map[args[1]];
      });
    });

    Runtime.register("String", (klass) {
      klass.define('toUpperCase', (args) => (args[0] as String).toUpperCase());
      klass.define('toLowerCase', (args) => (args[0] as String).toLowerCase());
      klass.define('length', (args) => (args[0] as String).length);
      klass.define('trim', (args) => (args[0] as String).trim());
      klass.define('split', (args) {
          var str = args[0] as String;
          return str.split(args[1] as String);
      });
      klass.define('replace', (args) => (args[0] as String).replaceAll(args[1] as String, args[2] as String));
      klass.define('contains', (args) => (args[0] as String).contains(args[1] as String));
      klass.define('startsWith', (args) => (args[0] as String).startsWith(args[1] as String));
      klass.define('endsWith', (args) => (args[0] as String).endsWith(args[1] as String));
      klass.define('substring', (args) => (args[0] as String).substring((args[1] as num).toInt(), (args[2] as num).toInt()));
      klass.define('isEmpty', (args) => (args[0] as String).isEmpty);
    });

    Runtime.register("Number", (klass) {
      klass.define('toString', (args) => (args[0] as num).toString());
      klass.define('toInt', (args) => (args[0] as num).toInt());
      klass.define('toDouble', (args) => (args[0] as num).toDouble());
      klass.define('round', (args) => (args[0] as num).round());
      klass.define('floor', (args) => (args[0] as num).floor());
      klass.define('ceil', (args) => (args[0] as num).ceil());
      klass.define('abs', (args) => (args[0] as num).abs());
    });
  }
}
