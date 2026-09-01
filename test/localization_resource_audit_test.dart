import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _readArb(String name) {
  return jsonDecode(File('lib/l10n/$name').readAsStringSync())
      as Map<String, Object?>;
}

Set<String> _messageKeys(Map<String, Object?> arb) =>
    arb.keys.where((key) => !key.startsWith('@')).toSet();

Map<String, Object?> _metadataFor(Map<String, Object?> arb, String key) {
  return (arb['@$key'] as Map<String, Object?>?) ?? const {};
}

Set<String> _placeholderNames(Map<String, Object?> metadata) {
  final placeholders = metadata['placeholders'];
  return placeholders is Map<String, Object?> ? placeholders.keys.toSet() : {};
}

void main() {
  final resources = <String, Map<String, Object?>>{
    'zh': _readArb('app_zh.arb'),
    'zh_Hant': _readArb('app_zh_Hant.arb'),
    'ja': _readArb('app_ja.arb'),
  };

  test(
    'all locales have identical message, metadata and placeholder schemas',
    () {
      final template = resources['zh']!;
      final expectedKeys = _messageKeys(template);

      for (final entry in resources.entries) {
        expect(_messageKeys(entry.value), expectedKeys, reason: entry.key);
        for (final key in expectedKeys) {
          final expectedMetadata = _metadataFor(template, key);
          final actualMetadata = _metadataFor(entry.value, key);
          expect(
            actualMetadata.keys.toSet(),
            expectedMetadata.keys.toSet(),
            reason: '${entry.key}: @$key metadata',
          );
          expect(
            _placeholderNames(actualMetadata),
            _placeholderNames(expectedMetadata),
            reason: '${entry.key}: $key placeholders',
          );
        }
      }
    },
  );

  test('all locales include enemy preview portrait settings', () {
    const keys = <String>{
      'battleEnemyPreviewPortraits',
      'battleEnemyPreviewPortraitsDesc',
    };

    for (final entry in resources.entries) {
      expect(_messageKeys(entry.value), containsAll(keys), reason: entry.key);
    }
  });

  test('all locales include the four frame-rate modes and warning', () {
    const keys = <String>{
      'gameFrameRateStable60',
      'gameFrameRateStable60Desc',
      'gameFrameRateStable30',
      'gameFrameRateStable30Desc',
      'gameFrameRateHighRefresh',
      'gameFrameRateHighRefreshDesc',
      'gameFrameRateHighRefreshDialogTitle',
      'gameFrameRateHighRefreshDialogBody',
      'gameFrameRateHighRefreshDialogConfirm',
    };

    for (final entry in resources.entries) {
      expect(_messageKeys(entry.value), containsAll(keys), reason: entry.key);
    }
  });

  test('identical translations are limited to reviewed terminology', () {
    // Each entry is intentionally shared: product/game terminology, numerals,
    // protocol names, or a language self-name. Adding a key requires review.
    const reviewedZhHant = <String>{
      'appTitle',
      'repair',
      'construction',
      'httpProxy',
      'socks5Proxy',
      'hostHint',
      // These repair mode names and the active-repair status use the same
      // established game terminology in Simplified and Traditional Chinese.
      'repairDockMode',
      'anchorageRepairMode',
      'repairing',
      'forecast',
      'detailed',
      'accepted',
      'completed',
      'questDaily',
      'questWeekly',
      'questMonthly',
      'questOther',
      'questUnknown',
      // 大破提醒 is standard game terminology in both Chinese scripts.
      'gameSafety',
      'latestVersionLabel',
      'cancel',
      'speed',
      'firepower',
      'airPower',
      'fuel',
      'hp',
      'fastSpeed',
      'slowSpeed',
      'gotIt',
      'notRepairing',
      'cost',
      'notConstructing',
      'lsc',
      'constructing',
      'constructComplete',
      'resourceTrend7d',
      'resourceTrend30d',
      'langZh',
      'langZhHant',
      'langJa',
      'friend',
      'drop',
      'fleetStandby',
      'highSpeed',
      'lowSpeed',
      'airStateLabel',
      // 均衡 is the established air-state term in both Chinese scripts.
      'airSuperiorityParity',
      'back',
      'dropLabel',
      'item',
      // These short status terms use the same standard Han spelling in both
      // Simplified and Traditional Chinese.
      'statusUnknown',
      'statusSuccess',
      // The established formula name is written identically in both locales.
      'formula33',
      // 改修 is the in-game term in both Chinese scripts; 受限 is unchanged.
      'improvement',
      'gadgetBypassRestricted',
      // 官方ID is the same developer-facing label in both Chinese scripts.
      'equipmentOfficialId',
      // These compact scope labels intentionally use the same wording in
      // Simplified and Traditional Chinese.
      'equipmentCompatibilityOwnedCompact',
      'equipmentCompatibilityAllCompact',
      // Short game/UI terms conventionally share the same Han spelling.
      'highSpeedPlus',
      'all',
      'clear',
      'done',
      'questSeasonal',
      'questYearly',
      'notCompleted',
      // “分享” is the standard action label in both Chinese scripts.
      'diagnosticShareAction',
      // HTTP and its numeric status placeholder are protocol terminology.
      'kcwikiReportFailureHttp',
      // “高刷”是简中和繁中统一采用的帧率档位产品名称。
      'gameFrameRateHighRefresh',
      // “升序/降序” are standard sorting terms in both Chinese scripts.
      'sortAscending',
      'sortDescending',
      'sortieCheckMapsMode',
      'mapHpGauges',
      'allMapsCleared',
      'gameRenderingModeCompatibility',
      'settingsTabNotification',
      'notificationSound',
      'notificationPercent',
      'notificationPreempt30s',
      'notificationPreempt60s',
      'notificationAnchorage',
      'notificationRepair',
      'notificationConstruction',
      // Collection-state and exclusion actions use the same established
      // wording in both Chinese scripts.
      'inventoryOwned',
      'inventoryUnowned',
      'unownedShipExcludedLabel',
      'clearNewShipExclusions',
      'otherType',
      'acknowledge',
      // “上次” is standard wording shared by both Chinese scripts.
      'battleLastFormation',
      // “全部” is the compact all-surfaces scope label in both Chinese scripts.
      'battleEffectScopeAll',
      // “最小/最大” are standard range labels shared by both Chinese scripts.
      'minimumValue',
      'maximumValue',
      // 基地航空队的海域、航程及状态均为游戏内固定术语。
      'landBaseAreaFallback',
      'landBaseRange',
      'landBaseActionAirDefense',
      'landBaseActionRest',
      'landBaseActionRetreat',
      // These concise Senka table labels and the formatted update prefix use
      // established game terminology shared by both Chinese scripts.
      'senkaActions',
      'senkaArea',
      'senkaBoss',
      'senkaDailyRequired',
      'senkaFavoriteArea',
      'senkaMonth',
      'senkaRank',
      'senkaResult',
      'senkaRewardCompleted',
      'senkaToday',
      'senkaUpdated',
      // Product names and the toolbox's generic labels intentionally keep
      // the same established spelling in both Chinese scripts.
      'toolbox',
      'otherTools',
      'noro6',
      'jervis',
      'deckBuilderV4',
      // “回填配方” is the concise action used in both Chinese scripts.
      'developmentApplyRecipe',
      // 「其他」 is the concise fallback secretary group in both scripts.
      'developmentOtherSecretaryGroup',
    };
    const reviewedJa = <String>{
      'appTitle',
      'construction',
      'settingsTabNotification',
      'notificationAnchorage',
      'notificationRepair',
      'notificationConstruction',
      // 入渠 and 泊地 are the established Japanese in-game repair mode names.
      'repairDockMode',
      'anchorageRepairMode',
      'sortieCheckMapsMode',
      'firepower',
      'torpedo',
      'airPower',
      'fuel',
      'fastSpeed',
      'slowSpeed',
      'constructing',
      'langZh',
      'langZhHant',
      'langJa',
      'highSpeed',
      'lowSpeed',
      'airStateLabel',
      // 「成功」 is the established Japanese status label as well.
      'statusSuccess',
      // 「33式」 is the in-game formula name in Japanese as well.
      'formula33',
      // 改修 is an established UI term shared with Japanese.
      'improvement',
      // These established game terms use the same spelling in Japanese.
      'armor',
      'evasion',
      'highSpeedPlus',
      'questRemodeling',
      // HTTP and its numeric status placeholder are protocol terminology.
      'kcwikiReportFailureHttp',
      // 「最小/最大」 are the standard Japanese range labels as well.
      'minimumValue',
      'maximumValue',
      // These are established in-game land-base terms shared with Chinese.
      'landBaseAreaFallback',
      'landBaseActionAirDefense',
      'landBaseActionRest',
      'landBaseActionRetreat',
      // These concise Senka labels are established game terminology shared
      // with Japanese; punctuation and placeholders are intentionally equal.
      'senkaActions',
      'senkaArea',
      'senkaBoss',
      'senkaResult',
      'senkaToday',
      'senkaUpdated',
      // Third-party product and interchange-format names are untranslated.
      'noro6',
      'jervis',
      'deckBuilderV4',
    };

    Set<String> identical(String locale) {
      final zh = resources['zh']!;
      final other = resources[locale]!;
      return _messageKeys(zh).where((key) => zh[key] == other[key]).toSet();
    }

    expect(identical('zh_Hant'), reviewedZhHant);
    expect(identical('ja'), reviewedJa);
  });
}
