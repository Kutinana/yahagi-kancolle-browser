import 'package:flutter/material.dart';

List<String> slotItemIconAssetCandidates(int iconId) => <String>[
  'assets/images/slotitem/$iconId.png',
  if (iconId >= 0) 'assets/images/slotitem/${iconId + 100}.png',
  'assets/images/slotitem/-1.png',
];

class EquipmentTypeIconImage extends StatelessWidget {
  const EquipmentTypeIconImage({
    super.key,
    required this.iconId,
    required this.width,
    required this.height,
    this.imageKey,
    this.filterQuality = FilterQuality.medium,
  });

  final int iconId;
  final double width;
  final double height;
  final Key? imageKey;
  final FilterQuality filterQuality;

  @override
  Widget build(BuildContext context) {
    return _candidateImage(slotItemIconAssetCandidates(iconId), 0);
  }

  Widget _candidateImage(List<String> candidates, int index) {
    return Image.asset(
      candidates[index],
      key: index == 0 ? imageKey : null,
      width: width,
      height: height,
      filterQuality: filterQuality,
      errorBuilder: index + 1 < candidates.length
          ? (context, error, stackTrace) =>
                _candidateImage(candidates, index + 1)
          : null,
    );
  }
}
