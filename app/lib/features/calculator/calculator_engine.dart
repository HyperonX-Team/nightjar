enum CalcOp { add, subtract, multiply, divide }

/// Immediate-execution calculator, the way a physical pocket calculator works.
/// There is no expression parser and no operator precedence: 2 + 3 x 4 = 20.
class CalculatorEngine {
  static const int maxDigits = 12;

  /// Beyond 12 integer digits a result cannot be shown in 12 characters.
  static const double _overflowLimit = 1e12;

  String _entry = '0';
  bool _typing = false;
  bool _consumed = false;
  double? _accumulator;
  CalcOp? _pendingOp;
  CalcOp? _lastOp;
  double? _lastOperand;
  bool _error = false;

  /// Display text with thousands separators. Never used for PIN comparison.
  String get display => _error ? 'Error' : formatForDisplay(_entry);

  /// The entry as typed, digits and separators only. The PIN trigger compares
  /// this, because the display groups 4 digit numbers as 4,826.
  String get rawEntry => _entry;

  bool get isError => _error;

  void clear() {
    _entry = '0';
    _typing = false;
    _consumed = false;
    _accumulator = null;
    _pendingOp = null;
    _lastOp = null;
    _lastOperand = null;
    _error = false;
  }

  void inputDigit(String digit) {
    if (_error) {
      clear();
    }
    if (!_typing) {
      _entry = digit;
      _typing = true;
      _consumed = false;
      return;
    }
    if (_entry == '0') {
      if (digit != '0') {
        _entry = digit;
      }
      return;
    }
    if (_entry == '-0') {
      _entry = '-$digit';
      return;
    }
    if (_digitCount(_entry) >= maxDigits) {
      return;
    }
    _entry = '$_entry$digit';
  }

  void inputDecimal() {
    if (_error) {
      clear();
    }
    if (!_typing) {
      _entry = '0.';
      _typing = true;
      _consumed = false;
      return;
    }
    if (_entry.contains('.')) {
      return;
    }
    if (_digitCount(_entry) >= maxDigits) {
      return;
    }
    _entry = '$_entry.';
  }

  void toggleSign() {
    if (_error) {
      return;
    }
    if (_entry == '0' || _entry == '0.') {
      return;
    }
    _entry = _entry.startsWith('-') ? _entry.substring(1) : '-$_entry';
  }

  void percent() {
    if (_error) {
      return;
    }
    final value = double.tryParse(_entry);
    if (value == null) {
      return;
    }
    _writeValue(value / 100);
    _typing = false;
    _consumed = false;
  }

  void applyOperator(CalcOp op) {
    if (_error) {
      return;
    }
    final value = double.tryParse(_entry);
    if (value == null) {
      return;
    }
    if (_pendingOp == null) {
      _accumulator = value;
    } else if (!_consumed) {
      final result = _compute(_accumulator ?? value, value, _pendingOp!);
      if (result == null) {
        _setError();
        return;
      }
      _accumulator = result;
    }
    _pendingOp = op;
    if (!_writeValue(_accumulator!)) {
      return;
    }
    _typing = false;
    _consumed = true;
  }

  void equals() {
    if (_error) {
      return;
    }
    if (_pendingOp != null) {
      final operand = double.tryParse(_entry);
      if (operand == null) {
        return;
      }
      final result = _compute(_accumulator ?? operand, operand, _pendingOp!);
      if (result == null) {
        _setError();
        return;
      }
      _lastOp = _pendingOp;
      _lastOperand = operand;
      _pendingOp = null;
      _accumulator = null;
      if (!_writeValue(result)) {
        return;
      }
      _typing = false;
      _consumed = true;
      return;
    }
    if (_lastOp != null && _lastOperand != null) {
      final base = double.tryParse(_entry);
      if (base == null) {
        return;
      }
      final result = _compute(base, _lastOperand!, _lastOp!);
      if (result == null) {
        _setError();
        return;
      }
      if (!_writeValue(result)) {
        return;
      }
      _typing = false;
      _consumed = true;
    }
  }

  void _setError() {
    _error = true;
    _entry = '0';
    _typing = false;
    _consumed = false;
    _accumulator = null;
    _pendingOp = null;
    _lastOp = null;
    _lastOperand = null;
  }

  bool _writeValue(double value) {
    final text = plainString(roundToSignificant(value, maxDigits));
    if (text == null) {
      _setError();
      return false;
    }
    _entry = text;
    return true;
  }

  double? _compute(double a, double b, CalcOp op) {
    final result = switch (op) {
      CalcOp.add => a + b,
      CalcOp.subtract => a - b,
      CalcOp.multiply => a * b,
      CalcOp.divide => b == 0 ? null : a / b,
    };
    if (result == null || !result.isFinite) {
      return null;
    }
    return result;
  }

  int _digitCount(String text) =>
      text.replaceAll(RegExp('[^0-9]'), '').length;
}

/// Rounds away binary artifacts so 0.1 + 0.2 shows as 0.3.
double roundToSignificant(double value, int digits) {
  if (value == 0 || !value.isFinite) {
    return value;
  }
  return double.parse(value.toStringAsPrecision(digits));
}

/// Plain decimal text inside the 12 significant character cap, or null when the
/// value cannot fit (SPEC 8.3). Rounding happens on the fraction, so 2/3 shows
/// 0.66666666667 rather than a truncated 0.66666666666.
String? plainString(double value) {
  if (!value.isFinite) {
    return null;
  }
  if (value == 0) {
    return '0';
  }
  final abs = value.abs();
  if (abs >= CalculatorEngine._overflowLimit) {
    return null;
  }
  final negative = value < 0;
  final integerDigits = abs.truncate().toString().length;
  final fractionOnly = abs < 1;
  final budget = CalculatorEngine.maxDigits -
      (integerDigits - (fractionOnly ? 1 : 0)) -
      (negative ? 1 : 0);
  if (budget <= 0) {
    final rounded = value.toStringAsFixed(0);
    return _significantLength(rounded) > CalculatorEngine.maxDigits
        ? null
        : rounded;
  }
  final text = value.toStringAsFixed(budget - 1);
  if (!text.contains('.')) {
    return text;
  }
  return text
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

/// Digits plus the decimal point plus the minus sign, where a single leading
/// zero before the decimal point does not count.
int _significantLength(String text) {
  final digits = text.replaceAll(RegExp('[^0-9]'), '').length;
  final sign = text.startsWith('-') ? 1 : 0;
  final dot = text.contains('.') ? 1 : 0;
  final body = sign == 1 ? text.substring(1) : text;
  final leadingZero = body.startsWith('0.') ? 1 : 0;
  return digits - leadingZero + sign + dot;
}

/// Display text: integer part grouped in threes, as on a physical calculator.
String formatForDisplay(String entry) {
  var sign = '';
  var text = entry;
  if (text.startsWith('-')) {
    sign = '-';
    text = text.substring(1);
  }
  final dot = text.indexOf('.');
  final intPart = dot >= 0 ? text.substring(0, dot) : text;
  final fracPart = dot >= 0 ? text.substring(dot) : '';
  return '$sign${_groupThousands(intPart)}$fracPart';
}

/// Font size ladder for the display, 48sp down to 24sp, so long values shrink
/// instead of overflowing or scrolling (SPEC 8.3).
double displayFontSize(int textLength) {
  const maxSize = 48.0;
  const minSize = 24.0;
  final size = maxSize - (textLength - 8) * 3;
  return size.clamp(minSize, maxSize);
}

String _groupThousands(String digits) {
  if (digits.length <= 3) {
    return digits;
  }
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
