import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// App-wide logger.
///
/// Use this instead of `print` for consistent formatting and log levels.
final Logger appLogger = Logger(
  filter: kReleaseMode ? ProductionFilter() : DevelopmentFilter(),
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 8,
    lineLength: 120,
    colors: !kIsWeb,
    printEmojis: false,
    printTime: false,
  ),
);

