import 'dart:typed_data';
import 'dart:ui' as ui;

/// Produces a disposable, front-facing 40 cm single-spot practice image with
/// six dark arrow holes for previewing the analysis and review flow.
class SimulatedTarget {
  static const _side = 512.0;
  static const _faceRadius = 246.0;

  // Deliberately spread across the colored bands so the demo exercises scoring.
  static const List<(double, double)> _arrows = [
    (0.03, -0.04), // 10
    (0.13, 0.00), // 9
    (-0.21, 0.15), // 8
    (0.30, 0.18), // 7
    (-0.42, 0.03), // 6
    (0.00, -0.52), // 5
  ];

  static Future<Uint8List> create() async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    const center = ui.Offset(_side / 2, _side / 2);
    canvas.drawColor(const ui.Color(0xFFF4F1E8), ui.BlendMode.src);

    for (var score = 1; score <= 10; score++) {
      final outer = _faceRadius * (1 - (score - 1) / 10);
      final inner = _faceRadius * (1 - score / 10);
      final path = ui.Path()
        ..fillType = ui.PathFillType.evenOdd
        ..addOval(ui.Rect.fromCircle(center: center, radius: outer));
      if (inner > 0) {
        path.addOval(ui.Rect.fromCircle(center: center, radius: inner));
      }
      canvas.drawPath(path, ui.Paint()..color = _ringColor(score));
      canvas.drawCircle(
        center,
        outer,
        ui.Paint()
          // Keep separators visible without making them look like dark arrow
          // holes to the prototype's connected-component detector.
          ..color = const ui.Color(0xFF7A7A7A)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 1.25,
      );
    }

    // Small dark punctures resemble holes in the paper and are large enough to
    // be detected reliably at this sample resolution.
    for (final (x, y) in _arrows) {
      final point = center + ui.Offset(x * _faceRadius, y * _faceRadius);
      canvas.drawCircle(
        point,
        5.2,
        ui.Paint()..color = const ui.Color(0xFF171717),
      );
      canvas.drawCircle(
        point,
        5.2,
        ui.Paint()
          ..color = const ui.Color(0xFFB7AAA0)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 0.7,
      );
    }

    final image = await recorder.endRecording().toImage(
      _side.toInt(),
      _side.toInt(),
    );
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) {
        throw StateError('Could not create the simulated target image.');
      }
      return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
    } finally {
      image.dispose();
    }
  }

  static const _white = ui.Color(0xFFF9F8F2);
  static const _black = ui.Color(0xFF181818);
  static const _blue = ui.Color(0xFF1974B9);
  static const _red = ui.Color(0xFFD73535);
  static const _yellow = ui.Color(0xFFFFD52A);

  static ui.Color _ringColor(int score) => switch (score) {
    1 || 2 => _white,
    3 || 4 => _black,
    5 || 6 => _blue,
    7 || 8 => _red,
    _ => _yellow,
  };
}
