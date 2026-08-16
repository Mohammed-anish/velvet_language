class Token {
  final TType type;
  final String value;
  final int line;
  final int column;

  Token(this.type, this.value, this.line, this.column);

  @override
  String toString() => 'Token($type, "$value", line: $line, column: $column)';
}

enum TType {
  // Identifiers and literals
  identifier,
  number,
  string,
  boolean,
  nullLiteral,

  // Keywords
  keyword,
  fn,
  if_,
  else_,
  while_,
  for_,
  return_,
  break_,
  continue_,
  class_,
  import_,
  export_,
  let,
  const_,
  auto,
  true_,
  false_,
  match_,
  switch_,
  case_,
  default_,
  try_,
  catch_,
  throw_,
  asyncKw,
  awaitKw,

  // Operators
  operator,
  plus,
  minus,
  star,
  slash,
  percent,
  equal,
  doubleEqual,
  notEqual,
  greater,
  greaterEqual,
  less,
  lessEqual,
  bang,
  and_,
  or_,
  arrow, // =>
  fatArrow, // =>>

  // Assignment
  assign, // =
  plusAssign, // +=
  minusAssign, // -=
  starAssign, // *=
  slashAssign, // /=

  // Delimiters
  delimeter,
  lParen, // (
  rParen, // )
  lBrace, // {
  rBrace, // }
  lBracket, // [
  rBracket, // ]
  comma,
  colon,
  semicolon,
  dot,

  // Others
  comment,
  newLine,
  eof,
  reactive,
  watch,
  loop,
  static,
  new_,
  this_,
  outer, derives
}
