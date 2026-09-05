import 'package:flutter/material.dart';
import '../battle/battle_detail_models.dart';

// Shared by the logbook and the isolated UI preview. No sample data is loaded here.
// LogbookPage owns insets for both this view and the adjacent record list.
const ink = Color(0xff081521);
const panel = Color(0xff0b202d);
const border = Color(0xff294556);
const muted = Color(0xff92aab7);
const friend = Color(0xff91d8f3);
const enemy = Color(0xffffaaa3);
const gold = Color(0xffffd977);
const healthy = Color(0xff4dbb8b);

Text label(
  String value, {
  Color color = const Color(0xffe4edf1),
  double size = 13,
  bool bold = false,
}) => Text(
  value,
  style: TextStyle(
    color: color,
    fontSize: size,
    fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
  ),
);

class BattleDetailPage extends StatefulWidget {
  const BattleDetailPage({
    super.key,
    required this.detail,
    required this.onBack,
  });
  final BattleDetailSnapshot detail;
  final VoidCallback onBack;
  @override
  State<BattleDetailPage> createState() => _BattleDetailPageState();
}

class _BattleDetailPageState extends State<BattleDetailPage> {
  int tab = 0;
  int filter = 0;
  final Set<String> closed = {};

  @override
  void didUpdateWidget(covariant BattleDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.detail != widget.detail) {
      closed.clear();
      filter = 0;
    }
  }

  @override
  Widget build(BuildContext context) => Material(
    key: const Key('battle-detail-page'),
    color: ink,
    child: Column(
      children: [
        _header(),
        Expanded(child: tab == 0 ? _fleets() : _process()),
      ],
    ),
  );

  Widget _tabs() => Container(
    key: const Key('detail-tabs'),
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: ink,
      border: Border.all(color: border),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 2; i++)
          SizedBox(
            width: i == 0 ? 70 : 96,
            height: 40,
            child: TextButton(
              key: Key(
                i == 0
                    ? 'battle-detail-tab-fleet'
                    : 'battle-detail-tab-process',
              ),
              style: TextButton.styleFrom(
                foregroundColor: tab == i ? gold : muted,
                backgroundColor: tab == i
                    ? const Color(0xff806024)
                    : Colors.transparent,
                padding: EdgeInsets.zero,
                shape: const StadiumBorder(),
              ),
              onPressed: () => setState(() => tab = i),
              child: label(
                i == 0 ? '舰队' : '战斗过程',
                color: tab == i ? gold : muted,
                bold: true,
              ),
            ),
          ),
      ],
    ),
  );

  Widget _header() => LayoutBuilder(
    builder: (context, box) {
      final inline = box.maxWidth >= 640;
      final detail = widget.detail;
      return Container(
        padding: const EdgeInsets.fromLTRB(4, 5, 12, 5),
        decoration: const BoxDecoration(
          color: panel,
          border: Border(bottom: BorderSide(color: border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  key: const Key('battle-detail-back'),
                  tooltip: '返回出击记录',
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back_rounded, color: friend),
                ),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      label(
                        '战斗详情 · ${detail.mapLabel} ${detail.nodeLabel}',
                        size: 15,
                        bold: true,
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (detail.enemyFleetName.isNotEmpty) ...[
                            Flexible(
                              child: Tag(
                                detail.enemyFleetName,
                                color: enemy,
                                pill: true,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Tag(detail.rank, color: gold),
                        ],
                      ),
                    ],
                  ),
                ),
                if (inline) ...[const SizedBox(width: 8), _tabs()],
              ],
            ),
            if (!inline)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Align(alignment: Alignment.centerLeft, child: _tabs()),
              ),
          ],
        ),
      );
    },
  );

  Widget _fleets() => LayoutBuilder(
    builder: (context, box) {
      Widget side(BattleDetailSide side) {
        final fleets = widget.detail.fleets
            .where((f) => f.side == side && f.ships.isNotEmpty)
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final fleet in fleets)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _FleetCard(fleet: fleet),
              ),
          ],
        );
      }

      return SingleChildScrollView(
        key: const PageStorageKey('battle-detail-fleet-scroll'),
        padding: const EdgeInsets.all(12),
        child: box.maxWidth >= 700
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: side(BattleDetailSide.friend)),
                  const SizedBox(width: 12),
                  Expanded(child: side(BattleDetailSide.enemy)),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  side(BattleDetailSide.friend),
                  side(BattleDetailSide.enemy),
                ],
              ),
      );
    },
  );

  BattleDetailShip? _targetShip(BattleDetailAttack attack) {
    if (attack.defenderRole == null || attack.defenderPosition == null) {
      return null;
    }
    return widget.detail
        .fleet(attack.defenderSide, attack.defenderRole!)
        ?.ships
        .where((ship) => ship.position == attack.defenderPosition)
        .firstOrNull;
  }

  Widget _process() {
    var number = 0;
    final entries =
        <
          ({
            BattleDetailStage stage,
            List<({BattleDetailAttack attack, int number})> attacks,
          })
        >[];
    for (final stage in widget.detail.stages) {
      final attacks = <({BattleDetailAttack attack, int number})>[];
      for (final attack in stage.attacks) {
        number++;
        if (filter == 0 ||
            (filter == 1 && attack.attackerSide != BattleDetailSide.enemy) ||
            (filter == 2 && attack.attackerSide == BattleDetailSide.enemy)) {
          attacks.add((attack: attack, number: number));
        }
      }
      if (attacks.isNotEmpty) entries.add((stage: stage, attacks: attacks));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var i = 0; i < 3; i++)
                ChoiceChip(
                  key: Key(
                    [
                      'battle-detail-filter-all',
                      'battle-detail-filter-friend',
                      'battle-detail-filter-enemy',
                    ][i],
                  ),
                  showCheckmark: false,
                  label: Text(['全部', '我方攻击', '敌方攻击'][i]),
                  selected: filter == i,
                  onSelected: (_) => setState(() => filter = i),
                  labelStyle: TextStyle(
                    color: filter == i ? friend : muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  backgroundColor: panel,
                  selectedColor: const Color(0xff194356),
                  side: BorderSide(
                    color: filter == i ? friend.withValues(alpha: .5) : border,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              label('按发生顺序', color: muted, size: 11),
            ],
          ),
        ),
        Expanded(
          child: entries.isEmpty
              ? Center(child: label('没有符合条件的攻击记录', color: muted))
              : ListView.builder(
                  key: PageStorageKey('battle-detail-process-$filter'),
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final stage = entry.stage;
                    final isClosed = closed.contains(stage.keyName);
                    final npcStage = stage.attacks.any(
                      (a) => a.attackerSide == BattleDetailSide.npc,
                    );
                    final beneficiary = npcStage
                        ? BattleDetailSide.npc
                        : BattleDetailSide.friend;
                    final beneficiaryName = npcStage ? '友军' : '我方';
                    final dealt = stage.attacks
                        .where((a) => a.attackerSide != BattleDetailSide.enemy)
                        .fold(0, (sum, a) => sum + a.totalDamage);
                    final received = stage.attacks
                        .where((a) => a.defenderSide == beneficiary)
                        .fold(0, (sum, a) => sum + a.totalDamage);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: panel,
                        border: Border.all(color: border),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          InkWell(
                            key: Key('stage-${stage.keyName}'),
                            onTap: () => setState(() {
                              if (!closed.remove(stage.keyName)) {
                                closed.add(stage.keyName);
                              }
                            }),
                            child: Container(
                              color: const Color(0xff112b39),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 11,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isClosed
                                        ? Icons.chevron_right
                                        : Icons.expand_more,
                                    color: gold,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Wrap(
                                      spacing: 12,
                                      runSpacing: 4,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        label(
                                          stage.title,
                                          color: gold,
                                          bold: true,
                                        ),
                                        label(
                                          '$beneficiaryName造成 $dealt · $beneficiaryName承受 $received',
                                          color: muted,
                                          size: 11,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  label(
                                    '${entry.attacks.length} 条',
                                    color: muted,
                                    size: 11,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (!isClosed)
                            for (final row in entry.attacks)
                              _AttackReport(
                                key: Key('attack-${row.number}'),
                                attack: row.attack,
                                number: row.number,
                                target: _targetShip(row.attack),
                              ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class Tag extends StatelessWidget {
  const Tag(
    this.text, {
    super.key,
    this.color = muted,
    this.size = 11,
    this.pill = false,
  });
  final String text;
  final Color color;
  final double size;
  final bool pill;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .10),
      border: Border.all(color: color.withValues(alpha: .28)),
      borderRadius: BorderRadius.circular(pill ? 20 : 5),
    ),
    child: label(text, color: color, size: size, bold: true),
  );
}

String sideName(BattleDetailSide side) => switch (side) {
  BattleDetailSide.friend => '我方',
  BattleDetailSide.enemy => '敌方',
  BattleDetailSide.npc => '友军',
};

class _AttackReport extends StatelessWidget {
  const _AttackReport({
    super.key,
    required this.attack,
    required this.number,
    this.target,
  });
  final BattleDetailAttack attack;
  final int number;
  final BattleDetailShip? target;

  String? get targetStatus {
    if (target?.hpUnknown == true || attack.defenderHpAfter < 0) return null;
    final hp = attack.defenderHpAfter;
    final prefix = sideName(attack.defenderSide);
    if (hp == 0 &&
        attack.defenderHpBefore > 0 &&
        attack.damageControlName == null) {
      return '$prefix击沉';
    }
    final maxHp = target?.maxHp ?? 0;
    if (hp <= 0 || maxHp <= 0) return null;
    if (hp * 4 <= maxHp) return '$prefix大破';
    if (hp * 2 <= maxHp) return '$prefix中破';
    if (hp * 4 <= maxHp * 3) return '$prefix小破';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final a = attack;
    final accent = a.attackerSide != BattleDetailSide.enemy ? friend : enemy;
    final missed =
        a.hits.isNotEmpty &&
        a.hits.every((h) => h.kind == BattleDetailHitKind.miss);
    final critical = a.hits.any((h) => h.kind == BattleDetailHitKind.critical);
    final status = targetStatus;
    final statusColor = status?.endsWith('小破') == true
        ? gold
        : status?.endsWith('中破') == true
        ? const Color(0xffffb45e)
        : enemy;
    final hp = target?.hpUnknown == true
        ? '目标HP 未知（-${a.totalDamage}）'
        : '目标HP ${a.defenderHpBefore} → ${a.defenderHpAfter}（-${a.totalDamage}）';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1, color: border),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          child: LayoutBuilder(
            builder: (context, box) {
              final wide = box.maxWidth >= 660;
              final summary = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 7,
                    runSpacing: 5,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      label(
                        number.toString().padLeft(2, '0'),
                        color: muted,
                        size: 11,
                      ),
                      Tag('${sideName(a.attackerSide)}攻击', color: accent),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: a.attackerName,
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const TextSpan(
                          text: '  攻击  ',
                          style: TextStyle(color: muted),
                        ),
                        TextSpan(
                          text: a.defenderName,
                          style: TextStyle(
                            color: a.defenderSide == BattleDetailSide.enemy
                                ? enemy
                                : friend,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                ],
              );
              final ending = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Tag(
                        missed ? '未命中' : '造成 ${a.totalDamage} 伤害',
                        color: missed ? muted : gold,
                        size: 13,
                        pill: true,
                      ),
                      if (critical && !missed)
                        const Tag('暴击', color: enemy, pill: true),
                      if (status != null)
                        Tag(status, color: statusColor, pill: true),
                      if (a.damageControlName != null)
                        const Tag('损管发动', color: healthy, pill: true),
                    ],
                  ),
                  const SizedBox(height: 7),
                  label(hp, color: muted, size: 12),
                ],
              );
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 3,
                    height: wide ? 54 : 96,
                    color: accent.withValues(alpha: .65),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: wide
                        ? Row(
                            children: [
                              Expanded(flex: 6, child: summary),
                              const SizedBox(width: 20),
                              Expanded(flex: 4, child: ending),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              summary,
                              const SizedBox(height: 10),
                              ending,
                            ],
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FleetCard extends StatelessWidget {
  const _FleetCard({required this.fleet});
  final BattleDetailFleet fleet;
  @override
  Widget build(BuildContext context) {
    final own = fleet.side != BattleDetailSide.enemy;
    final escort = fleet.role == BattleDetailFleetRole.escort;
    final title = own
        ? (escort ? '第二舰队 · 随伴' : '第一舰队 · 主力')
        : (escort ? '敌方随伴' : '敌方主力');
    final accent = own ? friend : enemy;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: panel,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xff112b39),
              border: Border(left: BorderSide(color: accent, width: 3)),
            ),
            child: Row(
              children: [
                Expanded(child: label(title, color: accent, bold: true)),
                label('${fleet.ships.length} 艘', color: muted, size: 11),
              ],
            ),
          ),
          for (final ship in fleet.ships) _ShipCard(ship: ship),
        ],
      ),
    );
  }
}

class _ShipCard extends StatelessWidget {
  const _ShipCard({required this.ship});
  final BattleDetailShip ship;
  @override
  Widget build(BuildContext context) {
    final s = ship;
    final ratio = s.maxHp <= 0 ? 0.0 : (s.finalHp / s.maxHp).clamp(0.0, 1.0);
    final hpColor = s.hpUnknown
        ? muted
        : ratio <= .25
        ? enemy
        : ratio <= .5
        ? gold
        : healthy;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Tag((s.position + 1).toString(), color: friend),
              const SizedBox(width: 8),
              Expanded(
                child: label(
                  s.name + (s.level == null ? '' : '  Lv.${s.level}'),
                  size: 13,
                  bold: true,
                ),
              ),
              const SizedBox(width: 6),
              label(
                s.hpUnknown
                    ? '耐久未知（-${s.damageReceived}）'
                    : '${s.finalHp} / ${s.maxHp}（-${s.damageReceived}）',
                color: hpColor,
                size: 12,
                bold: true,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: s.hpUnknown ? 0 : ratio,
              minHeight: 5,
              color: hpColor,
              backgroundColor: const Color(0xff20333e),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              label(
                s.hpUnknown ? '耐久未知' : '耐久 ${s.initialHp} → ${s.finalHp}',
                color: muted,
                size: 11,
              ),
              label('造成 ${s.damageDealt}', color: muted, size: 11),
              label('承受 ${s.damageReceived}', color: muted, size: 11),
              if (s.escaped) const Tag('退避'),
            ],
          ),
        ],
      ),
    );
  }
}
