import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/main.dart';

void main() {
  group('Usage labels localization', () {
    test('English formatting', () {
      final session = L10n.f(
        'ui_session_usage',
        {'used': '1', 'max': '3'},
        const Locale('en'),
        const {},
      );
      final total = L10n.f(
        'ui_total_usage',
        {'used': '2', 'max': '5'},
        const Locale('en'),
        const {},
      );
      expect(session, 'Session: 1 / 3');
      expect(total, 'Total: 2 / 5');
    });

    test('French formatting with space before colon', () {
      final session = L10n.f(
        'ui_session_usage',
        {'used': '1', 'max': '3'},
        const Locale('fr'),
        const {},
      );
      final total = L10n.f(
        'ui_total_usage',
        {'used': '2', 'max': '5'},
        const Locale('fr'),
        const {},
      );
      expect(session, 'Session : 1 / 3');
      expect(total, 'Total : 2 / 5');
    });

    test('German formatting', () {
      final session = L10n.f(
        'ui_session_usage',
        {'used': '4', 'max': '7'},
        const Locale('de'),
        const {},
      );
      final total = L10n.f(
        'ui_total_usage',
        {'used': '6', 'max': '9'},
        const Locale('de'),
        const {},
      );
      expect(session, 'Sitzung: 4 / 7');
      expect(total, 'Gesamt: 6 / 9');
    });

    test('Arabic RTL formatting', () {
      final session = L10n.f(
        'ui_session_usage',
        {'used': '1', 'max': '3'},
        const Locale('ar'),
        const {},
      );
      final total = L10n.f(
        'ui_total_usage',
        {'used': '2', 'max': '5'},
        const Locale('ar'),
        const {},
      );
      expect(session, 'الجلسة: 1 / 3');
      expect(total, 'الإجمالي: 2 / 5');
    });

    test('Chinese fullwidth colon', () {
      final session = L10n.f(
        'ui_session_usage',
        {'used': '1', 'max': '3'},
        const Locale('zh'),
        const {},
      );
      final total = L10n.f(
        'ui_total_usage',
        {'used': '2', 'max': '5'},
        const Locale('zh'),
        const {},
      );
      expect(session, '会话：1 / 3');
      expect(total, '总计：2 / 5');
    });

    test('Tok Pisin formatting', () {
      final session = L10n.f(
        'ui_session_usage',
        {'used': '1', 'max': '3'},
        const Locale('tpi'),
        const {},
      );
      final total = L10n.f(
        'ui_total_usage',
        {'used': '2', 'max': '5'},
        const Locale('tpi'),
        const {},
      );
      expect(session, 'Sesen: 1 / 3');
      expect(total, 'Olgeta: 2 / 5');
    });
  });
}
