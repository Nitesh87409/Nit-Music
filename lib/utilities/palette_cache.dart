import 'package:flutter/material.dart';

class PaletteCache {
  static String? _lastId;
  static Color? dominantColor;
  static Color? vibrantColor;

  static void update(String id, Color? dominant, Color? vibrant) {
    _lastId = id;
    dominantColor = dominant;
    vibrantColor = vibrant;
  }

  static bool hasColorsFor(String id) {
    return _lastId == id;
  }
}
