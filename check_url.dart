import 'dart:io';

void main() async {
  final resource = <int>[
    6657, 5699, 3371, 8909, 7719, 6229, 5449, 8561, 2987, 5501, 3127, 9319,
    4365, 9811, 9927, 2423, 3439, 1865, 5925, 4409, 5509, 1517, 9695, 9255,
    5325, 3691, 5519, 6949, 5607, 9539, 4133, 7795, 5465, 2659, 6381, 6875,
    4019, 9195, 5645, 2887, 1213, 1815, 8671, 3015, 3147, 2991, 7977, 7045,
    1619, 7909, 4451, 6573, 4545, 8251, 5983, 2849, 7249, 7449, 9477, 5963,
    2711, 9019, 7375, 2201, 5631, 4893, 7653, 3719, 8819, 5839, 1853, 9843,
    9119, 7023, 5681, 2345, 9873, 6349, 9315, 3795, 9737, 4633, 4173, 7549,
    7171, 6147, 4723, 5039, 2723, 7815, 6201, 5999, 5339, 4431, 2911, 4435,
    3611, 4423, 9517, 3243,
  ];

  String createCipher(int id, String seed) {
    var key = 0;
    for (final codeUnit in seed.codeUnits) {
      key += codeUnit;
    }
    final index = (key + id * seed.length) % resource.length;
    return (((17 * (id + 7) * resource[index]) % 8973) + 1000).toString();
  }

  int id = 277;
  String paddedId = id.toString().padLeft(4, '0');

  String urlNormal = 'http://203.104.209.71/kcs2/resources/ship/remodel/${paddedId}_${createCipher(id, 'ship_remodel')}.png';
  String urlDmg = 'http://203.104.209.71/kcs2/resources/ship/remodel/${paddedId}_${createCipher(id, 'ship_remodel_dmg')}.png';
  
  String urlBannerNormal = 'http://203.104.209.71/kcs2/resources/ship/banner/${paddedId}_${createCipher(id, 'ship_banner')}.png';
  String urlBannerDmg = 'http://203.104.209.71/kcs2/resources/ship/banner/${paddedId}_${createCipher(id, 'ship_banner_dmg')}.png';

  Future<void> checkUrl(String type, String url) async {
    try {
      var request = await HttpClient().headUrl(Uri.parse(url));
      request.headers.set('User-Agent', 'Mozilla/5.0');
      request.headers.set('Referer', 'http://203.104.209.71/');
      var response = await request.close();
      print('$type: ${response.statusCode}');
    } catch (e) {
      print('$type: Error $e');
    }
  }

  await checkUrl('Remodel Normal', urlNormal);
  await checkUrl('Remodel Dmg', urlDmg);
  await checkUrl('Banner Normal', urlBannerNormal);
  await checkUrl('Banner Dmg', urlBannerDmg);
}
