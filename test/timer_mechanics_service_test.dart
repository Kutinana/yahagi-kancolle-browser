import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/fleet/global_game_timer.dart';
import 'package:yahagi_kancolle_browser/src/fleet/nosaki_sparkle_calculator.dart';
import 'package:yahagi_kancolle_browser/src/fleet/timer_mechanics_service.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';

import 'anchorage_repair_calculator_test.dart' show buildAnchorageTestState;
import 'nosaki_sparkle_calculator_test.dart' show buildNosakiTestState;

void main() {
  CapturedApiEvent event(
    String path,
    DateTime at, {
    Map<String, Object?> requestParams = const <String, Object?>{},
  }) {
    return CapturedApiEvent(
      path: path,
      statusCode: 200,
      responseBody: 'svdata={"api_result":1}',
      requestParams: requestParams,
      capturedAt: at,
      source: CaptureSource.manual,
    );
  }

  group('Nozaki Global Timer Tests (N01 - N15)', () {
    // N01: 账号级计时基准常驻
    test('N01: Nozaki global timer runs even if no fleet contains Nozaki', () {
      final service = TimerMechanicsService();
      final portTime = DateTime.utc(2026, 8, 20, 10, 0);
      final emptyState = GameState.empty;

      service.observe(
        previousState: emptyState,
        nextState: emptyState,
        event: event('/kcsapi/api_port/port', portTime),
      );

      expect(service.nozakiTimer.anchorAt, portTime);
      expect(service.nozakiTimer.isRunning, isTrue);
    });

    // N02: 未满15分钟回港
    test('N02: Port refresh before 15 minutes does not reset Nozaki timer', () {
      final service = TimerMechanicsService();
      final startTime = DateTime.utc(2026, 8, 20, 10, 0);
      service.nozakiTimer.reset(startTime);

      final portTime = startTime.add(const Duration(minutes: 8));
      final state = buildNosakiTestState(flagshipMasterId: 602);

      service.observe(
        previousState: state,
        nextState: state,
        event: event('/kcsapi/api_port/port', portTime),
      );

      expect(service.nozakiTimer.anchorAt, startTime);
      expect(service.nozakiTimer.elapsed(portTime), const Duration(minutes: 8));
    });

    // N03: 满15分钟无野埼则刷新开启新一轮
    test('N03: Port refresh at or after 15 minutes with no Nozaki resets timer to start fresh cycle', () {
      final service = TimerMechanicsService();
      final startTime = DateTime.utc(2026, 8, 20, 10, 0);
      service.nozakiTimer.reset(startTime);

      final portTime = startTime.add(const Duration(minutes: 16));
      final noNosakiState = buildNosakiTestState(flagshipMasterId: 501);

      service.observe(
        previousState: noNosakiState,
        nextState: noNosakiState,
        event: event('/kcsapi/api_port/port', portTime),
      );

      expect(service.nozakiTimer.anchorAt, portTime);
      expect(service.nozakiTimer.elapsed(portTime), Duration.zero);
    });

    // N04: 普通野埼疲劳失败 (blockedOnlyByFatigue)
    test('N04: Base Nozaki fails only due to target fatigue retains READY without resetting', () {
      final service = TimerMechanicsService();
      final startTime = DateTime.utc(2026, 8, 20, 10, 0);
      service.nozakiTimer.reset(startTime);

      final portTime = startTime.add(const Duration(minutes: 16));
      // Base Nozaki (596) requires companion Cond >= 49. Companions with Cond = 40 will fail.
      final fatigueBlockedState = buildNosakiTestState(
        flagshipMasterId: 596,
        companionConds: const [40, 40, 40, 40, 40],
      );

      service.observe(
        previousState: fatigueBlockedState,
        nextState: fatigueBlockedState,
        event: event('/kcsapi/api_port/port', portTime),
      );

      // Anchor remains at 10:00! Timer stays READY!
      expect(service.nozakiTimer.anchorAt, startTime);
      expect(service.nozakiTimer.elapsed(portTime), const Duration(minutes: 16));
    });

    // N05: 野埼改疲劳恢复
    test('N05: Nozaki Kai sparkle success resets timer to start next cycle', () {
      final service = TimerMechanicsService();
      final startTime = DateTime.utc(2026, 8, 20, 10, 0);
      service.nozakiTimer.reset(startTime);

      final portTime = startTime.add(const Duration(minutes: 16));
      final successState = buildNosakiTestState(
        flagshipMasterId: 602,
        companionConds: const [0, 10, 20, 30, 40],
      );

      service.observe(
        previousState: successState,
        nextState: successState,
        event: event('/kcsapi/api_port/port', portTime),
      );

      // Effect applied, timer resets to portTime (10:16)
      expect(service.nozakiTimer.anchorAt, portTime);
    });

    // N06: 油弹失败
    test('N06: Unsupplied Nozaki at refresh node fails and resets timer', () {
      final service = TimerMechanicsService();
      final startTime = DateTime.utc(2026, 8, 20, 10, 0);
      service.nozakiTimer.reset(startTime);

      final portTime = startTime.add(const Duration(minutes: 16));
      final unsuppliedState = buildNosakiTestState(
        flagshipMasterId: 602,
        nosakiFuel: 70, // Not full
      );

      service.observe(
        previousState: unsuppliedState,
        nextState: unsuppliedState,
        event: event('/kcsapi/api_port/port', portTime),
      );

      expect(service.nozakiTimer.anchorAt, portTime);
    });

    // N07: 损伤失败
    test('N07: Damaged Nozaki at refresh node fails and resets timer', () {
      final service = TimerMechanicsService();
      final startTime = DateTime.utc(2026, 8, 20, 10, 0);
      service.nozakiTimer.reset(startTime);

      final portTime = startTime.add(const Duration(minutes: 16));
      final damagedState = buildNosakiTestState(
        flagshipMasterId: 602,
        nosakiHp: 20, // Damaged (max 42)
      );

      service.observe(
        previousState: damagedState,
        nextState: damagedState,
        event: event('/kcsapi/api_port/port', portTime),
      );

      expect(service.nozakiTimer.anchorAt, portTime);
    });

    // N08: 疲劳失败 30 分钟不累计
    test('N08: Fatigue-blocked state past 30 minutes still yields single boost (+3) on next success', () {
      final service = TimerMechanicsService();
      final startTime = DateTime.utc(2026, 8, 20, 10, 0);
      service.nozakiTimer.reset(startTime);

      // At 15 min: all ships already cond 54 (blocked by fatigue)
      final fullCondState = buildNosakiTestState(
        flagshipMasterId: 602,
        companionConds: const [54, 54, 54, 54, 54],
      );
      final portAt15 = startTime.add(const Duration(minutes: 15));
      service.observe(
        previousState: fullCondState,
        nextState: fullCondState,
        event: event('/kcsapi/api_port/port', portAt15),
      );
      expect(service.nozakiTimer.anchorAt, startTime);

      // At 30 min: ships now have cond 40
      final readyState = buildNosakiTestState(
        flagshipMasterId: 602,
        companionConds: const [40, 40, 40, 40, 40],
      );
      final projection = NosakiSparkleCalculator.project(
        state: readyState,
        fleetId: 1,
        elapsed: const Duration(minutes: 30),
      );

      // Single +3 boost per cycle, not +6
      expect(projection.boostAmount, 3);
      expect(projection.rows[1].gainCond, 3);
    });

    // N09: 普通编成修改其他船
    test('N09: Manual hensei swap on companions with Nozaki in slot 1 resets timer', () {
      final service = TimerMechanicsService();
      final startTime = DateTime.utc(2026, 8, 20, 10, 0);
      final changeTime = DateTime.utc(2026, 8, 20, 10, 5);
      service.nozakiTimer.reset(startTime);

      final stateBefore = buildNosakiTestState(flagshipMasterId: 602);
      final stateAfter = stateBefore.copyWith(
        fleets: const <Fleet>[
          Fleet(
            id: 1,
            name: '第一舰队',
            shipIds: <int>[1, 2, 4, 3, 5, 6], // swapped 3 and 4
            slotCount: 6,
          ),
        ],
      );

      service.observe(
        previousState: stateBefore,
        nextState: stateAfter,
        event: event(
          '/kcsapi/api_req_hensei/change',
          changeTime,
          requestParams: const <String, Object?>{
            'api_id': '1',
            'api_ship_idx': '2',
            'api_ship_id': '4',
          },
        ),
      );

      expect(service.nozakiTimer.anchorAt, changeTime);
    });

    // N10: 把野埼移出工作位 (保时间技巧，不重置)
    test('N10: Moving Nozaki from slot 1 to slot 3 leaves 1/2 without Nozaki and does NOT reset timer', () {
      final service = TimerMechanicsService();
      final startTime = DateTime.utc(2026, 8, 20, 10, 0);
      final changeTime = DateTime.utc(2026, 8, 20, 10, 5);
      service.nozakiTimer.reset(startTime);

      final stateBefore = buildNosakiTestState(flagshipMasterId: 602);
      final stateAfter = stateBefore.copyWith(
        fleets: const <Fleet>[
          Fleet(
            id: 1,
            name: '第一舰队',
            shipIds: <int>[3, 2, 1, 4, 5, 6], // Nozaki (1) moved to index 2 (slot 3)
            slotCount: 6,
          ),
        ],
      );

      service.observe(
        previousState: stateBefore,
        nextState: stateAfter,
        event: event(
          '/kcsapi/api_req_hensei/change',
          changeTime,
          requestParams: const <String, Object?>{
            'api_id': '1',
            'api_ship_idx': '0',
            'api_ship_id': '3',
          },
        ),
      );

      // Preserves timestamp!
      expect(service.nozakiTimer.anchorAt, startTime);
    });

    // N11: 把 3 号野埼移到 2 号
    test('N11: Moving Nozaki from slot 3 to slot 2 puts Nozaki into work position and resets timer', () {
      final service = TimerMechanicsService();
      final startTime = DateTime.utc(2026, 8, 20, 10, 0);
      final changeTime = DateTime.utc(2026, 8, 20, 10, 5);
      service.nozakiTimer.reset(startTime);

      final stateBefore = buildNosakiTestState(
        flagshipMasterId: 501,
        thirdMasterId: 602,
      );
      final stateAfter = stateBefore.copyWith(
        fleets: const <Fleet>[
          Fleet(
            id: 1,
            name: '第一舰队',
            shipIds: <int>[1, 3, 2, 4, 5, 6], // Nozaki (3) moved to index 1 (slot 2)
            slotCount: 6,
          ),
        ],
      );

      service.observe(
        previousState: stateBefore,
        nextState: stateAfter,
        event: event(
          '/kcsapi/api_req_hensei/change',
          changeTime,
          requestParams: const <String, Object?>{
            'api_id': '1',
            'api_ship_idx': '1',
            'api_ship_id': '3',
          },
        ),
      );

      expect(service.nozakiTimer.anchorAt, changeTime);
    });

    // N12: Preset 出现野埼
    test('N12: Preset select resulting in Nozaki in slot 2 does NOT reset Nozaki timer', () {
      final service = TimerMechanicsService();
      final startTime = DateTime.utc(2026, 8, 20, 10, 0);
      final presetTime = DateTime.utc(2026, 8, 20, 10, 12);
      service.nozakiTimer.reset(startTime);

      final baseState = buildNosakiTestState(flagshipMasterId: 501);
      final presetState = buildNosakiTestState(flagshipMasterId: 602);

      service.observe(
        previousState: baseState,
        nextState: presetState,
        event: event('/kcsapi/api_req_hensei/preset_select', presetTime),
      );

      expect(service.nozakiTimer.anchorAt, startTime);
      expect(service.nozakiTimer.elapsed(presetTime), const Duration(minutes: 12));
    });

    // N13: 一括解除
    test('N13: Batch unequip does NOT reset Nozaki timer', () {
      final service = TimerMechanicsService();
      final startTime = DateTime.utc(2026, 8, 20, 10, 0);
      final batchTime = DateTime.utc(2026, 8, 20, 10, 6);
      service.nozakiTimer.reset(startTime);

      final state = buildNosakiTestState(flagshipMasterId: 602);

      service.observe(
        previousState: state,
        nextState: state,
        event: event(
          '/kcsapi/api_req_hensei/change',
          batchTime,
          requestParams: const <String, Object?>{
            'api_id': '1',
            'api_ship_idx': '-1',
            'api_ship_id': '-2',
          },
        ),
      );

      expect(service.nozakiTimer.anchorAt, startTime);
    });

    // N14: 双野埼共享
    test('N14: Multiple fleets with Nozaki share a single global NozakiTimer', () {
      final service = TimerMechanicsService();
      final startTime = DateTime.utc(2026, 8, 20, 10, 0);

      final baseState = buildNosakiTestState(flagshipMasterId: 602);
      final twoFleetsState = baseState.copyWith(
        fleets: <Fleet>[
          baseState.fleets.first,
          const Fleet(
            id: 2,
            name: '第二舰队',
            shipIds: <int>[101, 102],
            slotCount: 6,
          ),
        ],
        ships: <int, OwnedShip>{
          ...baseState.ships,
          101: const OwnedShip(id: 101, masterId: 602, level: 80, currentHp: 48, maxHp: 48, currentFuel: 100, currentAmmo: 100, condition: 49),
          102: const OwnedShip(id: 102, masterId: 1, level: 50, currentHp: 30, maxHp: 30, currentFuel: 100, currentAmmo: 100, condition: 40),
        },
      );

      service.nozakiTimer.reset(startTime);

      final changeFleet2Time = startTime.add(const Duration(minutes: 10));
      final modifiedFleet2State = twoFleetsState.copyWith(
        fleets: <Fleet>[
          twoFleetsState.fleets[0],
          const Fleet(id: 2, name: '第二舰队', shipIds: <int>[101], slotCount: 6),
        ],
      );

      service.observe(
        previousState: twoFleetsState,
        nextState: modifiedFleet2State,
        event: event(
          '/kcsapi/api_req_hensei/change',
          changeFleet2Time,
          requestParams: const <String, Object?>{
            'api_id': '2',
            'api_ship_idx': '1',
            'api_ship_id': '-1',
          },
        ),
      );

      expect(service.nozakiTimer.anchorAt, changeFleet2Time);
      expect(service.nozakiTimer.elapsed(changeFleet2Time), Duration.zero);
    });

    // N15: 野埼与明石隔离
    test('N15: Resetting Nozaki timer never alters Akashi timer anchor', () {
      final service = TimerMechanicsService();
      final akashiAnchor = DateTime.utc(2026, 8, 20, 10, 0);
      final nozakiAnchor = DateTime.utc(2026, 8, 20, 10, 5);

      service.akashiTimer.reset(akashiAnchor);
      service.nozakiTimer.reset(nozakiAnchor);

      final resetTime = DateTime.utc(2026, 8, 20, 10, 15);
      service.nozakiTimer.reset(resetTime);

      expect(service.akashiTimer.anchorAt, akashiAnchor);
      expect(service.nozakiTimer.anchorAt, resetTime);
    });
  });

  group('Akashi Global Timer Tests (A01 - A11)', () {
    // A01: 明石旗舰开始/重置
    test('A01: Manual change with Akashi flagship sets/resets AkashiTimer', () {
      final service = TimerMechanicsService();
      final changeTime = DateTime.utc(2026, 8, 20, 10, 0);

      final baseState = buildAnchorageTestState(facilities: 3);
      service.observe(
        previousState: GameState.empty,
        nextState: baseState,
        event: event(
          '/kcsapi/api_req_hensei/change',
          changeTime,
          requestParams: const <String, Object?>{
            'api_id': '1',
            'api_ship_idx': '0',
            'api_ship_id': '187',
          },
        ),
      );

      expect(service.akashiTimer.anchorAt, changeTime);
    });

    // A02: 明石旗舰换随伴
    test('A02: Swapping companions in an Akashi-flagship fleet resets AkashiTimer', () {
      final service = TimerMechanicsService();
      final startTime = DateTime.utc(2026, 8, 20, 10, 0);
      final changeTime = DateTime.utc(2026, 8, 20, 10, 5);
      service.akashiTimer.reset(startTime);

      final stateBefore = buildAnchorageTestState(facilities: 3);
      final stateAfter = stateBefore.copyWith(
        fleets: const <Fleet>[
          Fleet(
            id: 1,
            name: '第一舰队',
            shipIds: <int>[1, 3, 2, 4, 5], // swapped 2 and 3
            slotCount: 6,
          ),
        ],
      );

      service.observe(
        previousState: stateBefore,
        nextState: stateAfter,
        event: event(
          '/kcsapi/api_req_hensei/change',
          changeTime,
          requestParams: const <String, Object?>{
            'api_id': '1',
            'api_ship_idx': '1',
            'api_ship_id': '3',
          },
        ),
      );

      expect(service.akashiTimer.anchorAt, changeTime);
    });

    // A03: 把明石移出旗舰 (不重置，保留时间戳)
    test('A03: Moving Akashi out of flagship does NOT reset AkashiTimer by that rule', () {
      final service = TimerMechanicsService();
      final startTime = DateTime.utc(2026, 8, 20, 10, 0);
      final changeTime = DateTime.utc(2026, 8, 20, 10, 5);
      service.akashiTimer.reset(startTime);

      final stateBefore = buildAnchorageTestState(facilities: 3);
      final stateAfter = stateBefore.copyWith(
        fleets: const <Fleet>[
          Fleet(
            id: 1,
            name: '第一舰队',
            shipIds: <int>[2, 1, 3, 4, 5], // Akashi (1) moved to index 1
            slotCount: 6,
          ),
        ],
      );

      service.observe(
        previousState: stateBefore,
        nextState: stateAfter,
        event: event(
          '/kcsapi/api_req_hensei/change',
          changeTime,
          requestParams: const <String, Object?>{
            'api_id': '1',
            'api_ship_idx': '0',
            'api_ship_id': '2',
          },
        ),
      );

      // Preserves timestamp!
      expect(service.akashiTimer.anchorAt, startTime);
    });

    // A04: 再放回旗舰
    test('A04: Putting Akashi back as flagship resets AkashiTimer', () {
      final service = TimerMechanicsService();
      final startTime = DateTime.utc(2026, 8, 20, 10, 0);
      final changeTime = DateTime.utc(2026, 8, 20, 10, 8);
      service.akashiTimer.reset(startTime);

      final stateBefore = buildAnchorageTestState(
        facilities: 3,
        flagshipMasterId: 501,
      );
      final stateAfter = buildAnchorageTestState(
        facilities: 3,
        flagshipMasterId: 187,
      );

      service.observe(
        previousState: stateBefore,
        nextState: stateAfter,
        event: event(
          '/kcsapi/api_req_hensei/change',
          changeTime,
          requestParams: const <String, Object?>{
            'api_id': '1',
            'api_ship_idx': '0',
            'api_ship_id': '1',
          },
        ),
      );

      expect(service.akashiTimer.anchorAt, changeTime);
    });

    // A05: Preset 展开明石
    test('A05: Expanding Akashi fleet via preset does NOT reset AkashiTimer', () {
      final service = TimerMechanicsService();
      final startTime = DateTime.utc(2026, 8, 20, 10, 0);
      final presetTime = DateTime.utc(2026, 8, 20, 10, 15);
      service.akashiTimer.reset(startTime);

      final combatState = buildAnchorageTestState(
        facilities: 3,
        flagshipMasterId: 501,
      );
      final akashiState = buildAnchorageTestState(
        facilities: 3,
        flagshipMasterId: 187,
      );

      service.observe(
        previousState: combatState,
        nextState: akashiState,
        event: event('/kcsapi/api_req_hensei/preset_select', presetTime),
      );

      expect(service.akashiTimer.anchorAt, startTime);
      expect(service.akashiTimer.elapsed(presetTime), const Duration(minutes: 15));
    });

    // A06: 20分钟以内母港
    test('A06: Port refresh before 20 minutes does not reset AkashiTimer', () {
      final service = TimerMechanicsService();
      final startTime = DateTime.utc(2026, 8, 20, 10, 0);
      service.akashiTimer.reset(startTime);

      final portTime = startTime.add(const Duration(minutes: 12));
      final state = buildAnchorageTestState(facilities: 3);

      service.observe(
        previousState: state,
        nextState: state,
        event: event('/kcsapi/api_port/port', portTime),
      );

      expect(service.akashiTimer.anchorAt, startTime);
      expect(service.akashiTimer.elapsed(portTime), const Duration(minutes: 12));
    });

    // A07: 20分钟以后母港
    test('A07: Port refresh at or after 20 minutes evaluates repair and restarts timer', () {
      final service = TimerMechanicsService();
      final startTime = DateTime.utc(2026, 8, 20, 10, 0);
      service.akashiTimer.reset(startTime);

      final portTime = startTime.add(const Duration(minutes: 25));
      final state = buildAnchorageTestState(facilities: 3);

      service.observe(
        previousState: state,
        nextState: state,
        event: event('/kcsapi/api_port/port', portTime),
      );

      expect(service.akashiTimer.anchorAt, portTime);
      expect(service.akashiTimer.elapsed(portTime), Duration.zero);
    });

    // A08: 改装备
    test('A08: Changing repair facility equipment does NOT reset AkashiTimer', () {
      final service = TimerMechanicsService();
      final startTime = DateTime.utc(2026, 8, 20, 10, 0);
      final slotsetTime = DateTime.utc(2026, 8, 20, 10, 10);
      service.akashiTimer.reset(startTime);

      final state = buildAnchorageTestState(facilities: 3);

      service.observe(
        previousState: state,
        nextState: state,
        event: event(
          '/kcsapi/api_req_kaisou/slotset',
          slotsetTime,
          requestParams: const <String, Object?>{'api_id': '1'},
        ),
      );

      expect(service.akashiTimer.anchorAt, startTime);
    });

    // A09: 出击
    test('A09: Sortie start and battle events do NOT reset AkashiTimer', () {
      final service = TimerMechanicsService();
      final startTime = DateTime.utc(2026, 8, 20, 10, 0);
      final sortieTime = DateTime.utc(2026, 8, 20, 10, 10);
      service.akashiTimer.reset(startTime);

      final state = buildAnchorageTestState(facilities: 3);

      service.observe(
        previousState: state,
        nextState: state,
        event: event(
          '/kcsapi/api_req_map/start',
          sortieTime,
          requestParams: const <String, Object?>{'api_deck_id': '1'},
        ),
      );

      expect(service.akashiTimer.anchorAt, startTime);
      expect(service.akashiTimer.elapsed(sortieTime), const Duration(minutes: 10));
    });

    // A10: 跨舰队抽随伴
    test('A10: Pulling companion from Fleet 1 (Akashi) into Fleet 2 modifies Fleet 1 and resets AkashiTimer', () {
      final service = TimerMechanicsService();
      final startTime = DateTime.utc(2026, 8, 20, 10, 0);
      final changeTime = DateTime.utc(2026, 8, 20, 10, 7);
      service.akashiTimer.reset(startTime);

      final baseState = buildAnchorageTestState(facilities: 3);
      final stateBefore = baseState.copyWith(
        fleets: <Fleet>[
          baseState.fleets.first,
          const Fleet(id: 2, name: '第二舰队', shipIds: <int>[101], slotCount: 6),
        ],
        ships: <int, OwnedShip>{
          ...baseState.ships,
          101: const OwnedShip(id: 101, masterId: 2, level: 50),
        },
      );

      // Ship 2 is pulled from Fleet 1 into Fleet 2
      final stateAfter = stateBefore.copyWith(
        fleets: <Fleet>[
          const Fleet(id: 1, name: '第一舰队', shipIds: <int>[1, 3, 4, 5], slotCount: 6),
          const Fleet(id: 2, name: '第二舰队', shipIds: <int>[101, 2], slotCount: 6),
        ],
      );

      service.observe(
        previousState: stateBefore,
        nextState: stateAfter,
        event: event(
          '/kcsapi/api_req_hensei/change',
          changeTime,
          requestParams: const <String, Object?>{
            'api_id': '2',
            'api_ship_idx': '1',
            'api_ship_id': '2',
          },
        ),
      );

      // Because Fleet 1 was actually changed and its flagship is still Akashi, timer resets!
      expect(service.akashiTimer.anchorAt, changeTime);
    });

    // A11: 两支明石舰队共享
    test('A11: Two fleets with Akashi share the single global AkashiTimer', () {
      final service = TimerMechanicsService();
      final startTime = DateTime.utc(2026, 8, 20, 10, 0);
      service.akashiTimer.reset(startTime);

      final baseState = buildAnchorageTestState(facilities: 3);
      final twoFleetsState = baseState.copyWith(
        fleets: <Fleet>[
          baseState.fleets.first,
          const Fleet(id: 2, name: '第二舰队', shipIds: <int>[201, 202], slotCount: 6),
        ],
        ships: <int, OwnedShip>{
          ...baseState.ships,
          201: const OwnedShip(id: 201, masterId: 187, level: 80, currentHp: 45, maxHp: 45, condition: 49),
          202: const OwnedShip(id: 202, masterId: 1, level: 50, currentHp: 20, maxHp: 30, condition: 49),
        },
      );

      final changeFleet2Time = startTime.add(const Duration(minutes: 12));
      final modifiedFleet2State = twoFleetsState.copyWith(
        fleets: <Fleet>[
          twoFleetsState.fleets[0],
          const Fleet(id: 2, name: '第二舰队', shipIds: <int>[201], slotCount: 6),
        ],
      );

      service.observe(
        previousState: twoFleetsState,
        nextState: modifiedFleet2State,
        event: event(
          '/kcsapi/api_req_hensei/change',
          changeFleet2Time,
          requestParams: const <String, Object?>{
            'api_id': '2',
            'api_ship_idx': '1',
            'api_ship_id': '-1',
          },
        ),
      );

      expect(service.akashiTimer.anchorAt, changeFleet2Time);
    });
  });

  group('Combined Akashi + Nozaki Tests (C01 - C04)', () {
    // C01: 同舰队明石+野埼
    test('C01: Akashi slot 1 and Nozaki slot 2 in same fleet co-exist independently', () {
      final service = TimerMechanicsService();
      final startTime = DateTime.utc(2026, 8, 20, 10, 0);

      service.akashiTimer.reset(startTime);
      service.nozakiTimer.reset(startTime);

      expect(service.akashiTimer.anchorAt, startTime);
      expect(service.nozakiTimer.anchorAt, startTime);
    });

    // C02: 15分钟节点
    test('C02: At 15-minute port refresh, Nozaki sparkles & restarts while Akashi continues', () {
      final service = TimerMechanicsService();
      final t1000 = DateTime.utc(2026, 8, 20, 10, 0);
      service.akashiTimer.reset(t1000);
      service.nozakiTimer.reset(t1000);

      final combinedFleet = GameState(
        fleets: const <Fleet>[
          Fleet(id: 1, name: '第一舰队', shipIds: <int>[1, 2, 3], slotCount: 6),
        ],
        ships: const <int, OwnedShip>{
          1: OwnedShip(id: 1, masterId: 187, level: 80, currentHp: 45, maxHp: 45, condition: 49, slotIds: <int>[1001, 1002]),
          2: OwnedShip(id: 2, masterId: 602, level: 80, currentHp: 48, maxHp: 48, currentFuel: 100, currentAmmo: 100, condition: 49),
          3: OwnedShip(id: 3, masterId: 1, level: 50, currentHp: 20, maxHp: 30, condition: 40),
        },
        slotItems: const <int, OwnedSlotItem>{
          1001: OwnedSlotItem(id: 1001, masterId: 86),
          1002: OwnedSlotItem(id: 1002, masterId: 86),
        },
        masterShips: const <int, MasterShip>{
          187: MasterShip(id: 187, name: '明石改', shipTypeId: 19),
          602: MasterShip(id: 602, name: '野埼改', shipTypeId: 19, maxFuel: 100, maxAmmo: 100),
          1: MasterShip(id: 1, name: '吹雪', shipTypeId: 2),
        },
      );

      final t1015 = t1000.add(const Duration(minutes: 15));
      service.observe(
        previousState: combinedFleet,
        nextState: combinedFleet,
        event: event('/kcsapi/api_port/port', t1015),
      );

      // Nozaki sparked and reset to 10:15
      expect(service.nozakiTimer.anchorAt, t1015);
      // Akashi elapsed 15m < 20m, still at 10:00
      expect(service.akashiTimer.anchorAt, t1000);
    });

    // C03: 20分钟节点
    test('C03: At 20-minute port refresh, Akashi repairs & restarts while Nozaki continues', () {
      final service = TimerMechanicsService();
      final t1000 = DateTime.utc(2026, 8, 20, 10, 0);
      final t1015 = DateTime.utc(2026, 8, 20, 10, 15);
      service.akashiTimer.reset(t1000);
      service.nozakiTimer.reset(t1015);

      final combinedFleet = GameState(
        fleets: const <Fleet>[
          Fleet(id: 1, name: '第一舰队', shipIds: <int>[1, 2, 3], slotCount: 6),
        ],
        ships: const <int, OwnedShip>{
          1: OwnedShip(id: 1, masterId: 187, level: 80, currentHp: 45, maxHp: 45, condition: 49, slotIds: <int>[1001, 1002]),
          2: OwnedShip(id: 2, masterId: 602, level: 80, currentHp: 48, maxHp: 48, currentFuel: 100, currentAmmo: 100, condition: 49),
          3: OwnedShip(id: 3, masterId: 1, level: 50, currentHp: 20, maxHp: 30, condition: 40),
        },
        slotItems: const <int, OwnedSlotItem>{
          1001: OwnedSlotItem(id: 1001, masterId: 86),
          1002: OwnedSlotItem(id: 1002, masterId: 86),
        },
        masterShips: const <int, MasterShip>{
          187: MasterShip(id: 187, name: '明石改', shipTypeId: 19),
          602: MasterShip(id: 602, name: '野埼改', shipTypeId: 19, maxFuel: 100, maxAmmo: 100),
          1: MasterShip(id: 1, name: '吹雪', shipTypeId: 2),
        },
      );

      final t1020 = t1000.add(const Duration(minutes: 20));
      service.observe(
        previousState: combinedFleet,
        nextState: combinedFleet,
        event: event('/kcsapi/api_port/port', t1020),
      );

      // Akashi elapsed 20m >= 20m, reset to 10:20
      expect(service.akashiTimer.anchorAt, t1020);
      // Nozaki elapsed 5m < 15m, remains at 10:15
      expect(service.nozakiTimer.anchorAt, t1015);
    });

    // C04: 同一普通编成同时命中两边
    test('C04: Single manual change on Akashi+Nozaki fleet triggers resets for both timers', () {
      final service = TimerMechanicsService();
      final startTime = DateTime.utc(2026, 8, 20, 10, 0);
      final changeTime = DateTime.utc(2026, 8, 20, 10, 10);
      service.akashiTimer.reset(startTime);
      service.nozakiTimer.reset(startTime);

      final stateBefore = GameState(
        fleets: const <Fleet>[
          Fleet(id: 1, name: '第一舰队', shipIds: <int>[1, 2, 3, 4], slotCount: 6),
        ],
        ships: const <int, OwnedShip>{
          1: OwnedShip(id: 1, masterId: 187, level: 80, currentHp: 45, maxHp: 45),
          2: OwnedShip(id: 2, masterId: 602, level: 80, currentHp: 48, maxHp: 48, currentFuel: 100, currentAmmo: 100),
          3: OwnedShip(id: 3, masterId: 1, level: 50),
          4: OwnedShip(id: 4, masterId: 2, level: 50),
        },
        masterShips: const <int, MasterShip>{
          187: MasterShip(id: 187, name: '明石改', shipTypeId: 19),
          602: MasterShip(id: 602, name: '野埼改', shipTypeId: 19),
          1: MasterShip(id: 1, name: '吹雪', shipTypeId: 2),
          2: MasterShip(id: 2, name: '白雪', shipTypeId: 2),
        },
      );

      final stateAfter = stateBefore.copyWith(
        fleets: const <Fleet>[
          Fleet(id: 1, name: '第一舰队', shipIds: <int>[1, 2, 4, 3], slotCount: 6), // 3 and 4 swapped
        ],
      );

      service.observe(
        previousState: stateBefore,
        nextState: stateAfter,
        event: event(
          '/kcsapi/api_req_hensei/change',
          changeTime,
          requestParams: const <String, Object?>{
            'api_id': '1',
            'api_ship_idx': '2',
            'api_ship_id': '4',
          },
        ),
      );

      expect(service.akashiTimer.anchorAt, changeTime);
      expect(service.nozakiTimer.anchorAt, changeTime);
    });
  });
}
