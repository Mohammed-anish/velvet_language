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
import 'package:velvet_cmp/runtime/ffi_bridge.dart';
import 'package:mime/mime.dart';
import 'package:velvet_cmp/lexer/tokenizer.dart';
import 'package:velvet_cmp/parser/parser.dart';
import 'package:velvet_cmp/core/vml_dom.dart';
import 'package:velvet_cmp/parser/ast_classes.dart';

class OuterFunctionRegistry {
  static void register() {
    CryptoRegistry.register();
    FFIBridgeRegistry.register();

    Runtime.bindPrimitive(md5.runtimeType, 'Hash');
    Runtime.bindPrimitive(sha1.runtimeType, 'Hash');
    Runtime.bindPrimitive(sha256.runtimeType, 'Hash');
    Runtime.bindPrimitive(md5.convert([]).runtimeType, 'Digest');

    Runtime.register("CryptoHelper", (klass) {
      klass.defineStatic('getMd5', (args) => md5);
    });

    Runtime.bindPrimitive(Uri, 'URL');
    Runtime.bindPrimitive(Uri.parse('http://a').runtimeType, 'URL');
    Runtime.bindPrimitive(bool, 'Boolean');

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
    Runtime.bindPrimitiveTypeCheck(
        (obj) => obj is ServerSocket, 'ServerSocket');
    Runtime.bindPrimitive(Uint8List, 'Buffer');
    Runtime.bindPrimitiveTypeCheck((obj) => obj is Uint8List, 'Buffer');

    Runtime.register("Buffer", (klass) {
      klass.defineStatic('alloc', (args) {
        return Uint8List((args[0] as num).toInt());
      });
      klass.defineStatic('fromUtf8', (args) {
        return Uint8List.fromList(utf8.encode(args[0] as String));
      });
      klass.define('toUtf8', (args) {
        var buffer = args[0] as Uint8List;
        return utf8.decode(buffer, allowMalformed: true);
      });
      klass.define('length', (args) {
        var buffer = args[0] as Uint8List;
        return buffer.length;
      });
      klass.define('get', (args) {
        var buffer = args[0] as Uint8List;
        return buffer[(args[1] as num).toInt()];
      });
      klass.define('set', (args) {
        var buffer = args[0] as Uint8List;
        buffer[(args[1] as num).toInt()] = (args[2] as num).toInt();
        return null;
      });
    });

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
          if (socketCompleters[socket] != null &&
              socketCompleters[socket]!.isNotEmpty) {
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

      klass.define('writeAsBytes', (args) async {
        var socket = args[0] as Socket;
        var data = args[1] as Uint8List;
        socket.add(data);
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

      klass.define('readAsBytes', (args) async {
        var socket = args[0] as Socket;
        var buffer = socketBuffers[socket]!;
        var completers = socketCompleters[socket]!;

        if (buffer.isNotEmpty) {
          return Uint8List.fromList(buffer.removeAt(0));
        }

        var completer = dart_async.Completer<List<int>>();
        completers.add(completer);
        var data = await completer.future;
        return Uint8List.fromList(data);
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
    final serverCompleters =
        <ServerSocket, List<dart_async.Completer<Socket>>>{};

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
            if (socketCompleters[socket] != null &&
                socketCompleters[socket]!.isNotEmpty) {
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
    Runtime.bindPrimitiveTypeCheck(
        (obj) => obj is RawDatagramSocket, 'UDPSocket');

    final udpBuffers = <RawDatagramSocket, List<Datagram>>{};
    final udpCompleters =
        <RawDatagramSocket, List<dart_async.Completer<Datagram>>>{};

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
              if (udpCompleters[socket] != null &&
                  udpCompleters[socket]!.isNotEmpty) {
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

      klass.define('sendBytes', (args) async {
        var socket = args[0] as RawDatagramSocket;
        var data = args[1] as Uint8List;
        var host = args[2] as String;
        var port = (args[3] as num).toInt();
        var addresses = await InternetAddress.lookup(host);
        if (addresses.isNotEmpty) {
          socket.send(data, addresses.first, port);
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

      klass.define('receiveBytes', (args) async {
        var socket = args[0] as RawDatagramSocket;
        var buffer = udpBuffers[socket]!;
        var completers = udpCompleters[socket]!;

        if (buffer.isNotEmpty) {
          var dg = buffer.removeAt(0);
          if (dg.data.isEmpty) return null; // Done
          return Uint8List.fromList(dg.data);
        }

        var completer = dart_async.Completer<Datagram>();
        completers.add(completer);
        var dg = await completer.future;
        if (dg.data.isEmpty) return null; // Done
        return Uint8List.fromList(dg.data);
      });

      klass.define('close', (args) async {
        var socket = args[0] as RawDatagramSocket;
        socket.close();
        udpBuffers.remove(socket);
        udpCompleters.remove(socket);
        return null;
      });
    });

    Runtime.bindPrimitive(WebSocket, 'WebSocketClient');
    Runtime.bindPrimitiveTypeCheck(
        (obj) => obj is WebSocket, 'WebSocketClient');

    final wsBuffers = <WebSocket, List<dynamic>>{};
    final wsCompleters = <WebSocket, List<dart_async.Completer<dynamic>>>{};

    Runtime.register("WebSocketClient", (klass) {
      klass.defineStatic('connect', (args) async {
        var url = args[0] as String;
        var ws = await WebSocket.connect(url);

        wsBuffers[ws] = [];
        wsCompleters[ws] = [];

        ws.listen((data) {
          if (wsCompleters[ws] != null && wsCompleters[ws]!.isNotEmpty) {
            var c = wsCompleters[ws]!.removeAt(0);
            c.complete(data);
          } else if (wsBuffers[ws] != null) {
            wsBuffers[ws]!.add(data);
          }
        }, onDone: () {
          if (wsCompleters[ws] != null) {
            for (var c in wsCompleters[ws]!) {
              c.complete(null);
            }
            wsCompleters[ws]!.clear();
          }
        });

        return ws;
      });

      klass.define('send', (args) async {
        var ws = args[0] as WebSocket;
        ws.add(args[1]); // Can be String or Uint8List
        return null;
      });

      klass.define('receive', (args) async {
        var ws = args[0] as WebSocket;
        var buffer = wsBuffers[ws]!;
        var completers = wsCompleters[ws]!;

        if (buffer.isNotEmpty) {
          var data = buffer.removeAt(0);
          return data is List<int> ? Uint8List.fromList(data) : data;
        }

        var completer = dart_async.Completer<dynamic>();
        completers.add(completer);
        var data = await completer.future;
        if (data == null) return null;
        return data is List<int> ? Uint8List.fromList(data) : data;
      });

      klass.define('close', (args) async {
        var ws = args[0] as WebSocket;
        await ws.close();
        wsBuffers.remove(ws);
        wsCompleters.remove(ws);
        return null;
      });
    });

    Runtime.bindPrimitive(HttpServer, 'WebSocketServer');
    Runtime.bindPrimitiveTypeCheck(
        (obj) => obj is HttpServer, 'WebSocketServer');

    final wsServerBuffers = <HttpServer, List<WebSocket>>{};
    final wsServerCompleters =
        <HttpServer, List<dart_async.Completer<WebSocket>>>{};

    Runtime.register("WebSocketServer", (klass) {
      klass.defineStatic('bind', (args) async {
        var host = args[0] as String;
        var port = (args[1] as num).toInt();
        var server = await HttpServer.bind(host, port);

        wsServerBuffers[server] = [];
        wsServerCompleters[server] = [];

        server.listen((HttpRequest request) {
          if (WebSocketTransformer.isUpgradeRequest(request)) {
            WebSocketTransformer.upgrade(request).then((WebSocket ws) {
              // Setup buffer for the incoming WebSocket so the user can use it immediately!
              wsBuffers[ws] = [];
              wsCompleters[ws] = [];

              ws.listen((data) {
                if (wsCompleters[ws] != null && wsCompleters[ws]!.isNotEmpty) {
                  var c = wsCompleters[ws]!.removeAt(0);
                  c.complete(data);
                } else if (wsBuffers[ws] != null) {
                  wsBuffers[ws]!.add(data);
                }
              }, onDone: () {
                if (wsCompleters[ws] != null) {
                  for (var c in wsCompleters[ws]!) {
                    c.complete(null);
                  }
                  wsCompleters[ws]!.clear();
                }
              });

              if (wsServerCompleters[server]!.isNotEmpty) {
                var c = wsServerCompleters[server]!.removeAt(0);
                c.complete(ws);
              } else {
                wsServerBuffers[server]!.add(ws);
              }
            });
          } else {
            // Not a WebSocket request, close it
            request.response.statusCode = HttpStatus.badRequest;
            request.response.close();
          }
        });

        return server;
      });

      klass.define('accept', (args) async {
        var server = args[0] as HttpServer;
        var buffer = wsServerBuffers[server]!;
        var completers = wsServerCompleters[server]!;

        if (buffer.isNotEmpty) {
          return buffer.removeAt(0);
        }

        var completer = dart_async.Completer<WebSocket>();
        completers.add(completer);
        return await completer.future;
      });

      klass.define('close', (args) async {
        var server = args[0] as HttpServer;
        await server.close();
        wsServerBuffers.remove(server);
        wsServerCompleters.remove(server);
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
        var res = Process.runSync(args[0] as String,
            (args[1] as KlassInstance).getField('_nativeData') as List<String>);
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
      klass.defineStatic(
          'env', (args) => Platform.environment[args[0] as String]);
      klass.defineStatic('os', (args) => Platform.operatingSystem);
    });

    Runtime.register("Path", (klass) {
      klass.defineStatic(
          'join', (args) => p.join(args[0] as String, args[1] as String));
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
      klass.define('millisecondsSinceEpoch',
          (args) => (args[0] as DateTime).millisecondsSinceEpoch);
      klass.define(
          'toIso8601String', (args) => (args[0] as DateTime).toIso8601String());
    });

    Runtime.register("NativeRandom", (klass) {
      klass.defineStatic('create', (args) => math.Random());
      klass.defineStatic(
          'createWithSeed', (args) => math.Random((args[0] as num).toInt()));
      klass.defineStatic(
          'nextDouble', (args) => (args[0] as math.Random).nextDouble());
      klass.defineStatic('nextInt',
          (args) => (args[0] as math.Random).nextInt((args[1] as num).toInt()));
      klass.defineStatic(
          'nextBool', (args) => (args[0] as math.Random).nextBool());
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
      klass.define('create', (args) async {
        var instance = args[0] as KlassInstance;
        await File(instance.getField('path') as String).create(recursive: true);
        return null;
      });
      klass.define('delete', (args) async {
        var instance = args[0] as KlassInstance;
        await File(instance.getField('path') as String).delete();
        return null;
      });
      klass.define('exists', (args) async {
        var instance = args[0] as KlassInstance;
        return await File(instance.getField('path') as String).exists();
      });
      klass.define('readAsString', (args) async {
        var instance = args[0] as KlassInstance;
        return await File(instance.getField('path') as String).readAsString();
      });
      klass.define('writeAsString', (args) async {
        var instance = args[0] as KlassInstance;
        await File(instance.getField('path') as String)
            .writeAsString(args[1] as String);
        return null;
      });
      klass.define('appendAsString', (args) async {
        var instance = args[0] as KlassInstance;
        await File(instance.getField('path') as String)
            .writeAsString(args[1] as String, mode: FileMode.append);
        return null;
      });
      klass.define('readAsBytes', (args) async {
        var instance = args[0] as KlassInstance;
        var bytes =
            await File(instance.getField('path') as String).readAsBytes();
        return Uint8List.fromList(bytes);
      });
      klass.define('writeAsBytes', (args) async {
        var instance = args[0] as KlassInstance;
        await File(instance.getField('path') as String)
            .writeAsBytes(args[1] as Uint8List);
        return null;
      });
      klass.define('copy', (args) async {
        var instance = args[0] as KlassInstance;
        await File(instance.getField('path') as String).copy(args[1] as String);
        return null;
      });
      klass.define('rename', (args) async {
        var instance = args[0] as KlassInstance;
        await File(instance.getField('path') as String)
            .rename(args[1] as String);
        return null;
      });
    });

    Runtime.register("Folder", (klass) {
      klass.define('create', (args) async {
        var instance = args[0] as KlassInstance;
        var recursive = args.length > 1 ? args[1] as bool : false;
        await Directory(instance.getField('path') as String)
            .create(recursive: recursive);
        return null;
      });
      klass.define('delete', (args) async {
        var instance = args[0] as KlassInstance;
        var recursive = args.length > 1 ? args[1] as bool : false;
        await Directory(instance.getField('path') as String)
            .delete(recursive: recursive);
        return null;
      });
      klass.define('exists', (args) async {
        var instance = args[0] as KlassInstance;
        return await Directory(instance.getField('path') as String).exists();
      });
      klass.define('list', (args) async {
        var instance = args[0] as KlassInstance;
        var recursive = args.length > 1 ? args[1] as bool : false;
        var entities = await Directory(instance.getField('path') as String)
            .list(recursive: recursive)
            .toList();
        // We will return a Dart List of strings, Velvet automatically converts it
        return entities.map((e) => e.path).toList();
      });
      klass.defineStatic('current', (args) {
        return Directory.current.path;
      });
    });

    Runtime.register("Http", (klass) {
      klass.defineStatic('get', (args) async {
        var url = args[0] as String;
        var client = HttpClient();
        try {
          var request = await client.getUrl(Uri.parse(url));
          if (args.length > 1 &&
              args[1] is KlassInstance &&
              (args[1] as KlassInstance).name == 'Map') {
            var headersMap =
                (args[1] as KlassInstance).getField('_nativeData') as Map;
            headersMap.forEach((key, value) {
              request.headers.set(key.toString(), value.toString());
            });
          }
          var response = await request.close();
          var responseBody = await response.transform(utf8.decoder).join();
          return {'statusCode': response.statusCode, 'body': responseBody};
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
          if (args.length > 2 &&
              args[2] is KlassInstance &&
              (args[2] as KlassInstance).name == 'Map') {
            var headersMap =
                (args[2] as KlassInstance).getField('_nativeData') as Map;
            headersMap.forEach((key, value) {
              request.headers.set(key.toString(), value.toString());
            });
          } else {
            request.headers.set('content-type', 'application/json');
          }
          request.write(body);
          var response = await request.close();
          var responseBody = await response.transform(utf8.decoder).join();
          return {'statusCode': response.statusCode, 'body': responseBody};
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
          if (args.length > 2 &&
              args[2] is KlassInstance &&
              (args[2] as KlassInstance).name == 'Map') {
            var headersMap =
                (args[2] as KlassInstance).getField('_nativeData') as Map;
            headersMap.forEach((key, value) {
              request.headers.set(key.toString(), value.toString());
            });
          } else {
            request.headers.set('content-type', 'application/json');
          }
          request.write(body);
          var response = await request.close();
          var responseBody = await response.transform(utf8.decoder).join();
          return {'statusCode': response.statusCode, 'body': responseBody};
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
          if (args.length > 1 &&
              args[1] is KlassInstance &&
              (args[1] as KlassInstance).name == 'Map') {
            var headersMap =
                (args[1] as KlassInstance).getField('_nativeData') as Map;
            headersMap.forEach((key, value) {
              request.headers.set(key.toString(), value.toString());
            });
          }
          var response = await request.close();
          var responseBody = await response.transform(utf8.decoder).join();
          return {'statusCode': response.statusCode, 'body': responseBody};
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

    Runtime.bindPrimitive(VmlElement, 'VmlElement');
    Runtime.bindPrimitiveTypeCheck((obj) => obj is VmlElement, 'VmlElement');
    Runtime.bindPrimitive(VmlText, 'VmlText');
    Runtime.bindPrimitiveTypeCheck((obj) => obj is VmlText, 'VmlText');
    Runtime.bindPrimitive(VmlDocument, 'VmlDocument');
    Runtime.bindPrimitiveTypeCheck((obj) => obj is VmlDocument, 'VmlDocument');

    Runtime.register("VmlText", (klass) {
      klass.getter('text', (args) => (args[0] as VmlText).text);
      klass.define('toHTML', (args) => (args[0] as VmlText).toString());
    });

    Runtime.register("VmlElement", (klass) {
      klass.getter('tagName', (args) => (args[0] as VmlElement).tagName);
      klass.getter('attributes', (args) => (args[0] as VmlElement).attributes);
      klass.getter('children', (args) => (args[0] as VmlElement).children);
      klass.define('querySelector', (args) => (args[0] as VmlElement).querySelector(args[1] as String));
      klass.define('querySelectorAll', (args) => (args[0] as VmlElement).querySelectorAll(args[1] as String));
      klass.define('getAttribute', (args) => (args[0] as VmlElement).attributes[args[1] as String]);
      klass.define('toHTML', (args) => (args[0] as VmlElement).toString());
    });

    Runtime.register("VmlDocument", (klass) {
      klass.getter('nodes', (args) => (args[0] as VmlDocument).nodes);
      klass.define('toHTML', (args) => (args[0] as VmlDocument).toString());
    });

    Runtime.register("VML", (klass) {
      klass.defineStatic('parse', (args) {
        var source = args[0] as String;
        var tokenizer = Tokenizer(source);
        tokenizer.tokenize();
        var parser = Parser(tokenizer, sourceName: 'inline.vml');
        var ast = parser.parse();
        
        List<Node> markupNodes = [];
        for (var stmt in ast.body) {
          if (stmt is MarkupNode) {
            markupNodes.add(stmt);
          } else if (stmt is ExpressionStatement && stmt.value is MarkupNode) {
            markupNodes.add(stmt.value);
          }
        }
        
        return VmlDocument.fromAst(markupNodes);
      });
      klass.defineStatic('toHTML', (args) {
        var source = args[0] as String;
        var tokenizer = Tokenizer(source);
        tokenizer.tokenize();
        var parser = Parser(tokenizer, sourceName: 'inline.vml');
        var ast = parser.parse();
        
        List<Node> markupNodes = [];
        for (var stmt in ast.body) {
          if (stmt is MarkupNode) {
            markupNodes.add(stmt);
          } else if (stmt is ExpressionStatement && stmt.value is MarkupNode) {
            markupNodes.add(stmt.value);
          }
        }
        
        var dom = VmlDocument.fromAst(markupNodes);
        return dom.toString();
      });
    });

    Runtime.register("List", (klass) {
      klass.define('add', (args) {
        var list = args[0] is KlassInstance
            ? (args[0] as KlassInstance).getField('_nativeData') as List
            : args[0] as List;
        list.add(args[1]);
        return null;
      });
      klass.define('get', (args) {
        var list = args[0] is KlassInstance
            ? (args[0] as KlassInstance).getField('_nativeData') as List
            : args[0] as List;
        return list[(args[1] as num).toInt()];
      });
      klass.define('set', (args) {
        var list = args[0] is KlassInstance
            ? (args[0] as KlassInstance).getField('_nativeData') as List
            : args[0] as List;
        list[(args[1] as num).toInt()] = args[2];
        return null;
      });
      klass.define('length', (args) {
        var list = args[0] is KlassInstance
            ? (args[0] as KlassInstance).getField('_nativeData') as List
            : args[0] as List;
        return list.length;
      });
      klass.define('toString', (args) {
        var list = args[0] is KlassInstance
            ? (args[0] as KlassInstance).getField('_nativeData') as List
            : args[0] as List;
        return list.toString();
      });
      klass.define('remove', (args) {
        var list = args[0] is KlassInstance
            ? (args[0] as KlassInstance).getField('_nativeData') as List
            : args[0] as List;
        return list.remove(args[1]);
      });
      klass.define('removeAt', (args) {
        var list = args[0] is KlassInstance
            ? (args[0] as KlassInstance).getField('_nativeData') as List
            : args[0] as List;
        return list.removeAt((args[1] as num).toInt());
      });
      klass.define('contains', (args) {
        var list = args[0] is KlassInstance
            ? (args[0] as KlassInstance).getField('_nativeData') as List
            : args[0] as List;
        return list.contains(args[1]);
      });
      klass.define('indexOf', (args) {
        var list = args[0] is KlassInstance
            ? (args[0] as KlassInstance).getField('_nativeData') as List
            : args[0] as List;
        return list.indexOf(args[1]);
      });
      klass.define('clear', (args) {
        var list = args[0] is KlassInstance
            ? (args[0] as KlassInstance).getField('_nativeData') as List
            : args[0] as List;
        list.clear();
        return null;
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
        var map = args[0] is KlassInstance
            ? (args[0] as KlassInstance).getField('_nativeData') as Map
            : args[0] as Map;
        return map[args[1]];
      });
      klass.define('remove', (args) {
        var instance = args[0] as KlassInstance;
        var map = instance.getField('_nativeData') as Map;
        return map.remove(args[1]);
      });
      klass.define('containsKey', (args) {
        var instance = args[0] as KlassInstance;
        var map = instance.getField('_nativeData') as Map;
        return map.containsKey(args[1]);
      });
      klass.define('keys', (args) {
        var instance = args[0] as KlassInstance;
        var map = instance.getField('_nativeData') as Map;
        return map.keys.toList();
      });
      klass.define('values', (args) {
        var instance = args[0] as KlassInstance;
        var map = instance.getField('_nativeData') as Map;
        return map.values.toList();
      });
      klass.define('clear', (args) {
        var instance = args[0] as KlassInstance;
        var map = instance.getField('_nativeData') as Map;
        map.clear();
        return null;
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
      klass.define(
          'replace',
          (args) => (args[0] as String)
              .replaceAll(args[1] as String, args[2] as String));
      klass.define('contains',
          (args) => (args[0] as String).contains(args[1] as String));
      klass.define('startsWith',
          (args) => (args[0] as String).startsWith(args[1] as String));
      klass.define('endsWith',
          (args) => (args[0] as String).endsWith(args[1] as String));
      klass.define(
          'substring',
          (args) => (args[0] as String)
              .substring((args[1] as num).toInt(), (args[2] as num).toInt()));
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

    Runtime.register("Boolean", (klass) {
      klass.define('toString', (args) => (args[0] as bool).toString());
    });

    Runtime.register("RegExp", (klass) {
      klass.define('compile', (args) {
        var instance = args[0] as KlassInstance;
        instance.setField('_nativeData', RegExp(args[1] as String));
        return null;
      });
      klass.define('hasMatch', (args) {
        var regExp =
            (args[0] as KlassInstance).getField('_nativeData') as RegExp;
        return regExp.hasMatch(args[1] as String);
      });
      klass.define('stringMatch', (args) {
        var regExp =
            (args[0] as KlassInstance).getField('_nativeData') as RegExp;
        return regExp.stringMatch(args[1] as String);
      });
      klass.define('replaceAll', (args) {
        var regExp =
            (args[0] as KlassInstance).getField('_nativeData') as RegExp;
        return (args[1] as String).replaceAll(regExp, args[2] as String);
      });
    });

    Runtime.register("Timer", (klass) {
      klass.defineStatic('sleep', (args) async {
        var ms = (args[0] as num).toInt();
        await Future.delayed(Duration(milliseconds: ms));
        return null;
      });
    });

    _registerHttpServer();
  }

  static void _registerHttpServer() {
    Runtime.bindPrimitive(VelvetHttpServer, 'HttpServer');
    Runtime.bindPrimitiveTypeCheck((obj) => obj is VelvetHttpServer, 'HttpServer');
    
    Runtime.bindPrimitive(VelvetHttpRequest, 'HttpRequest');
    Runtime.bindPrimitiveTypeCheck((obj) => obj is VelvetHttpRequest, 'HttpRequest');
    
    Runtime.bindPrimitive(HttpResponse, 'HttpResponse');
    Runtime.bindPrimitiveTypeCheck((obj) => obj is HttpResponse, 'HttpResponse');

    final serverBuffers = <VelvetHttpServer, List<VelvetHttpRequest>>{};
    final serverCompleters = <VelvetHttpServer, List<dart_async.Completer<VelvetHttpRequest>>>{};

    Runtime.register("HttpServer", (klass) {
      klass.defineStatic('bind', (args) async {
        var host = args[0] as String;
        var port = (args[1] as num).toInt();
        var dartServer = await HttpServer.bind(host, port);
        var server = VelvetHttpServer(dartServer);

        serverBuffers[server] = [];
        serverCompleters[server] = [];

        dartServer.listen((HttpRequest request) {
          var vReq = VelvetHttpRequest(request);
          if (serverCompleters[server] != null && serverCompleters[server]!.isNotEmpty) {
            var c = serverCompleters[server]!.removeAt(0);
            c.complete(vReq);
          } else if (serverBuffers[server] != null) {
            serverBuffers[server]!.add(vReq);
          }
        });

        return server;
      });

      klass.define('accept', (args) async {
        var server = args[0] as VelvetHttpServer;
        var buffer = serverBuffers[server]!;
        var completers = serverCompleters[server]!;

        if (buffer.isNotEmpty) {
          return buffer.removeAt(0);
        }

        var completer = dart_async.Completer<VelvetHttpRequest>();
        completers.add(completer);
        return await completer.future;
      });

      klass.define('close', (args) async {
        var server = args[0] as VelvetHttpServer;
        await server.server.close();
        serverBuffers.remove(server);
        serverCompleters.remove(server);
        return null;
      });
    });

    Runtime.register("HttpRequest", (klass) {
      klass.define('method', (args) => (args[0] as VelvetHttpRequest).request.method);
      klass.define('uri', (args) => (args[0] as VelvetHttpRequest).request.uri.toString());
      klass.define('path', (args) => (args[0] as VelvetHttpRequest).request.uri.path);
      klass.define('query', (args) {
         var req = args[0] as VelvetHttpRequest;
         return Map<String, dynamic>.from(req.request.uri.queryParameters);
      });
      klass.define('headers', (args) {
         var req = args[0] as VelvetHttpRequest;
         var map = <String, dynamic>{};
         req.request.headers.forEach((name, values) {
           map[name] = values.join(', ');
         });
         return map;
      });
      klass.define('ip', (args) {
         var req = args[0] as VelvetHttpRequest;
         return req.request.connectionInfo?.remoteAddress.address ?? "unknown";
      });
      klass.define('response', (args) => (args[0] as VelvetHttpRequest).request.response);
      klass.define('readAsString', (args) async {
        var req = args[0] as VelvetHttpRequest;
        return await utf8.decoder.bind(req.request).join();
      });
      klass.define('readAsBytes', (args) async {
         var req = args[0] as VelvetHttpRequest;
         var bytes = <int>[];
         await for (var chunk in req.request) {
           bytes.addAll(chunk);
         }
         return Uint8List.fromList(bytes);
      });
      klass.define('parseJson', (args) async {
        var req = args[0] as VelvetHttpRequest;
        var bodyString = await utf8.decoder.bind(req.request).join();
        if (bodyString.isEmpty) return null;
        return jsonDecode(bodyString);
      });
      klass.define('parseFormUrlEncoded', (args) async {
        var req = args[0] as VelvetHttpRequest;
        var bodyString = await utf8.decoder.bind(req.request).join();
        var uri = Uri(query: bodyString);
        return Map<String, dynamic>.from(uri.queryParameters);
      });
      klass.define('parseMultipart', (args) async {
        var req = args[0] as VelvetHttpRequest;
        var contentType = req.request.headers.contentType;
        if (contentType == null || contentType.primaryType != 'multipart') {
          return null;
        }
        var boundary = contentType.parameters['boundary'];
        if (boundary == null) return null;
        
        var transformer = MimeMultipartTransformer(boundary);
        var parts = await transformer.bind(req.request).toList();
        
        var result = <String, dynamic>{};
        for (var part in parts) {
          var disposition = part.headers['content-disposition'];
          if (disposition != null) {
            var nameMatch = RegExp(r'name="([^"]+)"').firstMatch(disposition);
            var filenameMatch = RegExp(r'filename="([^"]+)"').firstMatch(disposition);
            var name = nameMatch?.group(1) ?? 'unknown';
            
            var bytes = <int>[];
            await for (var chunk in part) {
              bytes.addAll(chunk);
            }
            
            if (filenameMatch != null) {
              result[name] = {
                'filename': filenameMatch.group(1),
                'bytes': Uint8List.fromList(bytes)
              };
            } else {
              result[name] = utf8.decode(bytes);
            }
          }
        }
        return result;
      });
    });

    Runtime.register("HttpResponse", (klass) {
      klass.define('statusCode', (args) => (args[0] as HttpResponse).statusCode);
      klass.define('setStatusCode', (args) {
        var res = args[0] as HttpResponse;
        res.statusCode = (args[1] as num).toInt();
        return null;
      });
      klass.define('setHeader', (args) {
        var res = args[0] as HttpResponse;
        res.headers.set(args[1] as String, args[2]);
        return null;
      });
      klass.define('removeHeader', (args) {
        var res = args[0] as HttpResponse;
        res.headers.removeAll(args[1] as String);
        return null;
      });
      klass.define('write', (args) {
        var res = args[0] as HttpResponse;
        res.write(args[1]);
        return null;
      });
      klass.define('writeBytes', (args) {
        var res = args[0] as HttpResponse;
        res.add(args[1] as Uint8List);
        return null;
      });
      klass.define('close', (args) async {
        var res = args[0] as HttpResponse;
        await res.close();
        return null;
      });
    });
  }
}

class VelvetHttpServer {
  final HttpServer server;
  VelvetHttpServer(this.server);
}

class VelvetHttpRequest {
  final HttpRequest request;
  VelvetHttpRequest(this.request);
}
