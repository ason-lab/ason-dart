/// ASON error types.
class AsonError implements Exception {
  final String message;
  const AsonError(this.message);

  @override
  String toString() => 'AsonError: $message';

  static const eof = AsonError('unexpected end of input');
  static const expectedColon = AsonError("expected ':'");
  static const expectedOpenParen = AsonError("expected '('");
  static const expectedCloseParen = AsonError("expected ')'");
  static const expectedOpenBrace = AsonError("expected '{'");
  static const expectedCloseBrace = AsonError("expected '}'");
  static const expectedOpenBracket = AsonError("expected '['");
  static const expectedCloseBracket = AsonError("expected ']'");
  static const expectedComma = AsonError("expected ','");
  static const expectedValue = AsonError('expected value');
  static const trailingCharacters = AsonError('trailing characters');
  static const invalidNumber = AsonError('invalid number');
  static const invalidBool = AsonError('invalid bool');
  static const unclosedString = AsonError('unclosed string');
  static const unclosedComment = AsonError('unclosed comment');
  static const invalidUnicodeEscape = AsonError('invalid unicode escape');
  static const unsupportedMap = AsonError(
    'map syntax is not supported; use entry-list arrays such as attrs@[{key@str,value@int}]',
  );
}
