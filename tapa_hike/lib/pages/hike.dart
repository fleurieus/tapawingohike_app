import 'package:flutter/material.dart';

import 'package:tapa_hike/widgets/loading.dart';

class HikePage extends StatefulWidget {
  const HikePage({ super.key });

  @override
  State<HikePage> createState() => _HikePageState();
}

class _HikePageState extends State<HikePage> {
  
  @override
  Widget build(BuildContext context) {
    return LoadingWidget();
  }
}
