import 'dart:io';

import 'package:bitree/ui/course_palette.dart';

Map<String, CoursePalette> testPalettes() => {
  for (final id in CoursePalette.builtinIds)
    id: CoursePalette.parse(
      File('assets/palettes/$id.json').readAsStringSync(),
    ),
};

CoursePalette lightTestPalette() => CoursePalette.fromJson({
  'name': '自定义浅色',
  'brightness': 'light',
  'base': '#F8F8F8',
  'text': '#242424',
  'northTeaching': '#245390',
  'wencui': '#336633',
  'southScience': '#765200',
  'eastFacilities': '#614A7A',
  'southEngineering': '#884C24',
  'neutral': '#555555',
  'agenda': '#614A7A',
});
