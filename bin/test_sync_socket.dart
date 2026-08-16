import 'dart:io';
void main() {
  var socket = RawSynchronousSocket.connectSync('google.com', 80);
  print(socket);
  socket.writeFromSync('GET / HTTP/1.1\r\nHost: google.com\r\n\r\n'.codeUnits);
  var data = socket.readSync(1024);
  print(String.fromCharCodes(data!));
  socket.closeSync();
}
