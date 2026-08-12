import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'senka_state.dart';

abstract interface class SenkaStore {
  Future<SenkaState?> load();
  Future<void> save(SenkaState state);
}

class SharedPreferencesSenkaStore implements SenkaStore {
  SharedPreferencesSenkaStore(this.preferences);

  static const _key = 'senka.archive.v1';
  final SharedPreferences preferences;

  static Future<SharedPreferencesSenkaStore> create() async =>
      SharedPreferencesSenkaStore(await SharedPreferences.getInstance());

  @override
  Future<SenkaState?> load() async {
    final raw = preferences.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return SenkaState.fromJson(jsonDecode(raw));
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> save(SenkaState state) =>
      preferences.setString(_key, jsonEncode(state.toJson()));
}
