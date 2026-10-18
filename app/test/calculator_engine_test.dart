import 'package:flutter_test/flutter_test.dart';
import 'package:nightjar/features/calculator/calculator_engine.dart';

/// Drives the engine with a compact key script:
/// digits and '.', operators + - * /, '=' equals, 'C' clear, 'S' sign,
/// '%' percent. Operator keys are all after the sign key so '-' is minus.
CalculatorEngine run(String keys) {
  final engine = CalculatorEngine();
  for (final key in keys.split('')) {
    if (RegExp(r'^[0-9]$').hasMatch(key)) {
      engine.inputDigit(key);
    } else if (key == '.') {
      engine.inputDecimal();
    } else if (key == '+') {
      engine.applyOperator(CalcOp.add);
    } else if (key == '-') {
      engine.applyOperator(CalcOp.subtract);
    } else if (key == '*') {
      engine.applyOperator(CalcOp.multiply);
    } else if (key == '/') {
      engine.applyOperator(CalcOp.divide);
    } else if (key == '=') {
      engine.equals();
    } else if (key == 'C') {
      engine.clear();
    } else if (key == 'S') {
      engine.toggleSign();
    } else if (key == '%') {
      engine.percent();
    }
  }
  return engine;
}

void main() {
  group('entry', () {
    test('starts at zero', () {
      expect(run('').display, '0');
    });

    test('digits append', () {
      expect(run('123').display, '123');
    });

    test('leading digit replaces zero', () {
      expect(run('05').display, '5');
    });

    test('repeated zero stays zero', () {
      expect(run('000').display, '0');
    });

    test('groups thousands', () {
      expect(run('1234').display, '1,234');
    });

    test('groups millions', () {
      expect(run('1234567').display, '1,234,567');
    });

    test('accepts twelve digits', () {
      expect(run('123456789012').display, '123,456,789,012');
    });

    test('ignores a thirteenth digit', () {
      expect(run('1234567890123').display, '123,456,789,012');
    });

    test('decimal point starts a fraction', () {
      expect(run('.').display, '0.');
    });

    test('fraction digits append', () {
      expect(run('.5').display, '0.5');
    });

    test('second decimal point is ignored', () {
      expect(run('1.2.3').display, '1.23');
    });

    test('trailing decimal point stays visible', () {
      expect(run('5.').display, '5.');
    });

    test('fraction digits count toward the twelve digit cap', () {
      final entry = '0.${'0' * 12}';
      expect(
        run(entry).rawEntry.replaceAll(RegExp('[^0-9]'), '').length,
        CalculatorEngine.maxDigits,
      );
    });

    test('AC clears the entry', () {
      expect(run('5C').display, '0');
    });

    test('AC clears a pending operator', () {
      expect(run('5+3C6=').display, '6');
    });
  });

  group('arithmetic', () {
    test('addition', () => expect(run('2+3=').display, '5'));
    test('subtraction', () => expect(run('9-4=').display, '5'));
    test('multiplication', () => expect(run('7*8=').display, '56'));
    test('division', () => expect(run('8/2=').display, '4'));
    test('immediate execution ignores precedence',
        () => expect(run('2+3*4=').display, '20'));
    test('chained operations run left to right',
        () => expect(run('10-2-3=').display, '5'));
    test('operator commits the entry',
        () => expect(run('2+3+').display, '5'));
    test('three operands accumulate',
        () => expect(run('2+3+4=').display, '9'));
    test('operator twice replaces the pending operator',
        () => expect(run('2+*3=').display, '6'));
    test('plus twice replaces plus',
        () => expect(run('2++3=').display, '5'));
    test('equals with a consumed entry uses the displayed value',
        () => expect(run('5+=').display, '10'));
    test('multiply equals repeats the entry',
        () => expect(run('6*=').display, '36'));
    test('equals with no pending operator keeps the value',
        () => expect(run('7=').display, '7'));
    test('repeat equals reuses the last operation',
        () => expect(run('2+3==').display, '8'));
    test('repeat equals chains',
        () => expect(run('2+3===').display, '11'));
    test('repeat equals works after multiply',
        () => expect(run('2*3==').display, '18'));
    test('AC clears the repeat memory',
        () => expect(run('2+3=C4=').display, '4'));
    test('decimals add cleanly', () => expect(run('1.5+2.25=').display, '3.75'));
    test('negative operand stays negative',
        () => expect(run('5S+3=').display, '-2'));
    test('negative result', () => expect(run('3-5=').display, '-2'));
    test('subtracting a negative',
        () => expect(run('3-5S=').display, '8'));
  });

  group('percent and sign', () {
    test('percent divides the entry by 100',
        () => expect(run('50%').display, '0.5'));
    test('percent is not percent of the accumulator',
        () => expect(run('50+10%=').display, '50.1'));
    test('percent on a result', () => expect(run('200%').display, '2'));
    test('sign toggles the entry', () => expect(run('5S').display, '-5'));
    test('sign toggles back', () => expect(run('5SS').display, '5'));
    test('sign on zero does nothing', () => expect(run('0S').display, '0'));
    test('sign toggles a result', () => expect(run('2+3=S').display, '-5'));
  });

  group('rounding and formatting', () {
    test('binary artifacts are rounded away',
        () => expect(run('0.1+0.2=').display, '0.3'));
    test('one third fits the cap with rounding',
        () => expect(run('1/3=').display, '0.33333333333'));
    test('two thirds rounds up',
        () => expect(run('2/3=').display, '0.66666666667'));
    test('one seventh rounds up',
        () => expect(run('1/7=').display, '0.14285714286'));
    test('trailing fraction zeros are dropped',
        () => expect(run('1/8=').display, '0.125'));
    test('large result keeps the comma grouping',
        () => expect(run('999999*999999=').display, '999,998,000,001'));
    test('twelve digit result is kept',
        () => expect(run('999999*1000000=').display, '999,999,000,000'));
    test('result beyond twelve digits is an error',
        () => expect(run('999999999999*2=').display, 'Error'));
    test('negative twelve digit result is an error',
        () => expect(run('999999999999*2S=').display, 'Error'));
    test('display font shrinks with length', () {
      expect(displayFontSize(1), 48);
      expect(displayFontSize(8), 48);
      expect(displayFontSize(12), 36);
      expect(displayFontSize(15), 27);
      expect(displayFontSize(30), 24);
    });
  });

  group('error recovery', () {
    test('divide by zero shows Error',
        () => expect(run('5/0=').display, 'Error'));
    test('zero divided by zero shows Error',
        () => expect(run('0/0=').display, 'Error'));
    test('a digit after Error starts a new entry', () {
      final engine = run('5/0=5');
      expect(engine.display, '5');
      expect(engine.isError, isFalse);
    });
    test('AC clears Error', () => expect(run('5/0=C').display, '0'));
    test('decimal after Error starts zero point', () {
      final engine = run('5/0=.');
      expect(engine.display, '0.');
    });
    test('operators are ignored while in Error', () {
      final engine = run('5/0=+');
      expect(engine.display, 'Error');
    });
    test('equals is ignored while in Error', () {
      final engine = run('5/0==');
      expect(engine.display, 'Error');
    });
    test('percent is ignored while in Error', () {
      final engine = run('5/0=%');
      expect(engine.display, 'Error');
    });
    test('sign is ignored while in Error', () {
      final engine = run('5/0=S');
      expect(engine.display, 'Error');
    });
  });

  group('raw entry for the PIN check', () {
    test('raw entry has no grouping', () {
      expect(run('4826').rawEntry, '4826');
    });

    test('raw entry keeps the decimal point', () {
      expect(run('12.5').rawEntry, '12.5');
    });

    test('raw entry keeps a sign', () {
      expect(run('5S').rawEntry, '-5');
    });

    test('zero padded entry is not the PIN text', () {
      expect(run('04826').rawEntry, '4826');
    });
  });
}
