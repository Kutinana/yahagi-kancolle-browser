import 'package:flutter/material.dart';

mixin SettingsUIHelpers {
  Widget buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xffd4a85f),
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget buildCard({required Widget child}) {
    return Material(
      color: const Color(0xff142735),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: ListTileTheme(
        data: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 16),
          minLeadingWidth: 0,
        ),
        child: child,
      ),
    );
  }

  Widget buildActionTile({
    Key? key,
    required String title,
    Key? titleKey,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    bool enabled = true,
  }) {
    return InkWell(
      key: key,
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title,
                    key: titleKey,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: enabled ? null : const Color(0xff526776),
                    ),
                  ),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: enabled
                            ? const Color(0xff8197a5)
                            : const Color(0xff526776),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...<Widget>[
              const SizedBox(width: 12),
              trailing,
            ],
          ],
        ),
      ),
    );
  }

  Widget buildSwitchTile({
    required String title,
    Key? titleKey,
    Key? switchKey,
    String? subtitle,
    Widget? trailingBeforeSwitch,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  key: titleKey,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Color(0xff8197a5)),
                  ),
                ],
              ],
            ),
          ),
          if (trailingBeforeSwitch != null) ...<Widget>[
            const SizedBox(width: 12),
            trailingBeforeSwitch,
          ],
          const SizedBox(width: 12),
          Switch(
            key: switchKey,
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xffd4a85f),
          ),
        ],
      ),
    );
  }

  Widget buildSliderTile({
    required String title,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${(value * 100).toInt()}%',
                style: TextStyle(
                  color: onChanged == null
                      ? const Color(0xff526776)
                      : const Color(0xffd4a85f),
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            activeColor: const Color(0xffd4a85f),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
