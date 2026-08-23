/// ASUN error types.
class AsunError implements Exception {
  final String message;
  const AsunError(this.message);

  @override
  String toString() => 'AsunError: $message';

  static const eof = AsunError('unexpected end of input');
  static const expectedColon = AsunError("expected ':'");
  static const expectedOpenParen = AsunError("expected '('");
  static const expectedCloseParen = AsunError("expected ')'");
  static const expectedOpenBrace = AsunError("expected '{'");
  static const expectedCloseBrace = AsunError("expected '}'");
  static const expectedOpenBracket = AsunError("expected '['");
  static const expectedCloseBracket = AsunError("expected ']'");
  static const expectedComma = AsunError("expected ','");
  static const expectedValue = AsunError('expected value');
  static const trailingCharacters = AsunError('trailing characters');
  static const invalidNumber = AsunError('invalid number');
  static const invalidBool = AsunError('invalid bool');
  static const unclosedString = AsunError('unclosed string');
  static const unclosedComment = AsunError('unclosed comment');
  static const invalidUnicodeEscape = AsunError('invalid unicode escape');
  static const unsupportedMap = AsunError('map syntax is not supported');
  static const maxDepthExceeded =
      AsunError('maximum nesting depth exceeded');
}
