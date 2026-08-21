import 'package:shared_preferences/shared_preferences.dart';

enum AnchorageNotificationMode {
  twentyMinutes,
  allRepaired,
  both;

  String get storageValue => name;

  static AnchorageNotificationMode fromStorage(String? value) {
    return AnchorageNotificationMode.values.firstWhere(
      (m) => m.storageValue == value,
      orElse: () => AnchorageNotificationMode.twentyMinutes,
    );
  }
}

class NotificationSettings {
  const NotificationSettings({
    this.master = true,
    this.sound = true,
    this.vibration = true,
    this.ongoingLive = true,
    this.showProgress = true,
    this.showPercent = true,
    this.showCountdown = true,
    this.expedition = true,
    this.expeditionPreemptSeconds = 60,
    this.repair = true,
    this.repairPreemptSeconds = 0,
    this.anchorage = true,
    this.anchorageMode = AnchorageNotificationMode.twentyMinutes,
    this.construction = true,
    this.morale = true,
  });

  final bool master;
  final bool sound;
  final bool vibration;
  final bool ongoingLive;
  final bool showProgress;
  final bool showPercent;
  final bool showCountdown;
  final bool expedition;
  final int expeditionPreemptSeconds;
  final bool repair;
  final int repairPreemptSeconds;
  final bool anchorage;
  final AnchorageNotificationMode anchorageMode;
  final bool construction;
  final bool morale;

  NotificationSettings copyWith({
    bool? master,
    bool? sound,
    bool? vibration,
    bool? ongoingLive,
    bool? showProgress,
    bool? showPercent,
    bool? showCountdown,
    bool? expedition,
    int? expeditionPreemptSeconds,
    bool? repair,
    int? repairPreemptSeconds,
    bool? anchorage,
    AnchorageNotificationMode? anchorageMode,
    bool? construction,
    bool? morale,
  }) {
    return NotificationSettings(
      master: master ?? this.master,
      sound: sound ?? this.sound,
      vibration: vibration ?? this.vibration,
      ongoingLive: ongoingLive ?? this.ongoingLive,
      showProgress: showProgress ?? this.showProgress,
      showPercent: showPercent ?? this.showPercent,
      showCountdown: showCountdown ?? this.showCountdown,
      expedition: expedition ?? this.expedition,
      expeditionPreemptSeconds:
          expeditionPreemptSeconds ?? this.expeditionPreemptSeconds,
      repair: repair ?? this.repair,
      repairPreemptSeconds: repairPreemptSeconds ?? this.repairPreemptSeconds,
      anchorage: anchorage ?? this.anchorage,
      anchorageMode: anchorageMode ?? this.anchorageMode,
      construction: construction ?? this.construction,
      morale: morale ?? this.morale,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationSettings &&
          runtimeType == other.runtimeType &&
          master == other.master &&
          sound == other.sound &&
          vibration == other.vibration &&
          ongoingLive == other.ongoingLive &&
          showProgress == other.showProgress &&
          showPercent == other.showPercent &&
          showCountdown == other.showCountdown &&
          expedition == other.expedition &&
          expeditionPreemptSeconds == other.expeditionPreemptSeconds &&
          repair == other.repair &&
          repairPreemptSeconds == other.repairPreemptSeconds &&
          anchorage == other.anchorage &&
          anchorageMode == other.anchorageMode &&
          construction == other.construction &&
          morale == other.morale;

  @override
  int get hashCode => Object.hash(
    master,
    sound,
    vibration,
    ongoingLive,
    showProgress,
    showPercent,
    showCountdown,
    expedition,
    expeditionPreemptSeconds,
    repair,
    repairPreemptSeconds,
    anchorage,
    anchorageMode,
    construction,
    morale,
  );
}

abstract interface class NotificationSettingsStore {
  Future<NotificationSettings> load();
  Future<void> save(NotificationSettings settings);
}

class SharedPreferencesNotificationSettingsStore
    implements NotificationSettingsStore {
  const SharedPreferencesNotificationSettingsStore();

  static const String _prefix = 'yahagi_notification_';
  static const String _keyMaster = '${_prefix}master';
  static const String _keySound = '${_prefix}sound';
  static const String _keyVibration = '${_prefix}vibration';
  static const String _keyOngoingLive = '${_prefix}ongoing_live';
  static const String _keyShowProgress = '${_prefix}show_progress';
  static const String _keyShowPercent = '${_prefix}show_percent';
  static const String _keyShowCountdown = '${_prefix}show_countdown';
  static const String _keyExpedition = '${_prefix}expedition';
  static const String _keyExpPreempt = '${_prefix}exp_preempt';
  static const String _keyRepair = '${_prefix}repair';
  static const String _keyRepairPreempt = '${_prefix}repair_preempt';
  static const String _keyAnchorage = '${_prefix}anchorage';
  static const String _keyAnchorageMode = '${_prefix}anchorage_mode';
  static const String _keyConstruction = '${_prefix}construction';
  static const String _keyMorale = '${_prefix}morale';

  @override
  Future<NotificationSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return NotificationSettings(
      master: prefs.getBool(_keyMaster) ?? true,
      sound: prefs.getBool(_keySound) ?? true,
      vibration: prefs.getBool(_keyVibration) ?? true,
      ongoingLive: prefs.getBool(_keyOngoingLive) ?? true,
      showProgress: prefs.getBool(_keyShowProgress) ?? true,
      showPercent: prefs.getBool(_keyShowPercent) ?? true,
      showCountdown: prefs.getBool(_keyShowCountdown) ?? true,
      expedition: prefs.getBool(_keyExpedition) ?? true,
      expeditionPreemptSeconds: prefs.getInt(_keyExpPreempt) ?? 60,
      repair: prefs.getBool(_keyRepair) ?? true,
      repairPreemptSeconds: prefs.getInt(_keyRepairPreempt) ?? 0,
      anchorage: prefs.getBool(_keyAnchorage) ?? true,
      anchorageMode: AnchorageNotificationMode.fromStorage(
        prefs.getString(_keyAnchorageMode),
      ),
      construction: prefs.getBool(_keyConstruction) ?? true,
      morale: prefs.getBool(_keyMorale) ?? true,
    );
  }

  @override
  Future<void> save(NotificationSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setBool(_keyMaster, settings.master),
      prefs.setBool(_keySound, settings.sound),
      prefs.setBool(_keyVibration, settings.vibration),
      prefs.setBool(_keyOngoingLive, settings.ongoingLive),
      prefs.setBool(_keyShowProgress, settings.showProgress),
      prefs.setBool(_keyShowPercent, settings.showPercent),
      prefs.setBool(_keyShowCountdown, settings.showCountdown),
      prefs.setBool(_keyExpedition, settings.expedition),
      prefs.setInt(_keyExpPreempt, settings.expeditionPreemptSeconds),
      prefs.setBool(_keyRepair, settings.repair),
      prefs.setInt(_keyRepairPreempt, settings.repairPreemptSeconds),
      prefs.setBool(_keyAnchorage, settings.anchorage),
      prefs.setString(_keyAnchorageMode, settings.anchorageMode.storageValue),
      prefs.setBool(_keyConstruction, settings.construction),
      prefs.setBool(_keyMorale, settings.morale),
    ]);
  }
}
