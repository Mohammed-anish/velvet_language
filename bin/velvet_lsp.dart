import 'dart:io';
import 'package:lsp_server/lsp_server.dart';
import 'package:velvet_cmp/lsp/handlers.dart';

void main() async {
  final connection = Connection(stdin, stdout);
  final handlers = LspHandlers(connection);

  await connection.listen();
}
