import 'dart:io';

/// Console color utilities for terminal output
class ConsoleColors {
  // ANSI color codes
  static const String reset = '\x1B[0m';
  static const String bold = '\x1B[1m';
  static const String dim = '\x1B[2m';
  static const String underline = '\x1B[4m';

  // Foreground colors
  static const String black = '\x1B[30m';
  static const String red = '\x1B[31m';
  static const String green = '\x1B[32m';
  static const String yellow = '\x1B[33m';
  static const String blue = '\x1B[34m';
  static const String magenta = '\x1B[35m';
  static const String cyan = '\x1B[36m';
  static const String white = '\x1B[37m';

  // Bright foreground colors
  static const String brightRed = '\x1B[91m';
  static const String brightGreen = '\x1B[92m';
  static const String brightYellow = '\x1B[93m';
  static const String brightBlue = '\x1B[94m';
  static const String brightMagenta = '\x1B[95m';
  static const String brightCyan = '\x1B[96m';

  // Background colors
  static const String bgRed = '\x1B[41m';
  static const String bgGreen = '\x1B[42m';
  static const String bgYellow = '\x1B[43m';
  static const String bgBlue = '\x1B[44m';

  // Utility methods
  static String colorize(String text, String color) {
    return '$color$text$reset';
  }

  static String success(String text) => colorize(text, green);
  static String error(String text) => colorize(text, red);
  static String warning(String text) => colorize(text, yellow);
  static String info(String text) => colorize(text, blue);
  static String highlight(String text) => colorize(text, cyan);
  static String dimmed(String text) => '$dim$text$reset';

  static String boldSuccess(String text) => '$bold${success(text)}';
  static String boldError(String text) => '$bold${error(text)}';
  static String boldWarning(String text) => '$bold${warning(text)}';

  // Test result indicators
  static String passed() => success('✓');
  static String failed() => error('✗');
  static String skipped() => warning('○');

  // Progress indicators
  static String progressBar(int current, int total, {int width = 30}) {
    final percentage = (current / total * 100).round();
    final filled = (current / total * width).round();
    final empty = width - filled;

    final bar = '█' * filled + '░' * empty;
    final color = percentage >= 80
        ? green
        : percentage >= 60
            ? yellow
            : red;

    return '$color[$bar]$reset $percentage%';
  }

  // Table formatting
  static String tableSeparator(int width) => '─' * width;
  static String tableCorner(String char) => char;

  // Check if colors are supported
  static bool get supportsColor {
    if (!isTerminal) return false;

    final term = Platform.environment['TERM'];
    if (term == null) return false;

    final colorTerms = [
      'xterm',
      'screen',
      'vt100',
      'color',
      'ansi',
      'cygwin',
      'linux'
    ];
    return colorTerms.any((t) => term.contains(t));
  }

  static bool get isTerminal => stdout.hasTerminal;
}

// Extension for easy string coloring
extension ColoredString on String {
  String get red => ConsoleColors.error(this);
  String get green => ConsoleColors.success(this);
  String get yellow => ConsoleColors.warning(this);
  String get blue => ConsoleColors.info(this);
  String get cyan => ConsoleColors.highlight(this);
  String get dim => ConsoleColors.dimmed(this);
  String get bold => '${ConsoleColors.bold}$this${ConsoleColors.reset}';
}
