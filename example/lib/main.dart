import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:implicitly_animated_reorderable_list/implicitly_animated_reorderable_list.dart';

import 'ui/lang_page.dart';
import 'ui/ui.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
      ),
    );


    return MaterialApp(
      title: 'Implicitly Animated Reorderable List Example',
      theme: ThemeData.light().copyWith(
        accentColor: Colors.amber.shade800,
        dividerTheme: DividerThemeData(
          thickness: 1,
          color: Colors.grey.shade300,
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: LanguagePage(),
    );
  }
}
