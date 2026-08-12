import 'package:flutter/material.dart';

class OfficialEnemyPreview extends StatelessWidget {
  const OfficialEnemyPreview({super.key, required this.names});

  final List<String> names;

  @override
  Widget build(BuildContext context) {
    final combined = names.length > 3;
    return Container(
      key: const Key('official-enemy-preview'),
      decoration: BoxDecoration(
        color: const Color(0xff10212e),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(9, 7, 9, 5),
            child: Text(
              '敌方部队（战前预测）',
              key: Key('official-enemy-preview-title'),
              style: TextStyle(
                color: Color(0xffff8c78),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (!combined)
            for (var index = 0; index < names.length; index++) ...<Widget>[
              if (index > 0) const Divider(height: 1, color: Color(0xff203746)),
              _nameCell(
                names[index],
                key: Key('official-enemy-preview-row-$index'),
              ),
            ]
          else
            for (var index = 0; index < 3; index++) ...<Widget>[
              if (index > 0) const Divider(height: 1, color: Color(0xff203746)),
              Row(
                key: Key('official-enemy-preview-row-$index'),
                children: <Widget>[
                  Expanded(
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        border: Border(
                          right: BorderSide(color: Color(0xff203746)),
                        ),
                      ),
                      child: _nameCell(
                        _nameAt(index),
                        key: Key('official-enemy-preview-escort-$index'),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _nameCell(
                      _nameAt(index + 3),
                      key: Key('official-enemy-preview-main-$index'),
                    ),
                  ),
                ],
              ),
            ],
        ],
      ),
    );
  }

  String _nameAt(int index) => index < names.length ? names[index] : '';

  Widget _nameCell(String name, {required Key key}) => Padding(
    key: key,
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    child: Tooltip(
      message: name,
      child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    ),
  );
}
