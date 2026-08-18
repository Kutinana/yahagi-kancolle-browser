import 'package:flutter/material.dart';

class HeaderFilterIconButton extends StatelessWidget {
  const HeaderFilterIconButton({
    super.key,
    required this.icon,
    required this.active,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final bool active;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 34,
    height: 34,
    child: IconButton(
      padding: EdgeInsets.zero,
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: active
            ? const Color(0xff8a6628)
            : const Color(0xff0b202d),
        side: const BorderSide(color: Color(0xff315064)),
      ),
      icon: Icon(
        icon,
        size: 18,
        color: active ? const Color(0xffffdc88) : const Color(0xff9fb3bf),
      ),
    ),
  );
}

class CompactFilterChip extends StatelessWidget {
  const CompactFilterChip({
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
    padding: const EdgeInsets.only(right: 5, bottom: 3),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: selected ? const Color(0xff287e6a) : const Color(0xffd3dae0),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xff24333c),
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ),
  );
}
