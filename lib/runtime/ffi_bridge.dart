import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import 'package:velvet_cmp/runtime/runtime.dart';

class FFIBridgeRegistry {
  static final Map<String, ffi.DynamicLibrary> _libs = {};

  static void register() {
    Runtime.register('FFI', (klass) {
      klass.defineStatic('load', (args) {
        var path = args[0] as String;
        var name = args[1] as String;
        _libs[name] = ffi.DynamicLibrary.open(path);
        return name;
      });

      klass.defineStatic('invokeVoid', (args) {
        var lib = _libs[args[0] as String];
        if (lib == null) throw Exception("Library not loaded");
        var funcName = args[1] as String;
        var func = lib.lookupFunction<ffi.Void Function(), void Function()>(funcName);
        func();
        return null;
      });

      klass.defineStatic('invokeInt', (args) {
        var lib = _libs[args[0] as String];
        if (lib == null) throw Exception("Library not loaded");
        var funcName = args[1] as String;
        var func = lib.lookupFunction<ffi.Int32 Function(ffi.Int32), int Function(int)>(funcName);
        return func((args[2] as num).toInt());
      });

      klass.defineStatic('invokeString', (args) {
        var lib = _libs[args[0] as String];
        if (lib == null) throw Exception("Library not loaded");
        var funcName = args[1] as String;
        
        var func = lib.lookupFunction<
            ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>), 
            ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>)
        >(funcName);
        
        var dartString = args[2] as String;
        var cString = dartString.toNativeUtf8();
        
        var resultPtr = func(cString);
        var resultStr = resultPtr.toDartString();
        
        malloc.free(cString);
        return resultStr;
      });
    });
  }
}
