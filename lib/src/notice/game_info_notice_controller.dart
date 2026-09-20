import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../bridge/captured_api_event.dart';
import '../game_state/game_api_decoder.dart';
import '../game_state/game_api_event_pipeline.dart';
import '../game_state/game_state.dart';
import '../settings/layout_settings_controller.dart';
import '../toolbox/exp_calc/ship_exp_table.dart';
import '../widgets/top_notice.dart';

/// Intercepts game events and dispatches unified top bar notices for:
/// - Equipment development (single & 3-batch with slot-by-slot status)
/// - Equipment improvement (success and failure)
/// - Ship modernization (increases, MAX flags, failure)
/// - Marriage (luck bonus and remaining to cap)
/// - Sortie safety checks (ship/equipment capacity warnings)
/// - Practice assistant (opponent base experience and training cruiser bonus)
class GameInfoNoticeController implements GameApiEventConsumer {
  GameInfoNoticeController({
    required this.stateProvider,
    required this.layoutSettingsController,
    required this.topNoticeController,
  });

  final GameState Function() stateProvider;
  final LayoutSettingsController layoutSettingsController;
  final TopNoticeController topNoticeController;

  Future<void> _queue = Future<void>.value();

  @override
  Future<void> get idle => _queue;

  @override
  bool supportsPath(String path) {
    return path == '/kcsapi/api_req_kousyou/createitem' ||
        path == '/kcsapi/api_req_kousyou/remodel_slot' ||
        path == '/kcsapi/api_req_kaisou/powerup' ||
        path == '/kcsapi/api_req_kaisou/marriage' ||
        path == '/kcsapi/api_get_member/mapinfo' ||
        path == '/kcsapi/api_req_member/get_practice_enemyinfo';
  }

  @override
  void accept(CapturedApiEvent event) {
    if (!layoutSettingsController.topNoticeEnabled) {
      return;
    }

    // Immediately and synchronously capture the current state before any asynchronous
    // processing or pipeline reducers have a chance to update the state.
    final stateBefore = stateProvider();

    _queue = _queue.then((_) async {
      try {
        final rawData = GameApiDecoder.decodeEventData(event);
        if (rawData is! Map<String, Object?>) return;

        switch (event.path) {
          case '/kcsapi/api_req_kousyou/createitem':
            _handleDevelopment(rawData, stateBefore);
            break;
          case '/kcsapi/api_req_kousyou/remodel_slot':
            _handleEquipmentImprovement(rawData);
            break;
          case '/kcsapi/api_req_kaisou/powerup':
            _handleModernization(rawData, event, stateBefore);
            break;
          case '/kcsapi/api_req_kaisou/marriage':
            _handleMarriage(rawData, event, stateBefore);
            break;
          case '/kcsapi/api_get_member/mapinfo':
            _handleSortieCheck(stateBefore);
            break;
          case '/kcsapi/api_req_member/get_practice_enemyinfo':
            _handlePracticeEnemyInfo(rawData, stateBefore);
            break;
        }
      } catch (e, stack) {
        debugPrint(
          'GameInfoNoticeController error handling ${event.path}: $e\n$stack',
        );
      }
    });
  }

  void postNotice({
    required String message,
    required TopNoticeTone tone,
    IconData? icon,
    Color? color,
    Duration appendWithin = const Duration(milliseconds: 500),
    String? replacementKey,
  }) {
    if (!layoutSettingsController.topNoticeEnabled) return;
    topNoticeController.show(
      message: message,
      tone: tone,
      customIcon: icon,
      customColor: color,
      duration: Duration(
        seconds: layoutSettingsController.topNoticeDurationSeconds,
      ),
      appendWithin: appendWithin,
      replacementKey: replacementKey,
    );
  }

  AppLocalizations _getL10n() {
    final code = layoutSettingsController.localeCode;
    if (code == 'zh_Hant') {
      return lookupAppLocalizations(
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      );
    } else if (code == 'ja') {
      return lookupAppLocalizations(const Locale('ja'));
    }
    return lookupAppLocalizations(const Locale('zh'));
  }

  static int _asInt(dynamic val, [int fallback = 0]) {
    if (val == null) return fallback;
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) {
      return int.tryParse(val) ?? fallback;
    }
    return fallback;
  }

  void _handleDevelopment(Map<String, Object?> data, GameState state) {
    final l10n = _getL10n();
    final rawGetItems = data['api_get_items'];
    if (rawGetItems is List && rawGetItems.isNotEmpty) {
      // 3-batch development
      final results = <String>[];
      var successCount = 0;
      for (final item in rawGetItems) {
        Map? slotItem;
        if (item is Map) {
          final nestedSlotItem = item['api_slot_item'];
          if (nestedSlotItem is Map && _asInt(item['api_create_flag']) == 1) {
            slotItem = nestedSlotItem;
          } else if (item.containsKey('api_slotitem_id')) {
            slotItem = item;
          }
        }

        final masterId = slotItem == null
            ? 0
            : _asInt(slotItem['api_slotitem_id']);
        if (masterId > 0) {
          successCount++;
          final name =
              state.masterSlotItems[masterId]?.name ??
              l10n.noticeDevDefaultName;
          results.add(name);
        } else {
          results.add(l10n.noticeDevSlotFailed);
        }
      }

      if (successCount == 0) {
        postNotice(
          message: l10n.noticeDevFailedPenguin,
          tone: TopNoticeTone.warning,
        );
      } else {
        postNotice(message: results.join(' / '), tone: TopNoticeTone.success);
      }
      return;
    }

    // Single development
    final createFlag = _asInt(data['api_create_flag']);
    if (createFlag == 1) {
      final slotItem = data['api_slot_item'];
      final masterId = slotItem is Map
          ? _asInt(slotItem['api_slotitem_id'])
          : 0;
      final name =
          state.masterSlotItems[masterId]?.name ?? l10n.noticeDevDefaultName;
      postNotice(
        message: l10n.noticeDevSuccess(name),
        tone: TopNoticeTone.success,
      );
    } else {
      postNotice(message: l10n.noticeDevFailed, tone: TopNoticeTone.warning);
    }
  }

  void _handleEquipmentImprovement(Map<String, Object?> data) {
    final l10n = _getL10n();
    final succeeded = _asInt(data['api_remodel_flag']) == 1;
    postNotice(
      message: succeeded
          ? l10n.noticeEquipImproveSuccess
          : l10n.noticeEquipImproveFailed,
      tone: succeeded ? TopNoticeTone.success : TopNoticeTone.warning,
      appendWithin: const Duration(milliseconds: 500),
    );
  }

  void _handleModernization(
    Map<String, Object?> data,
    CapturedApiEvent event,
    GameState state,
  ) {
    final l10n = _getL10n();
    final flag = _asInt(data['api_powerup_flag']);
    if (flag == 0) {
      postNotice(message: l10n.noticeModFailed, tone: TopNoticeTone.warning);
      return;
    }

    final rawShip = data['api_ship'];
    if (rawShip is! Map) {
      postNotice(message: l10n.noticeModSuccess, tone: TopNoticeTone.success);
      return;
    }

    final shipId = _asInt(rawShip['api_id']);
    final oldShip = state.ships[shipId];
    if (oldShip == null) {
      postNotice(message: l10n.noticeModSuccess, tone: TopNoticeTone.success);
      return;
    }

    final rawMasterId = _asInt(rawShip['api_ship_id']);
    final masterId = rawMasterId > 0 ? rawMasterId : oldShip.masterId;
    final master = state.masterShips[masterId];
    final oldKyouka = oldShip.modernization;

    final rawKaryoku = rawShip['api_karyoku'];
    final rawRaisou = rawShip['api_raisou'];
    final rawTaiku = rawShip['api_taiku'];
    final rawSoukou = rawShip['api_soukou'];
    final rawLucky = rawShip['api_lucky'];
    final rawMaxHp = rawShip['api_maxhp'];
    final rawTaisen = rawShip['api_taisen'];

    final newFirepower = rawKaryoku is List && rawKaryoku.isNotEmpty
        ? _asInt(rawKaryoku[0])
        : oldShip.firepower;
    final maxFirepower = rawKaryoku is List && rawKaryoku.length > 1
        ? _asInt(rawKaryoku[1])
        : oldShip.firepowerMax;

    final newTorpedo = rawRaisou is List && rawRaisou.isNotEmpty
        ? _asInt(rawRaisou[0])
        : oldShip.torpedo;
    final maxTorpedo = rawRaisou is List && rawRaisou.length > 1
        ? _asInt(rawRaisou[1])
        : oldShip.torpedoMax;

    final newAntiAir = rawTaiku is List && rawTaiku.isNotEmpty
        ? _asInt(rawTaiku[0])
        : oldShip.antiAir;
    final maxAntiAir = rawTaiku is List && rawTaiku.length > 1
        ? _asInt(rawTaiku[1])
        : oldShip.antiAirMax;

    final newArmor = rawSoukou is List && rawSoukou.isNotEmpty
        ? _asInt(rawSoukou[0])
        : oldShip.armor;
    final maxArmor = rawSoukou is List && rawSoukou.length > 1
        ? _asInt(rawSoukou[1])
        : oldShip.armorMax;

    final newLuck = rawLucky is List && rawLucky.isNotEmpty
        ? _asInt(rawLucky[0])
        : oldShip.luck;
    final maxLuck = rawLucky is List && rawLucky.length > 1
        ? _asInt(rawLucky[1])
        : oldShip.luckMax;

    final int newHp;
    final int maxHp;
    if (rawMaxHp is List && rawMaxHp.isNotEmpty) {
      newHp = _asInt(rawMaxHp[0]);
      maxHp = rawMaxHp.length > 1 ? _asInt(rawMaxHp[1]) : 0;
    } else if (rawMaxHp != null) {
      newHp = _asInt(rawMaxHp);
      maxHp = 0;
    } else {
      newHp = oldShip.maxHp;
      maxHp = 0;
    }

    final int newAsw;
    final int maxAsw;
    if (rawTaisen is List && rawTaisen.isNotEmpty) {
      newAsw = _asInt(rawTaisen[0]);
      maxAsw = rawTaisen.length > 1 ? _asInt(rawTaisen[1]) : 0;
    } else if (rawTaisen != null) {
      newAsw = _asInt(rawTaisen);
      maxAsw = 0;
    } else {
      newAsw = oldShip.antiSub;
      maxAsw = 0;
    }

    final rawKyouka = rawShip['api_kyouka'];
    final kyoukaList = rawKyouka is List
        ? rawKyouka.map(_asInt).toList()
        : null;

    final parts = <String>[];

    // Firepower (Index 0)
    final int fpDelta;
    final bool isFpMax;
    if (kyoukaList != null && kyoukaList.isNotEmpty) {
      fpDelta = oldKyouka.isNotEmpty
          ? (kyoukaList[0] - oldKyouka[0])
          : (newFirepower - oldShip.firepower);
      final remaining = master?.remainingModernization(0, kyoukaList[0]);
      isFpMax = remaining != null
          ? remaining <= 0
          : (maxFirepower > 0 && newFirepower >= maxFirepower);
    } else {
      fpDelta = newFirepower - oldShip.firepower;
      isFpMax = maxFirepower > 0 && newFirepower >= maxFirepower;
    }
    if (fpDelta > 0) {
      parts.add('${l10n.statFirepower} ▲ $fpDelta${isFpMax ? ' (MAX)' : ''}');
    }

    // Torpedo (Index 1)
    final int tpDelta;
    final bool isTpMax;
    if (kyoukaList != null && kyoukaList.length > 1) {
      tpDelta = oldKyouka.length > 1
          ? (kyoukaList[1] - oldKyouka[1])
          : (newTorpedo - oldShip.torpedo);
      final remaining = master?.remainingModernization(1, kyoukaList[1]);
      isTpMax = remaining != null
          ? remaining <= 0
          : (maxTorpedo > 0 && newTorpedo >= maxTorpedo);
    } else {
      tpDelta = newTorpedo - oldShip.torpedo;
      isTpMax = maxTorpedo > 0 && newTorpedo >= maxTorpedo;
    }
    if (tpDelta > 0) {
      parts.add('${l10n.statTorpedo} ▲ $tpDelta${isTpMax ? ' (MAX)' : ''}');
    }

    // Anti-Air (Index 2)
    final int aaDelta;
    final bool isAaMax;
    if (kyoukaList != null && kyoukaList.length > 2) {
      aaDelta = oldKyouka.length > 2
          ? (kyoukaList[2] - oldKyouka[2])
          : (newAntiAir - oldShip.antiAir);
      final remaining = master?.remainingModernization(2, kyoukaList[2]);
      isAaMax = remaining != null
          ? remaining <= 0
          : (maxAntiAir > 0 && newAntiAir >= maxAntiAir);
    } else {
      aaDelta = newAntiAir - oldShip.antiAir;
      isAaMax = maxAntiAir > 0 && newAntiAir >= maxAntiAir;
    }
    if (aaDelta > 0) {
      parts.add('${l10n.statAntiAir} ▲ $aaDelta${isAaMax ? ' (MAX)' : ''}');
    }

    // Armor (Index 3)
    final int arDelta;
    final bool isArMax;
    if (kyoukaList != null && kyoukaList.length > 3) {
      arDelta = oldKyouka.length > 3
          ? (kyoukaList[3] - oldKyouka[3])
          : (newArmor - oldShip.armor);
      final remaining = master?.remainingModernization(3, kyoukaList[3]);
      isArMax = remaining != null
          ? remaining <= 0
          : (maxArmor > 0 && newArmor >= maxArmor);
    } else {
      arDelta = newArmor - oldShip.armor;
      isArMax = maxArmor > 0 && newArmor >= maxArmor;
    }
    if (arDelta > 0) {
      parts.add('${l10n.statArmor} ▲ $arDelta${isArMax ? ' (MAX)' : ''}');
    }

    // Luck (Index 4)
    final int luckDelta;
    final bool isLuckMax;
    if (kyoukaList != null && kyoukaList.length > 4) {
      luckDelta = oldKyouka.length > 4
          ? (kyoukaList[4] - oldKyouka[4])
          : (newLuck - oldShip.luck);
      final remaining = master?.remainingModernization(4, kyoukaList[4]);
      isLuckMax = remaining != null
          ? remaining <= 0
          : (maxLuck > 0 && newLuck >= maxLuck);
    } else {
      luckDelta = newLuck - oldShip.luck;
      isLuckMax = maxLuck > 0 && newLuck >= maxLuck;
    }
    if (luckDelta > 0) {
      parts.add('${l10n.statLuck} ▲ $luckDelta${isLuckMax ? ' (MAX)' : ''}');
    }

    // HP (Index 5)
    final int hpDelta;
    final bool isHpMax;
    final isMasterHpCap =
        master != null && master.maxHp > 0 && newHp >= master.maxHp;
    if (kyoukaList != null && kyoukaList.length > 5) {
      hpDelta = oldKyouka.length > 5
          ? (kyoukaList[5] - oldKyouka[5])
          : (newHp - oldShip.maxHp);
      final remaining = master?.remainingModernization(5, kyoukaList[5]);
      isHpMax =
          (remaining != null ? remaining <= 0 : kyoukaList[5] >= 2) ||
          isMasterHpCap ||
          (maxHp > 0 && newHp >= maxHp);
    } else {
      hpDelta = newHp - oldShip.maxHp;
      isHpMax = (maxHp > 0 && newHp >= maxHp) || isMasterHpCap;
    }
    if (hpDelta > 0) {
      parts.add('${l10n.statHp} ▲ $hpDelta${isHpMax ? ' (MAX)' : ''}');
    }

    // ASW (Index 6)
    final int aswDelta;
    final bool isAswMax;
    if (kyoukaList != null && kyoukaList.length > 6) {
      aswDelta = oldKyouka.length > 6
          ? (kyoukaList[6] - oldKyouka[6])
          : (newAsw - oldShip.antiSub);
      final remaining = master?.remainingModernization(6, kyoukaList[6]);
      isAswMax = remaining != null ? remaining <= 0 : kyoukaList[6] >= 9;
    } else {
      aswDelta = newAsw - oldShip.antiSub;
      isAswMax = maxAsw > 0 && newAsw >= maxAsw;
    }
    if (aswDelta > 0) {
      parts.add('${l10n.statAsw} ▲ $aswDelta${isAswMax ? ' (MAX)' : ''}');
    }

    if (parts.isEmpty) {
      // No observed increase is not proof of a cap (partial responses and
      // already-maxed individual stats are both possible).
      // Equipment can inflate total stats to their displayed maxima. Require
      // actual modernization values and master caps for the ordinary stats.
      final allStatsMax =
          master != null &&
          kyoukaList != null &&
          kyoukaList.length >= 7 &&
          List.generate(5, (index) => index).every((index) {
            final remaining = master.remainingModernization(
              index,
              kyoukaList[index],
            );
            return remaining != null && remaining <= 0;
          }) &&
          isHpMax &&
          isAswMax;
      postNotice(
        message: allStatsMax
            ? l10n.noticeModSuccessMaxCap
            : l10n.noticeModSuccess,
        tone: TopNoticeTone.success,
      );
    } else {
      postNotice(
        message: l10n.noticeModSuccessDetail(parts.join(' · ')),
        tone: TopNoticeTone.success,
      );
    }
  }

  void _handleMarriage(
    Map<String, Object?> data,
    CapturedApiEvent event,
    GameState state,
  ) {
    final l10n = _getL10n();
    final rawShip = data.containsKey('api_id')
        ? data
        : (data['api_ship'] ?? data['api_data']);
    if (rawShip is! Map) return;

    final shipId = _asInt(rawShip['api_id']);
    final oldShip = state.ships[shipId];
    if (oldShip == null) return;

    final rawLucky = rawShip['api_lucky'];
    final newLuck = rawLucky is List && rawLucky.isNotEmpty
        ? _asInt(rawLucky[0])
        : oldShip.luck;
    final maxLuck = rawLucky is List && rawLucky.length > 1
        ? _asInt(rawLucky[1])
        : oldShip.luckMax;

    final delta = newLuck - oldShip.luck;
    final remaining = maxLuck - newLuck;
    final arrow = delta > 4 ? '▲▲' : '▲';

    if (remaining <= 0) {
      postNotice(
        message: l10n.noticeMarriageLuckMax(arrow, delta),
        tone: TopNoticeTone.marriage,
      );
    } else {
      postNotice(
        message: l10n.noticeMarriageLuck(arrow, delta, remaining),
        tone: TopNoticeTone.marriage,
      );
    }
  }

  void _handleSortieCheck(GameState state) {
    final l10n = _getL10n();
    final maxShips = state.maxShipCount;
    final remainingShips = (maxShips != null && maxShips > 0)
        ? maxShips - state.ships.length
        : null;

    final maxItems = state.maxEquipmentCount;
    final remainingItems = (maxItems != null && maxItems > 0)
        ? maxItems - state.equipmentCapacityUsed
        : null;

    final shipFull = remainingShips != null && remainingShips <= 0;
    final itemFull = remainingItems != null && remainingItems <= 0;

    // Error priority: Full capacity
    if (shipFull && itemFull) {
      postNotice(
        message: l10n.noticeSortieShipAndItemFull,
        tone: TopNoticeTone.error,
      );
      return;
    }
    if (shipFull) {
      postNotice(message: l10n.noticeSortieShipFull, tone: TopNoticeTone.error);
      return;
    }
    if (itemFull) {
      postNotice(message: l10n.noticeSortieItemFull, tone: TopNoticeTone.error);
      return;
    }

    // 2. Warning: Low capacity (<= 5)
    final shipLow =
        remainingShips != null && remainingShips > 0 && remainingShips <= 5;
    final itemLow =
        remainingItems != null && remainingItems > 0 && remainingItems <= 5;

    if (shipLow && itemLow) {
      postNotice(
        message: l10n.noticeSortieShipAndItemLow(
          remainingShips,
          remainingItems,
        ),
        tone: TopNoticeTone.warning,
      );
      return;
    }
    if (shipLow) {
      postNotice(
        message: l10n.noticeSortieShipLow(remainingShips),
        tone: TopNoticeTone.warning,
      );
      return;
    }
    if (itemLow) {
      postNotice(
        message: l10n.noticeSortieItemLow(remainingItems),
        tone: TopNoticeTone.warning,
      );
      return;
    }
  }

  void _handlePracticeEnemyInfo(Map<String, Object?> data, GameState state) {
    const noticeKey = 'practice-experience';
    final l10n = _getL10n();
    final rawDeck = data['api_deck'];
    if (rawDeck is! Map) {
      topNoticeController.removeByKey(noticeKey);
      return;
    }

    final rawShips = rawDeck['api_ships'];
    if (rawShips is! List || rawShips.isEmpty) {
      topNoticeController.removeByKey(noticeKey);
      return;
    }

    final firstShip = rawShips[0];
    final secondShip = rawShips.length > 1 ? rawShips[1] : null;

    final l1 = firstShip is Map ? _asInt(firstShip['api_level']) : 0;
    final l2 = secondShip is Map ? _asInt(secondShip['api_level']) : 0;

    if (l1 <= 0) {
      topNoticeController.removeByKey(noticeKey);
      return;
    }

    final baseExp = calculatePracticeBaseExp(l1, l2);
    if (baseExp <= 0) {
      topNoticeController.removeByKey(noticeKey);
      return;
    }

    final sExp = (baseExp * 1.2).round();
    final aExp = baseExp;

    // Check if player's fleet 1 contains Training Cruiser(s) (Katori / Kashima)
    final ctBonus = calculateFleetTrainingCruiserBonus(state);
    if (ctBonus > 0) {
      final multiplier = 1.0 + (ctBonus / 100.0);
      final boostedSExp = ((baseExp * 1.2) * multiplier).round();
      final boostedAExp = (baseExp * multiplier).round();
      final bonusStr = ctBonus % 1 == 0 ? '${ctBonus.toInt()}%' : '$ctBonus%';
      postNotice(
        message: l10n.noticePracticeExpCtBonus(
          boostedSExp,
          boostedAExp,
          bonusStr,
        ),
        tone: TopNoticeTone.info,
        replacementKey: noticeKey,
      );
    } else {
      postNotice(
        message: l10n.noticePracticeExp(sExp, aExp),
        tone: TopNoticeTone.info,
        replacementKey: noticeKey,
      );
    }
  }

  /// Calculates training cruiser bonus according to official 4-mode matrix:
  /// 1. CT Flagship only:
  ///    Lv 1~9: +5%, Lv 10~29: +8%, Lv 30~59: +12%, Lv 60~99: +15%, Lv 100+: +20%
  /// 2. CT Flagship + Companion:
  ///    Lv 1~9: +10%, Lv 10~29: +13%, Lv 30~59: +16%, Lv 60~99: +20%, Lv 100+: +25%
  /// 3. Companion 1 only (no CT flagship):
  ///    Lv 1~9: +3%, Lv 10~29: +5%, Lv 30~59: +7%, Lv 60~99: +10%, Lv 100+: +15%
  /// 4. Companion 2 only (no CT flagship):
  ///    Lv 1~9: +4%, Lv 10~29: +6%, Lv 30~59: +8%, Lv 60~99: +12%, Lv 100+: +17.5%
  static double calculateFleetTrainingCruiserBonus(GameState state) {
    if (state.fleets.isEmpty) return 0.0;
    final firstFleet = state.fleets[0];
    var isFlagshipCt = false;
    var accompanyingCtCount = 0;
    var flagshipLevel = 1;
    var maxAccompanyingCtLevel = 1;

    for (var i = 0; i < firstFleet.shipIds.length; i++) {
      final shipId = firstFleet.shipIds[i];
      final ship = state.ships[shipId];
      if (ship == null) continue;
      final master = state.masterShips[ship.masterId];
      final isCt =
          master?.shipTypeId == 21 ||
          (master?.name.contains('香取') ?? false) ||
          (master?.name.contains('鹿島') ?? false);

      if (isCt) {
        if (i == 0) {
          isFlagshipCt = true;
          flagshipLevel = ship.level;
        } else {
          accompanyingCtCount++;
          if (ship.level > maxAccompanyingCtLevel) {
            maxAccompanyingCtLevel = ship.level;
          }
        }
      }
    }

    if (!isFlagshipCt && accompanyingCtCount == 0) return 0.0;

    // 1. CT Flagship only
    if (isFlagshipCt && accompanyingCtCount == 0) {
      if (flagshipLevel >= 100) return 20.0;
      if (flagshipLevel >= 60) return 15.0;
      if (flagshipLevel >= 30) return 12.0;
      if (flagshipLevel >= 10) return 8.0;
      return 5.0;
    }

    // 2. CT Flagship + Companion
    if (isFlagshipCt && accompanyingCtCount > 0) {
      if (flagshipLevel >= 100) return 25.0;
      if (flagshipLevel >= 60) return 20.0;
      if (flagshipLevel >= 30) return 16.0;
      if (flagshipLevel >= 10) return 13.0;
      return 10.0;
    }

    // 3. Companion 1 only (no CT flagship)
    if (!isFlagshipCt && accompanyingCtCount == 1) {
      if (maxAccompanyingCtLevel >= 100) return 15.0;
      if (maxAccompanyingCtLevel >= 60) return 10.0;
      if (maxAccompanyingCtLevel >= 30) return 7.0;
      if (maxAccompanyingCtLevel >= 10) return 5.0;
      return 3.0;
    }

    // 4. Companion 2 only (no CT flagship)
    if (!isFlagshipCt && accompanyingCtCount >= 2) {
      if (maxAccompanyingCtLevel >= 100) return 17.5;
      if (maxAccompanyingCtLevel >= 60) return 12.0;
      if (maxAccompanyingCtLevel >= 30) return 8.0;
      if (maxAccompanyingCtLevel >= 10) return 6.0;
      return 4.0;
    }

    return 0.0;
  }

  /// Practice opponent base experience formula:
  /// - Base exp = floor(exp(L1) / 100 + exp(L2) / 300)
  /// - When total > 500: floor(500 + sqrt(total - 500))
  /// - Minimum exp for valid non-empty opponent is 10.
  /// - Returns 0 for 0-ship/empty opponent (L1 <= 0).
  static int calculatePracticeBaseExp(int l1, int l2) {
    if (l1 <= 0) return 0;
    final exp1 = shipCumulativeExp(l1);
    final exp2 = l2 > 0 ? shipCumulativeExp(l2) : 0;
    final total = (exp1 / 100.0) + (exp2 / 300.0);
    if (total <= 0) return 10;
    if (total > 500) {
      return (500.0 + math.sqrt(total - 500.0)).floor();
    }
    return total.floor();
  }
}
