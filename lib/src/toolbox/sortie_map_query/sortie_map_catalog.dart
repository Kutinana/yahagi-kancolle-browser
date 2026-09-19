import 'package:flutter/services.dart';

import 'sortie_map_models.dart';

class SortieMapCatalog {
  const SortieMapCatalog._();

  static const assetPath = 'assets/data/sortie_map_catalog.json';

  static Future<SortieMapCatalogData> loadAsset() async {
    final source = await rootBundle.loadString(assetPath);
    return SortieMapCatalogData.fromJsonString(source);
  }
}
