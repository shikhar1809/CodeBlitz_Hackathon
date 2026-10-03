import 'package:flutter_test/flutter_test.dart';
import 'package:winger/domain/sig.dart';
import 'package:winger/domain/sig_parser.dart';

const m = DoseSlot.morning;
const a = DoseSlot.afternoon;
const e = DoseSlot.evening;
const n = DoseSlot.night;

void main() {
  Sig sig(String s) => SigParser.parseSig(s);

  group('frequency codes', () {
    test('OD is once, in the morning', () => expect(sig('OD').slots, [m]));
    test('BD is morning and night', () => expect(sig('BD').slots, [m, n]));
    test('TDS is three times', () => expect(sig('TDS').slots, [m, a, n]));
    test('TID is three times', () => expect(sig('tid').slots, [m, a, n]));
    test('QID is four times', () => expect(sig('QID').slots, [m, a, e, n]));
    test('HS is at night', () => expect(sig('HS').slots, [n]));
    test('nocte is at night', () => expect(sig('nocte').slots, [n]));
    test('frequency codes leave nothing unresolved', () {
      for (final code in ['OD', 'BD', 'TDS', 'QID', 'HS']) {
        expect(sig(code).unresolved, isEmpty, reason: code);
      }
    });
  });

  group('positional', () {
    test('1-0-1', () => expect(sig('1-0-1').slots, [m, n]));
    test('1-1-1', () => expect(sig('1-1-1').slots, [m, a, n]));
    test('0-0-1', () => expect(sig('0-0-1').slots, [n]));
    test('spaced 1 - 0 - 1', () => expect(sig('1 - 0 - 1').slots, [m, n]));
    test('four positions', () => expect(sig('1-0-0-1').slots, [m, n]));
    test('2-0-2 is two tablets', () => expect(sig('2-0-2').unitsPerDose, 2));
    test('½-0-½ is half a tablet', () {
      expect(sig('½-0-½').unitsPerDose, .5);
      expect(sig('½-0-½').slots, [m, n]);
    });
    test('1-0-2 asks a person: one number cannot carry two amounts', () {
      expect(sig('1-0-2').unresolved, ['1-0-2']);
    });
    test('a positional pattern beats a named frequency', () {
      expect(sig('1-0-1 OD').slots, [m, n]);
    });
  });

  group('food', () {
    test(
      'a/c is before food',
      () => expect(sig('a/c').food, FoodTiming.before),
    );
    test('p/c is after food', () => expect(sig('p/c').food, FoodTiming.after));
    test('p.c. with full stops', () {
      expect(sig('1-0-1 p.c.').food, FoodTiming.after);
    });
    test('AC in capitals', () => expect(sig('OD AC').food, FoodTiming.before));
    test('khane ke baad', () {
      expect(sig('khane ke baad').food, FoodTiming.after);
    });
    test('khali pet', () => expect(sig('khali pet').food, FoodTiming.before));
    test('before breakfast is also the morning', () {
      final s = sig('before breakfast');
      expect(s.food, FoodTiming.before);
      expect(s.slots, [m]);
    });
    test('unspecified when nobody said', () {
      expect(sig('BD').food, FoodTiming.unspecified);
    });
  });

  group('SOS and STAT', () {
    test('SOS has no slots and no alarm', () {
      final s = sig('SOS');
      expect(s.sos, isTrue);
      expect(s.slots, isEmpty);
      expect(s.hasTiming, isTrue);
    });
    test('SOS wins over a slot word: never invent a time', () {
      expect(sig('SOS at night').slots, isEmpty);
    });
    test('as needed', () => expect(sig('as needed').sos, isTrue));
    test('dard hone par', () => expect(sig('dard hone par').sos, isTrue));
    test('STAT', () => expect(sig('STAT').stat, isTrue));
  });

  group('duration and interval', () {
    test('x 10 days', () => expect(sig('BD x 10 days').durationDays, 10));
    test('x10days', () => expect(sig('BD x10days').durationDays, 10));
    test('for 5 days', () => expect(sig('OD for 5 days').durationDays, 5));
    test('2 weeks', () => expect(sig('OD 2 weeks').durationDays, 14));
    test('1 month', () => expect(sig('OD x 1 month').durationDays, 30));
    test('for a month', () => expect(sig('for a month').durationDays, 30));
    test('5 din', () => expect(sig('subah 5 din').durationDays, 5));
    test(
      'alternate days',
      () => expect(sig('OD alternate days').everyNDays, 2),
    );
    test('alt days', () => expect(sig('alt days').everyNDays, 2));
    test('ek din chhod ke', () {
      expect(sig('subah ek din chhod ke').everyNDays, 2);
    });
    test('every 3 days', () => expect(sig('every 3 days').everyNDays, 3));
    test('weekly', () => expect(sig('weekly').everyNDays, 7));
  });

  group('Hindi and Hinglish, as a doctor says it', () {
    test('subah ek', () {
      final s = sig('subah ek');
      expect(s.slots, [m]);
      expect(s.unitsPerDose, 1);
      expect(s.unresolved, isEmpty);
    });
    test('subah aur raat — "aur" is a connector, not a problem', () {
      final s = sig('subah aur raat khane ke baad');
      expect(s.slots, [m, n]);
      expect(s.food, FoodTiming.after);
      expect(s.unresolved, isEmpty);
    });
    test('raat ko do goli', () {
      final s = sig('raat ko do goli');
      expect(s.slots, [n]);
      expect(s.unitsPerDose, 2);
    });
    test('din mein teen baar', () {
      expect(sig('din mein teen baar').slots, [m, a, n]);
    });
    test('aadhi goli subah', () {
      expect(sig('aadhi goli subah').unitsPerDose, .5);
    });
    test('one in the morning', () {
      final s = sig('one in the morning after food');
      expect(s.slots, [m]);
      expect(s.food, FoodTiming.after);
      expect(s.unresolved, isEmpty);
    });
    test('twice a day', () => expect(sig('twice a day').slots, [m, n]));
    test('"forty one" with no pause is forty-one', () {
      expect(SigParser.parseLine('Telma forty one').name, 'TELMA 41');
    });
    test('the English verb "do" is not the number two', () {
      expect(sig('do not stop').unitsPerDose, 1);
    });
  });

  group('lines with a name', () {
    ParsedLine line(String s) => SigParser.parseLine(s);

    test('Tab Telma 40 1-0-1 p/c', () {
      final l = line('Tab Telma 40  1-0-1  p/c');
      expect(l.name, 'TELMA 40');
      expect(l.strength, '40');
      expect(l.form, 'tab');
      expect(l.sig.slots, [m, n]);
      expect(l.sig.food, FoodTiming.after);
      expect(l.sig.unresolved, isEmpty);
    });

    test('trap 1: "TELMA 40 TAB" is a strength, not forty tablets', () {
      final l = line('TELMA 40 TAB');
      expect(l.name, 'TELMA 40');
      expect(l.sig.unitsPerDose, 1);
      expect(l.sig.unresolved, isEmpty);
    });

    test('trap 2: a bill quantity does not land in the name', () {
      final l = line('TELMA 40 TAB  30 NOS');
      expect(l.name, 'TELMA 40');
      expect(l.sig.unresolved, isEmpty);
    });

    test('trap 3: double-space columns and prices are cut', () {
      final l = line('GLYCOMET 500 SR   1x15   45.50');
      expect(l.name, 'GLYCOMET 500 SR');
      expect(l.sig.unresolved, isEmpty);
    });

    test('trap 4: Hindi number words and connectors do not flag a row', () {
      final l = line('Glycomet paanch sau subah aur raat');
      expect(l.name, isNotNull);
      expect(l.sig.slots, [m, n]);
    });

    test('spoken strength: "Telma forty, one in the morning"', () {
      final l = line('Telma forty, one in the morning');
      expect(l.name, 'TELMA 40');
      expect(l.sig.slots, [m]);
    });

    test('spoken strength: "Glycomet five hundred"', () {
      expect(line('Glycomet five hundred twice a day').name, 'GLYCOMET 500');
    });

    test('spoken strength: "Dolo six fifty"', () {
      expect(line('Dolo six fifty SOS').name, 'DOLO 650');
    });

    test('a single-digit strength is kept: Amlo 5', () {
      expect(line('Amlo 5 OD').name, 'AMLO 5');
    });

    test('a single digit before "tab" is a count: Crocin 2 tab', () {
      final l = line('Crocin 2 tab SOS');
      expect(l.name, 'CROCIN');
      expect(l.sig.unitsPerDose, 2);
    });

    test('printed, a single digit before TAB is a strength: AMLONG 5 TAB', () {
      final l = SigParser.parseLine(
        '3 AMLONG 5 TAB  30 NOS  60.00',
        printed: true,
      );
      expect(l.name, 'AMLONG 5');
      expect(l.form, 'tab');
      expect(l.sig.unitsPerDose, 1);
    });

    test('said aloud, the count still keeps its dosage form as evidence', () {
      expect(line('Crocin 2 tab SOS').form, 'tab');
    });

    test('a variant stays in the name: GLYCOMET GP 1 is not GLYCOMET', () {
      expect(line('Tab Glycomet GP1 BD').name, 'GLYCOMET GP1');
    });

    test('numbering is skipped', () {
      expect(line('1) Tab Pan 40 OD a/c').name, 'PAN 40');
    });

    test('the doctor\'s purpose is quoted, never inferred', () {
      final l = line('Telma 40 subah, for BP');
      expect(l.purpose, 'BP');
      expect(l.sig.unresolved, isEmpty);
    });

    test('"sugar ke liye"', () {
      expect(line('Glycomet 500 raat sugar ke liye').purpose, 'Sugar');
    });

    test('a purpose never swallows the timing next to it', () {
      final l = line('Telma 40 morning after food BP ke liye');
      expect(l.purpose, 'BP');
      expect(l.sig.food, FoodTiming.after);
      final m = line('Glycomet 500 for sugar subah');
      expect(m.purpose, 'Sugar');
      expect(m.sig.slots, [DoseSlot.morning]);
      expect(line('Telma 40 for blood pressure OD').purpose, 'Blood pressure');
    });

    test('"for 10 days" is a duration, not a purpose', () {
      final l = line('Augmentin 625 BD for 10 days');
      expect(l.purpose, isNull);
      expect(l.sig.durationDays, 10);
    });

    test('a bill total is not a medicine', () {
      expect(line('TOTAL 450.00').name, isNull);
    });

    test('a substitution is left for a person to see', () {
      final l = line('Telma ki jagah Telmisartan de diya');
      expect(l.name, 'TELMA');
      expect(l.sig.unresolved, containsAll(['jagah', 'telmisartan']));
    });
  });

  test('a Sig round-trips through JSON, omitting defaults', () {
    const s = Sig(
      slots: [m, n],
      food: FoodTiming.after,
      durationDays: 30,
      everyNDays: 2,
    );
    final json = s.toJson();
    expect(json.containsKey('sos'), isFalse);
    expect(json.containsKey('unresolved'), isFalse);
    expect(Sig.fromJson(json), s);
  });
}
