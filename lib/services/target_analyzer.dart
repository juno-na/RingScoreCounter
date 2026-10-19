import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Contract for the local vision pipeline. Target detection is kept separate
/// from scoring so additional face layouts can be added later.
abstract interface class TargetAnalyzer {
  Future<TargetAnalysis> analyze(Uint8List imageBytes);
}

class TargetAnalysis {
  const TargetAnalysis({
    required this.impacts,
    required this.confidence,
    required this.message,
  });

  final List<DetectedImpact> impacts;
  final double confidence;
  final String message;
}

class DetectedImpact {
  const DetectedImpact({
    required this.x,
    required this.y,
    required this.score,
    required this.confidence,
  });

  /// Coordinates relative to the face center, where the outer face radius is 1.
  /// The review screen uses this same -1..1 coordinate space.
  final double x;
  final double y;
  final int score;
  final double confidence;
}

/// First on-device prototype for a centered, single-spot FITA face.
///
/// This detects small dark impact marks and estimates ring scores from their
/// distance to the face center. It is intended for generated samples and early
/// range evaluation; perspective correction and robust target localization
/// still need to be added after testing real photos.
class PrototypeTargetAnalyzer implements TargetAnalyzer {
  @override
  Future<TargetAnalysis> analyze(Uint8List imageBytes) async {
    // Cap decode width to avoid holding a full-resolution phone photo and
    // multiple full-image working buffers in memory at once.
    final codec = await ui.instantiateImageCodec(imageBytes, targetWidth: 1200);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (pixels == null) {
        throw const FormatException('Could not read image pixels.');
      }
      return _analyzePixels(pixels, image.width, image.height);
    } finally {
      image.dispose();
      codec.dispose();
    }
  }

  TargetAnalysis _analyzePixels(ByteData data, int width, int height) {
    final count = width * height;
    var minX = width;
    var minY = height;
    var maxX = -1;
    var maxY = -1;

    // The colored FITA bands occupy about 60% of the face radius. Their
    // chromatic pixels provide a simple center/scale estimate for this
    // front-facing prototype.
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final offset = (y * width + x) * 4;
        final r = data.getUint8(offset);
        final g = data.getUint8(offset + 1);
        final b = data.getUint8(offset + 2);
        final high = math.max(r, math.max(g, b));
        final low = math.min(r, math.min(g, b));
        if (high - low > 65 && high > 90) {
          minX = math.min(minX, x).toInt();
          minY = math.min(minY, y).toInt();
          maxX = math.max(maxX, x).toInt();
          maxY = math.max(maxY, y).toInt();
        }
      }
    }
    if (maxX < minX || maxY < minY) {
      return const TargetAnalysis(
        impacts: [],
        confidence: 0,
        message:
            'Could not locate the colored target rings. Adjust the photo and try again.',
      );
    }

    final centerX = (minX + maxX) / 2;
    final centerY = (minY + maxY) / 2;
    final faceRadius = ((maxX - minX) + (maxY - minY)) / 2 / 1.2;
    if (faceRadius < 8) {
      return const TargetAnalysis(
        impacts: [],
        confidence: 0,
        message:
            'The target is too small in the photo. Move closer and try again.',
      );
    }

    // Find connected dark components. Large components are target ring edges;
    // small components inside the face are treated as arrow holes.
    final visited = Uint8List(count);
    final queue = Int32List(count);
    final impacts = <DetectedImpact>[];
    final faceLeft = math.max(0, (centerX - faceRadius * 1.08).floor()).toInt();
    final faceRight = math
        .min(width - 1, (centerX + faceRadius * 1.08).ceil())
        .toInt();
    final faceTop = math.max(0, (centerY - faceRadius * 1.08).floor()).toInt();
    final faceBottom = math
        .min(height - 1, (centerY + faceRadius * 1.08).ceil())
        .toInt();

    bool isDark(int index) {
      final offset = index * 4;
      return data.getUint8(offset) < 65 &&
          data.getUint8(offset + 1) < 65 &&
          data.getUint8(offset + 2) < 65;
    }

    for (var y = faceTop; y <= faceBottom; y++) {
      for (var x = faceLeft; x <= faceRight; x++) {
        final start = y * width + x;
        if (visited[start] != 0 || !isDark(start)) continue;
        var head = 0;
        var tail = 0;
        var sumX = 0;
        var sumY = 0;
        var componentMinX = x;
        var componentMaxX = x;
        var componentMinY = y;
        var componentMaxY = y;
        visited[start] = 1;
        queue[tail++] = start;
        while (head < tail) {
          final current = queue[head++];
          final px = current % width;
          final py = current ~/ width;
          sumX += px;
          sumY += py;
          componentMinX = math.min(componentMinX, px).toInt();
          componentMaxX = math.max(componentMaxX, px).toInt();
          componentMinY = math.min(componentMinY, py).toInt();
          componentMaxY = math.max(componentMaxY, py).toInt();
          for (var dy = -1; dy <= 1; dy++) {
            for (var dx = -1; dx <= 1; dx++) {
              final nx = px + dx;
              final ny = py + dy;
              if (nx < faceLeft ||
                  nx > faceRight ||
                  ny < faceTop ||
                  ny > faceBottom) {
                continue;
              }
              final neighbor = ny * width + nx;
              if (visited[neighbor] == 0 && isDark(neighbor)) {
                visited[neighbor] = 1;
                queue[tail++] = neighbor;
              }
            }
          }
        }
        final componentWidth = componentMaxX - componentMinX + 1;
        final componentHeight = componentMaxY - componentMinY + 1;
        if (tail < 12 ||
            tail > faceRadius * faceRadius * 0.004 ||
            math.max(componentWidth, componentHeight) > faceRadius * 0.08) {
          continue;
        }

        final dx = (sumX / tail - centerX) / faceRadius;
        final dy = (sumY / tail - centerY) / faceRadius;
        final radialDistance = math.sqrt(dx * dx + dy * dy);
        final score = _scoreAt(radialDistance);
        impacts.add(
          DetectedImpact(
            x: dx,
            y: dy,
            score: score,
            confidence: (0.94 - (tail / (faceRadius * faceRadius) * 4))
                .clamp(0.55, 0.94)
                .toDouble(),
          ),
        );
      }
    }
    impacts.sort((a, b) => a.y.compareTo(b.y));
    final meanConfidence = impacts.isEmpty
        ? 0.0
        : impacts.fold<double>(
                0,
                (total, impact) => total + impact.confidence,
              ) /
              impacts.length;
    return TargetAnalysis(
      impacts: impacts,
      confidence: meanConfidence,
      message: impacts.isEmpty
          ? 'No arrow holes detected. You can add impacts manually for review.'
          : 'Detected ${impacts.length} arrow${impacts.length == 1 ? '' : 's'}. Review the positions and scores.',
    );
  }

  int _scoreAt(double radius) {
    if (radius > 1) return 0;
    if (radius <= 0.1) return 10;
    return (10 - (radius * 10).floor()).clamp(1, 9).toInt();
  }
}
