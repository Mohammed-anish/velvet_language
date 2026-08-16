import 'dart:io';
import 'dart:convert';
import 'dart:async' as dart_async;
import 'dart:typed_data';
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

    Runtime.bindPrimitive(Uri, 'URL');
    Runtime.bindPrimitive(Uri.parse('http://a').runtimeType, 'URL');

    Runtime.register("URL", (klass) {
      klass.defineStatic('parse', (args) => Uri.parse(args[0] as String));
      klass.getter('scheme', (args) => (args[0] as Uri).scheme);
      klass.getter('host', (args) => (args[0] as Uri).host);
      klass.getter('port', (args) => (args[0] as Uri).port);
      klass.getter('path', (args) => (args[0] as Uri).path);
      klass.getter('query', (args) => (args[0] as Uri).query);
      klass.getter('fragment', (args) => (args[0] as Uri).fragment);
      klass.getter('userInfo', (args) => (args[0] as Uri).userInfo);
      klass.getter('authority', (args) => (args[0] as Uri).authority);
    });

    Runtime.register("DNS", (klass) {
      klass.defineStatic('lookup', (args) async {
        var addresses = await InternetAddress.lookup(args[0] as String);
        return addresses.map((e) => e.address).toList();
      });
    });

    Runtime.bindPrimitive(Socket, 'Socket');
    Runtime.bindPrimitiveTypeCheck((obj) => obj is Socket, 'Socket');
    Runtime.bindPrimitive(ServerSocket, 'ServerSocket');
    Runtime.bindPrimitiveTypeCheck((obj) => obj is ServerSocket, 'ServerSocket');

    final socketBuffers = <Socket, List<List<int>>>{};
    final socketCompleters = <Socket, List<dart_async.Completer<List<int>>>>{};

    Runtime.register("Socket", (klass) {
      klass.defineStatic('connect', (args) async {
        var host = args[0] as String;
        var port = (args[1] as num).toInt();
        var socket = await Socket.connect(host, port);
        
        socketBuffers[socket] = [];
        socketCompleters[socket] = [];
        
        socket.listen((data) {
          if (socketCompleters[socket] != null && socketCompleters[socket]!.isNotEmpty) {
            var c = socketCompleters[socket]!.removeAt(0);
            c.complete(data);
          } else if (socketBuffers[socket] != null) {
            socketBuffers[socket]!.add(data);
          }
        }, onDone: () {
          if (socketCompleters[socket] != null) {
            for (var c in socketCompleters[socket]!) {
              c.complete(<int>[]);
            }
            socketCompleters[socket]!.clear();
          }
        });
        
        return socket;
      });

      klass.define('write', (args) async {
        var socket = args[0] as Socket;
        var data = args[1] as String;
        socket.write(data);
        await socket.flush();
        return null;
      });

      klass.define('read', (args) async {
        var socket = args[0] as Socket;
        var buffer = socketBuffers[socket]!;
        var completers = socketCompleters[socket]!;
        
        if (buffer.isNotEmpty) {
          return utf8.decode(buffer.removeAt(0), allowMalformed: true);
        }
        
        var completer = dart_async.Completer<List<int>>();
        completers.add(completer);
        var data = await completer.future;
        if (data.isEmpty) return "";
        return utf8.decode(data, allowMalformed: true);
      });

      klass.define('close', (args) async {
        var socket = args[0] as Socket;
        await socket.close();
        socketBuffers.remove(socket);
        socketCompleters.remove(socket);
        return null;
      });
    });

    final serverBuffers = <ServerSocket, List<Socket>>{};
    final serverCompleters = <ServerSocket, List<dart_async.Completer<Socket>>>{};

    Runtime.register("ServerSocket", (klass) {
      klass.defineStatic('bind', (args) async {
        var host = args[0] as String;
        var port = (args[1] as num).toInt();
        var server = await ServerSocket.bind(host, port);
        
        serverBuffers[server] = [];
        serverCompleters[server] = [];
        
        server.listen((socket) {
          // Initialize socket buffers just like connect
          socketBuffers[socket] = [];
          socketCompleters[socket] = [];
          
          socket.listen((data) {
            if (socketCompleters[socket] != null && socketCompleters[socket]!.isNotEmpty) {
              var c = socketCompleters[socket]!.removeAt(0);
              c.complete(data);
            } else if (socketBuffers[socket] != null) {
              socketBuffers[socket]!.add(data);
            }
          }, onDone: () {
            if (socketCompleters[socket] != null) {
              for (var c in socketCompleters[socket]!) {
                c.complete(<int>[]);
              }
              socketCompleters[socket]!.clear();
            }
          });

          if (serverCompleters[server]!.isNotEmpty) {
            var c = serverCompleters[server]!.removeAt(0);
            c.complete(socket);
          } else {
            serverBuffers[server]!.add(socket);
          }
        });
        
        return server;
      });

      klass.define('accept', (args) async {
        var server = args[0] as ServerSocket;
        var buffer = serverBuffers[server]!;
        var completers = serverCompleters[server]!;
        
        if (buffer.isNotEmpty) {
          return buffer.removeAt(0);
        }
        
        var completer = dart_async.Completer<Socket>();
        completers.add(completer);
        return await completer.future;
      });

      klass.define('close', (args) async {
        var server = args[0] as ServerSocket;
        await server.close();
        serverBuffers.remove(server);
        serverCompleters.remove(server);
        return null;
      });
    });

    Runtime.bindPrimitive(RawDatagramSocket, 'UDPSocket');
    Runtime.bindPrimitiveTypeCheck((obj) => obj is RawDatagramSocket, 'UDPSocket');

    final udpBuffers = <RawDatagramSocket, List<Datagram>>{};
    final udpCompleters = <RawDatagramSocket, List<dart_async.Completer<Datagram>>>{};

    Runtime.register("UDPSocket", (klass) {
      klass.defineStatic('bind', (args) async {
        var host = args[0] as String;
        var port = (args[1] as num).toInt();
        var socket = await RawDatagramSocket.bind(host, port);

        udpBuffers[socket] = [];
        udpCompleters[socket] = [];

        socket.listen((event) {
          if (event == RawSocketEvent.read) {
            var datagram = socket.receive();
            if (datagram != null) {
              if (udpCompleters[socket] != null && udpCompleters[socket]!.isNotEmpty) {
                var c = udpCompleters[socket]!.removeAt(0);
                c.complete(datagram);
              } else if (udpBuffers[socket] != null) {
                udpBuffers[socket]!.add(datagram);
              }
            }
          }
        }, onDone: () {
          if (udpCompleters[socket] != null) {
            for (var c in udpCompleters[socket]!) {
              // Return an empty datagram to unblock
              c.complete(Datagram(Uint8List(0), InternetAddress.anyIPv4, 0));
            }
            udpCompleters[socket]!.clear();
          }
        });

        return socket;
      });

      klass.define('send', (args) async {
        var socket = args[0] as RawDatagramSocket;
        var data = args[1] as String;
        var host = args[2] as String;
        var port = (args[3] as num).toInt();
        var addresses = await InternetAddress.lookup(host);
        if (addresses.isNotEmpty) {
          socket.send(utf8.encode(data), addresses.first, port);
        }
        return null;
      });

      klass.define('receive', (args) async {
        var socket = args[0] as RawDatagramSocket;
        var buffer = udpBuffers[socket]!;
        var completers = udpCompleters[socket]!;

        if (buffer.isNotEmpty) {
          var dg = buffer.removeAt(0);
          if (dg.data.isEmpty) return null; // Done
          return utf8.decode(dg.data, allowMalformed: true);
        }

        var completer = dart_async.Completer<Datagram>();
        completers.add(completer);
        var dg = await completer.future;
        if (dg.data.isEmpty) return null; // Done
        return utf8.decode(dg.data, allowMalformed: true);
      });

      klass.define('close', (args) async {
        var socket = args[0] as RawDatagramSocket;
        socket.close();
        udpBuffers.remove(socket);
        udpCompleters.remove(socket);
        return null;
      });
    });

    Runtime.register("HTTP", (klass) {
      klass.defineStatic('get', (args) async {
        var url = args[0] as String;
        var client = HttpClient();
        try {
          var request = await client.getUrl(Uri.parse(url));
          var response = await request.close();
          var responseBody = await response.transform(utf8.decoder).join();
          return responseBody;
        } finally {
          client.close();
        }
      });
      
      klass.defineStatic('post', (args) async {
        var url = args[0] as String;
        var body = args[1] as String;
        var client = HttpClient();
        try {
          var request = await client.postUrl(Uri.parse(url));
          request.headers.set('content-type', 'application/json');
          request.write(body);
          var response = await request.close();
          var responseBody = await response.transform(utf8.decoder).join();
          return responseBody;
        } finally {
          client.close();
        }
      });
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

    Runtime.register("Http", (klass) {
      klass.defineStatic('get', (args) async {
          var url = args[0] as String;
          var client = HttpClient();
          try {
            var request = await client.getUrl(Uri.parse(url));
            if (args.length > 1 && args[1] is KlassInstance && (args[1] as KlassInstance).name == 'Map') {
              var headersMap = (args[1] as KlassInstance).getField('_nativeData') as Map;
              headersMap.forEach((key, value) {
                request.headers.set(key.toString(), value.toString());
              });
            }
            var response = await request.close();
            var responseBody = await response.transform(utf8.decoder).join();
            return {
                'statusCode': response.statusCode,
                'body': responseBody
            };
          } catch (e) {
            return {'statusCode': 500, 'body': e.toString()};
          } finally {
            client.close();
          }
      });
      klass.defineStatic('post', (args) async {
          var url = args[0] as String;
          var body = args[1] as String;
          var client = HttpClient();
          try {
            var request = await client.postUrl(Uri.parse(url));
            if (args.length > 2 && args[2] is KlassInstance && (args[2] as KlassInstance).name == 'Map') {
              var headersMap = (args[2] as KlassInstance).getField('_nativeData') as Map;
              headersMap.forEach((key, value) {
                request.headers.set(key.toString(), value.toString());
              });
            } else {
              request.headers.set('content-type', 'application/json');
            }
            request.write(body);
            var response = await request.close();
            var responseBody = await response.transform(utf8.decoder).join();
            return {
                'statusCode': response.statusCode,
                'body': responseBody
            };
          } catch (e) {
            return {'statusCode': 500, 'body': e.toString()};
          } finally {
            client.close();
          }
      });
      klass.defineStatic('put', (args) async {
          var url = args[0] as String;
          var body = args[1] as String;
          var client = HttpClient();
          try {
            var request = await client.putUrl(Uri.parse(url));
            if (args.length > 2 && args[2] is KlassInstance && (args[2] as KlassInstance).name == 'Map') {
              var headersMap = (args[2] as KlassInstance).getField('_nativeData') as Map;
              headersMap.forEach((key, value) {
                request.headers.set(key.toString(), value.toString());
              });
            } else {
              request.headers.set('content-type', 'application/json');
            }
            request.write(body);
            var response = await request.close();
            var responseBody = await response.transform(utf8.decoder).join();
            return {
                'statusCode': response.statusCode,
                'body': responseBody
            };
          } catch (e) {
            return {'statusCode': 500, 'body': e.toString()};
          } finally {
            client.close();
          }
      });
      klass.defineStatic('delete', (args) async {
          var url = args[0] as String;
          var client = HttpClient();
          try {
            var request = await client.deleteUrl(Uri.parse(url));
            if (args.length > 1 && args[1] is KlassInstance && (args[1] as KlassInstance).name == 'Map') {
              var headersMap = (args[1] as KlassInstance).getField('_nativeData') as Map;
              headersMap.forEach((key, value) {
                request.headers.set(key.toString(), value.toString());
              });
            }
            var response = await request.close();
            var responseBody = await response.transform(utf8.decoder).join();
            return {
                'statusCode': response.statusCode,
                'body': responseBody
            };
          } catch (e) {
            return {'statusCode': 500, 'body': e.toString()};
          } finally {
            client.close();
          }
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
