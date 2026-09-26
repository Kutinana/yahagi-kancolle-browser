import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../account/account_session.dart';
import 'exp_calc_models.dart';

abstract interface class ExpTrackerStore {
  Future<List<ExpCalcTrackItem>> loadTrackItems(int memberId);
  Future<bool> saveTrackItems(int memberId, List<ExpCalcTrackItem> items);
}

final class SharedPreferencesExpTrackerStore implements ExpTrackerStore {
  SharedPreferencesExpTrackerStore({AccountSession? accountSession})
    : accountSession = accountSession ?? AccountSession.shared;

  final AccountSession accountSession;
  static const _key = 'exp_calc.track_items.v1';

  @override
  Future<List<ExpCalcTrackItem>> loadTrackItems(int memberId) async {
    final scope = accountSession.current;
    if (!scope.isKnown || scope.memberId != memberId) {
      return <ExpCalcTrackItem>[];
    }
    final prefs = await SharedPreferences.getInstance();
    if (!accountSession.isCurrent(scope)) return <ExpCalcTrackItem>[];
    final raw = prefs.getString(scope.key(_key));
    if (raw == null || raw.trim().isEmpty) return <ExpCalcTrackItem>[];

    try {
      final list = jsonDecode(raw);
      if (list is! List || list.any((item) => item is! Map<String, dynamic>)) {
        throw const FormatException('Invalid EXP tracking data');
      }
      return list
          .cast<Map<String, dynamic>>()
          .map(ExpCalcTrackItem.fromJson)
          .toList();
    } catch (_) {
      throw const FormatException('Unable to read EXP tracking data');
    }
  }

  @override
  Future<bool> saveTrackItems(
    int memberId,
    List<ExpCalcTrackItem> items,
  ) async {
    final scope = accountSession.current;
    if (!scope.isKnown || scope.memberId != memberId) return false;
    final prefs = await SharedPreferences.getInstance();
    if (!accountSession.isCurrent(scope)) return false;
    final jsonString = jsonEncode(items.map((e) => e.toJson()).toList());
    final saved = await prefs.setString(scope.key(_key), jsonString);
    if (!saved) {
      throw StateError('Unable to save EXP tracking data');
    }
    return accountSession.isCurrent(scope);
  }
}
