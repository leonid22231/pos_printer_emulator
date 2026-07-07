import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/paper_width.dart';

const _paperWidthKey = 'paper_width';

class PaperWidthNotifier extends Notifier<PaperWidth> {
  @override
  PaperWidth build() {
    Future.microtask(_loadPersisted);
    return PaperWidth.mm80;
  }

  Future<void> _loadPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    state = PaperWidth.fromCode(prefs.getString(_paperWidthKey));
  }

  Future<void> setPaperWidth(PaperWidth width) async {
    state = width;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_paperWidthKey, width.code);
  }
}

final paperWidthProvider =
    NotifierProvider<PaperWidthNotifier, PaperWidth>(PaperWidthNotifier.new);
