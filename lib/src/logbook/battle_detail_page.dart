import 'package:flutter/material.dart';

import '../battle/battle_detail_models.dart';

enum _AttackFilter { all, friend, enemy }

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
  int _tab = 0;
  _AttackFilter _filter = _AttackFilter.all;
  final Set<String> _collapsedStages = <String>{};

  @override
  Widget build(BuildContext context) => ColoredBox(
    key: const Key('battle-detail-page'),
    color: const Color(0xff081521),
    child: SafeArea(
      top: false,
      child: Column(
        children: <Widget>[
          _DetailHeader(detail: widget.detail, onBack: widget.onBack),
          _DetailTabs(
            selected: _tab,
            onSelected: (value) => setState(() => _tab = value),
          ),
          Expanded(
            child: _tab == 0
                ? _FleetOverview(detail: widget.detail)
                : _BattleProcess(
                    detail: widget.detail,
                    filter: _filter,
                    collapsedStages: _collapsedStages,
                    onFilterChanged: (value) => setState(() => _filter = value),
                    onStageToggle: (key) => setState(() {
                      if (!_collapsedStages.remove(key)) {
                        _collapsedStages.add(key);
                      }
                    }),
                  ),
          ),
        ],
      ),
    ),
  );
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.detail, required this.onBack});

  final BattleDetailSnapshot detail;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final time = DateTime.fromMillisecondsSinceEpoch(detail.completedAtMillis);
    final timestamp =
        '${time.year.toString().padLeft(4, '0')}/'
        '${time.month.toString().padLeft(2, '0')}/'
        '${time.day.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.fromLTRB(8, 7, 12, 7),
      decoration: const BoxDecoration(
        color: Color(0xff0b202d),
        border: Border(bottom: BorderSide(color: Color(0xff294354))),
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            key: const Key('battle-detail-back'),
            tooltip: '返回出击记录',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            color: const Color(0xffd5e3e9),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '战斗详情 · ${detail.mapLabel} ${detail.nodeLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xffedf5f7),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    timestamp,
                    if (detail.enemyFleetName.isNotEmpty) detail.enemyFleetName,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xff8ea6b3),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            constraints: const BoxConstraints(minWidth: 38, minHeight: 34),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xff3d3017),
              border: Border.all(color: const Color(0xff9f7930)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              detail.rank,
              style: const TextStyle(
                color: Color(0xffffd977),
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailTabs extends StatelessWidget {
  const _DetailTabs({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    height: 48,
    alignment: Alignment.centerLeft,
    padding: const EdgeInsets.fromLTRB(12, 7, 12, 5),
    child: Container(
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xff0b202d),
        border: Border.all(color: const Color(0xff315064)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _TabButton(
            key: const Key('battle-detail-tab-fleet'),
            label: '舰队',
            selected: selected == 0,
            onTap: () => onSelected(0),
          ),
          _TabButton(
            key: const Key('battle-detail-tab-process'),
            label: '战斗过程',
            selected: selected == 1,
            onTap: () => onSelected(1),
          ),
        ],
      ),
    ),
  );
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 126,
    height: 30,
    child: Material(
      color: selected ? const Color(0xff8a6628) : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? const Color(0xffffdc88)
                  : const Color(0xff9fb3bf),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    ),
  );
}

class _FleetOverview extends StatelessWidget {
  const _FleetOverview({required this.detail});

  final BattleDetailSnapshot detail;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 840;
      final friendSections = <Widget>[
        _FleetSection(
          title: '第一舰队 · 主力',
          fleet: detail.fleet(
            BattleDetailSide.friend,
            BattleDetailFleetRole.main,
          ),
        ),
        const SizedBox(height: 10),
        _FleetSection(
          title: '第二舰队 · 随伴',
          fleet: detail.fleet(
            BattleDetailSide.friend,
            BattleDetailFleetRole.escort,
          ),
        ),
      ];
      final enemySections = <Widget>[
        _FleetSection(
          title: '敌方主力',
          fleet: detail.fleet(
            BattleDetailSide.enemy,
            BattleDetailFleetRole.main,
          ),
        ),
        const SizedBox(height: 10),
        _FleetSection(
          title: '敌方随伴',
          fleet: detail.fleet(
            BattleDetailSide.enemy,
            BattleDetailFleetRole.escort,
          ),
        ),
      ];
      return Scrollbar(
        child: SingleChildScrollView(
          key: const Key('battle-detail-fleet-scroll'),
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(child: Column(children: friendSections)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(children: enemySections)),
                  ],
                )
              : Column(
                  children: <Widget>[
                    ...friendSections,
                    const SizedBox(height: 10),
                    ...enemySections,
                  ],
                ),
        ),
      );
    },
  );
}

class _FleetSection extends StatelessWidget {
  const _FleetSection({required this.title, required this.fleet});

  final String title;
  final BattleDetailFleet? fleet;

  @override
  Widget build(BuildContext context) {
    final enemy = fleet?.side == BattleDetailSide.enemy;
    final accent = enemy ? const Color(0xffd16b68) : const Color(0xff5fb5db);
    final ships = fleet?.ships ?? const <BattleDetailShip>[];
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xff0b202d),
        border: Border.all(color: const Color(0xff294556)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xff112b39),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(9),
              ),
              border: Border(left: BorderSide(color: accent, width: 3)),
            ),
            child: Text(
              title,
              style: TextStyle(
                color: enemy
                    ? const Color(0xffffaaa3)
                    : const Color(0xff91d8f3),
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (ships.isEmpty)
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                '无随伴舰队',
                style: TextStyle(color: Color(0xff718895), fontSize: 12),
              ),
            )
          else
            for (var index = 0; index < ships.length; index++) ...<Widget>[
              _ShipRow(ship: ships[index]),
              if (index != ships.length - 1)
                const Divider(height: 1, color: Color(0xff243d4c)),
            ],
        ],
      ),
    );
  }
}

class _ShipRow extends StatelessWidget {
  const _ShipRow({required this.ship});

  final BattleDetailShip ship;

  @override
  Widget build(BuildContext context) {
    final hpRatio = ship.maxHp <= 0
        ? 0.0
        : (ship.finalHp / ship.maxHp).clamp(0.0, 1.0);
    final hpColor = hpRatio <= .25
        ? const Color(0xffe35c5c)
        : hpRatio <= .5
        ? const Color(0xffe3a84f)
        : const Color(0xff4dbb8b);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xff183747),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${ship.position + 1}',
                  style: const TextStyle(
                    color: Color(0xff9fc2d2),
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${ship.name}${ship.level == null ? '' : '  Lv.${ship.level}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xffe4edf1),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${ship.finalHp} / ${ship.maxHp}',
                style: TextStyle(
                  color: hpColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: hpRatio,
              minHeight: 5,
              color: hpColor,
              backgroundColor: const Color(0xff20333e),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: <Widget>[
              _Metric(
                label: 'HP',
                value: '${ship.initialHp} → ${ship.finalHp}',
              ),
              _Metric(label: '造成', value: '${ship.damageDealt}'),
              _Metric(label: '承受', value: '${ship.damageReceived}'),
              if (ship.escaped) const _Metric(label: '状态', value: '退避'),
            ],
          ),
          if (ship.equipment.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: <Widget>[
                for (final item in ship.equipment) _EquipmentChip(item: item),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: <InlineSpan>[
        TextSpan(
          text: '$label ',
          style: const TextStyle(color: Color(0xff718b98)),
        ),
        TextSpan(
          text: value,
          style: const TextStyle(
            color: Color(0xffbdcbd2),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
    style: const TextStyle(fontSize: 10.5),
  );
}

class _EquipmentChip extends StatelessWidget {
  const _EquipmentChip({required this.item});

  final BattleDetailEquipment item;

  @override
  Widget build(BuildContext context) {
    final suffix = <String>[
      if (item.improvement > 0) '★${item.improvement}',
      if (item.proficiency > 0) '熟练 ${item.proficiency}',
    ].join(' ');
    return Container(
      constraints: const BoxConstraints(maxWidth: 210),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xff132f3d),
        border: Border.all(color: const Color(0xff315264)),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        suffix.isEmpty ? item.name : '${item.name}  $suffix',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Color(0xff9fb8c4), fontSize: 10),
      ),
    );
  }
}

class _BattleProcess extends StatelessWidget {
  const _BattleProcess({
    required this.detail,
    required this.filter,
    required this.collapsedStages,
    required this.onFilterChanged,
    required this.onStageToggle,
  });

  final BattleDetailSnapshot detail;
  final _AttackFilter filter;
  final Set<String> collapsedStages;
  final ValueChanged<_AttackFilter> onFilterChanged;
  final ValueChanged<String> onStageToggle;

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
          children: <Widget>[
            _FilterButton(
              key: const Key('battle-detail-filter-all'),
              label: '全部',
              selected: filter == _AttackFilter.all,
              onTap: () => onFilterChanged(_AttackFilter.all),
            ),
            _FilterButton(
              key: const Key('battle-detail-filter-friend'),
              label: '我方攻击',
              selected: filter == _AttackFilter.friend,
              onTap: () => onFilterChanged(_AttackFilter.friend),
            ),
            _FilterButton(
              key: const Key('battle-detail-filter-enemy'),
              label: '敌方攻击',
              selected: filter == _AttackFilter.enemy,
              onTap: () => onFilterChanged(_AttackFilter.enemy),
            ),
          ],
        ),
      ),
      Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 840;
            final stages =
                <({BattleDetailStage stage, List<BattleDetailAttack> attacks})>[
                      for (final stage in detail.stages)
                        (
                          stage: stage,
                          attacks: stage.attacks
                              .where((attack) {
                                return switch (filter) {
                                  _AttackFilter.all => true,
                                  _AttackFilter.friend =>
                                    attack.attackerSide ==
                                        BattleDetailSide.friend,
                                  _AttackFilter.enemy =>
                                    attack.attackerSide ==
                                        BattleDetailSide.enemy,
                                };
                              })
                              .toList(growable: false),
                        ),
                    ]
                    .where((entry) => entry.attacks.isNotEmpty)
                    .toList(growable: false);
            if (stages.isEmpty) {
              return const Center(
                child: Text(
                  '此筛选条件下没有攻击记录',
                  style: TextStyle(color: Color(0xff7f95a1), fontSize: 12),
                ),
              );
            }
            return ListView.separated(
              key: const Key('battle-detail-process-scroll'),
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
              itemCount: stages.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final entry = stages[index];
                final collapsed = collapsedStages.contains(entry.stage.keyName);
                return _StageSection(
                  stage: entry.stage,
                  attacks: entry.attacks,
                  collapsed: collapsed,
                  wide: wide,
                  onToggle: () => onStageToggle(entry.stage.keyName),
                );
              },
            );
          },
        ),
      ),
    ],
  );
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 7),
    child: Material(
      color: selected ? const Color(0xff1d5367) : const Color(0xff0d2431),
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          constraints: const BoxConstraints(minWidth: 72),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? const Color(0xff4b98b5)
                  : const Color(0xff2b4656),
            ),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? const Color(0xffb9eafb)
                  : const Color(0xff91a6b1),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    ),
  );
}

class _StageSection extends StatelessWidget {
  const _StageSection({
    required this.stage,
    required this.attacks,
    required this.collapsed,
    required this.wide,
    required this.onToggle,
  });

  final BattleDetailStage stage;
  final List<BattleDetailAttack> attacks;
  final bool collapsed;
  final bool wide;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xff0b202d),
      border: Border.all(color: const Color(0xff294556)),
      borderRadius: BorderRadius.circular(10),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: <Widget>[
        Material(
          color: const Color(0xff13303e),
          child: InkWell(
            onTap: onToggle,
            child: SizedBox(
              height: 40,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 11),
                child: Row(
                  children: <Widget>[
                    Icon(
                      collapsed
                          ? Icons.chevron_right_rounded
                          : Icons.expand_more_rounded,
                      size: 20,
                      color: const Color(0xffffc95d),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        stage.title,
                        style: const TextStyle(
                          color: Color(0xffffce70),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      '${attacks.length} 次',
                      style: const TextStyle(
                        color: Color(0xff819ba8),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (!collapsed)
          for (var index = 0; index < attacks.length; index++) ...<Widget>[
            if (wide)
              _WideAttackRow(attack: attacks[index])
            else
              _NarrowAttackCard(attack: attacks[index]),
            if (index != attacks.length - 1)
              const Divider(height: 1, color: Color(0xff223b49)),
          ],
      ],
    ),
  );
}

class _WideAttackRow extends StatelessWidget {
  const _WideAttackRow({required this.attack});

  final BattleDetailAttack attack;

  @override
  Widget build(BuildContext context) {
    final friendlyAttack = attack.attackerSide == BattleDetailSide.friend;
    final friendName = friendlyAttack
        ? attack.attackerName
        : attack.defenderName;
    final enemyName = friendlyAttack
        ? attack.defenderName
        : attack.attackerName;
    final friendHp = friendlyAttack
        ? ''
        : '${attack.defenderHpAfter} / ${attack.defenderHpBefore.clamp(attack.defenderHpAfter, 1 << 30)}';
    final enemyHp = friendlyAttack
        ? '${attack.defenderHpAfter} / ${attack.defenderHpBefore.clamp(attack.defenderHpAfter, 1 << 30)}'
        : '';
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 70),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        child: Row(
          children: <Widget>[
            Expanded(flex: 12, child: _HpText(friendHp, friendly: true)),
            const SizedBox(width: 6),
            Expanded(flex: 17, child: _ShipName(friendName, friendly: true)),
            SizedBox(
              width: 34,
              child: friendlyAttack
                  ? const SizedBox.shrink()
                  : const Icon(
                      Icons.arrow_back_rounded,
                      color: Color(0xffe77972),
                      size: 22,
                    ),
            ),
            Expanded(flex: 28, child: _AttackCenter(attack: attack)),
            SizedBox(
              width: 34,
              child: friendlyAttack
                  ? const Icon(
                      Icons.arrow_forward_rounded,
                      color: Color(0xff68c6e9),
                      size: 22,
                    )
                  : const SizedBox.shrink(),
            ),
            Expanded(flex: 17, child: _ShipName(enemyName, friendly: false)),
            const SizedBox(width: 6),
            Expanded(flex: 12, child: _HpText(enemyHp, friendly: false)),
          ],
        ),
      ),
    );
  }
}

class _NarrowAttackCard extends StatelessWidget {
  const _NarrowAttackCard({required this.attack});

  final BattleDetailAttack attack;

  @override
  Widget build(BuildContext context) {
    final friendly = attack.attackerSide == BattleDetailSide.friend;
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  attack.attackerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: friendly
                        ? const Color(0xff8edbf5)
                        : const Color(0xffffaaa3),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: friendly
                    ? const Color(0xff68c6e9)
                    : const Color(0xffe77972),
                size: 21,
              ),
              Expanded(
                child: Text(
                  attack.defenderName,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: friendly
                        ? const Color(0xffffaaa3)
                        : const Color(0xff8edbf5),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: _AttackCenter(attack: attack, alignStart: true)),
              const SizedBox(width: 8),
              Text(
                '${attack.defenderHpBefore} → ${attack.defenderHpAfter} HP',
                style: const TextStyle(
                  color: Color(0xffb8c8cf),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttackCenter extends StatelessWidget {
  const _AttackCenter({required this.attack, this.alignStart = false});

  final BattleDetailAttack attack;
  final bool alignStart;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: alignStart
        ? CrossAxisAlignment.start
        : CrossAxisAlignment.center,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Text(
        attack.attackType,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: alignStart ? TextAlign.start : TextAlign.center,
        style: const TextStyle(
          color: Color(0xffd4e0e5),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 5),
      Wrap(
        alignment: alignStart ? WrapAlignment.start : WrapAlignment.center,
        spacing: 4,
        runSpacing: 4,
        children: <Widget>[
          for (final hit in attack.hits) _HitChip(hit: hit),
          if (attack.damageControlName != null)
            _StatusChip(label: attack.damageControlName!),
        ],
      ),
    ],
  );
}

class _HitChip extends StatelessWidget {
  const _HitChip({required this.hit});

  final BattleDetailHit hit;

  @override
  Widget build(BuildContext context) {
    final color = switch (hit.kind) {
      BattleDetailHitKind.miss => const Color(0xff708590),
      BattleDetailHitKind.hit => const Color(0xffd5b45f),
      BattleDetailHitKind.critical => const Color(0xffff746d),
    };
    return Tooltip(
      message: switch (hit.kind) {
        BattleDetailHitKind.miss => '未命中',
        BattleDetailHitKind.hit => '命中 · 段后 HP ${hit.hpAfter}',
        BattleDetailHitKind.critical => '暴击 · 段后 HP ${hit.hpAfter}',
      },
      child: Container(
        constraints: const BoxConstraints(minWidth: 28, minHeight: 22),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .13),
          border: Border.all(color: color.withValues(alpha: .7)),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          hit.kind == BattleDetailHitKind.miss ? 'MISS' : '${hit.damage}',
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0xff2a4d37),
      border: Border.all(color: const Color(0xff58a574)),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Color(0xff9ee1b5),
        fontSize: 9.5,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _ShipName extends StatelessWidget {
  const _ShipName(this.name, {required this.friendly});

  final String name;
  final bool friendly;

  @override
  Widget build(BuildContext context) => Text(
    name,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    textAlign: friendly ? TextAlign.right : TextAlign.left,
    style: TextStyle(
      color: friendly ? const Color(0xff8edbf5) : const Color(0xffffaaa3),
      fontSize: 11,
      fontWeight: FontWeight.w800,
    ),
  );
}

class _HpText extends StatelessWidget {
  const _HpText(this.value, {required this.friendly});

  final String value;
  final bool friendly;

  @override
  Widget build(BuildContext context) => Text(
    value,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    textAlign: friendly ? TextAlign.right : TextAlign.left,
    style: const TextStyle(
      color: Color(0xffb8c8cf),
      fontSize: 10.5,
      fontWeight: FontWeight.w800,
    ),
  );
}
