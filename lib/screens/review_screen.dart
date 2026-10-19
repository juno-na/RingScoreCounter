import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/score_repository.dart';
import '../services/target_analyzer.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({
    required this.imageBytes,
    required this.capturedAt,
    required this.repository,
    required this.analyzer,
    super.key,
  });

  final Uint8List imageBytes;
  final DateTime capturedAt;
  final ScoreRepository repository;
  final TargetAnalyzer analyzer;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final List<_Impact> _impacts = [];
  final _photoKey = GlobalKey();
  bool _saving = false;
  String _analysisMessage = 'Checking the photo…';
  int _selectedScore = 10;

  int get _total => _impacts.fold(0, (sum, impact) => sum + impact.score);

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  Future<void> _analyze() async {
    try {
      final analysis = await widget.analyzer.analyze(widget.imageBytes);
      if (!mounted) return;
      setState(() {
        _analysisMessage = analysis.message;
        for (final impact in analysis.impacts) {
          _impacts.add(_Impact(impact.x, impact.y, impact.score));
        }
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _analysisMessage =
              'The photo could not be analyzed. Tap each arrow’s ring to enter its score.',
        );
      }
    }
  }

  void _markImpact(Offset localPosition, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.48;
    final dx = (localPosition.dx - center.dx) / radius;
    final dy = (localPosition.dy - center.dy) / radius;
    if ((dx * dx) + (dy * dy) > 1.12) return;
    setState(() => _impacts.add(_Impact(dx, dy, _selectedScore)));
  }

  void _moveImpact(int index, Offset globalPosition) {
    final renderObject = _photoKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || index >= _impacts.length) return;
    final local = renderObject.globalToLocal(globalPosition);
    final side = renderObject.size.shortestSide;
    if (side == 0) return;
    final dx = (local.dx - side / 2) / (side * 0.48);
    final dy = (local.dy - side / 2) / (side * 0.48);
    if ((dx * dx) + (dy * dy) > 1.12) return;
    setState(() => _impacts[index] = _Impact(dx, dy, _impacts[index].score));
  }

  Future<void> _save() async {
    if (_impacts.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await widget.repository.saveRound(
        capturedAt: widget.capturedAt,
        scores: _impacts.map((impact) => impact.score).toList(),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save this round. Please try again.'),
          ),
        );
      }
    }
  }

  Future<void> _cancel() async {
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review round'),
        leading: IconButton(
          tooltip: 'Discard photo',
          onPressed: _cancel,
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 3, 22, 14),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_outlined,
                    color: Color(0xFF245B48),
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _analysisMessage,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final side = math.min(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      );
                      final size = Size.square(side);
                      return Center(
                        child: SizedBox.fromSize(
                          size: size,
                          key: _photoKey,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapUp: (details) =>
                                _markImpact(details.localPosition, size),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.memory(
                                  widget.imageBytes,
                                  fit: BoxFit.cover,
                                ),
                                for (var i = 0; i < _impacts.length; i++)
                                  _ImpactMarker(
                                    impact: _impacts[i],
                                    size: size,
                                    onRemove: () =>
                                        setState(() => _impacts.removeAt(i)),
                                    onMove: (position) =>
                                        _moveImpact(i, position),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        'Tap to add a missed arrow; tap a marker to remove it',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const Spacer(),
                      Text(
                        '${_impacts.length} arrows',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 7,
                    runSpacing: 7,
                    children: List.generate(11, (score) {
                      return ChoiceChip(
                        label: Text('$score'),
                        selected: score == _selectedScore,
                        onSelected: (_) =>
                            setState(() => _selectedScore = score),
                        visualDensity: VisualDensity.compact,
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        'TOTAL',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              letterSpacing: 1.2,
                              color: const Color(0xFF64716B),
                            ),
                      ),
                      const Spacer(),
                      Text(
                        '$_total',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontSize: 32,
                              color: const Color(0xFF245B48),
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),
                  FilledButton(
                    onPressed: _impacts.isEmpty || _saving ? null : _save,
                    child: Text(_saving ? 'Saving…' : 'Confirm and save round'),
                  ),
                  if (_impacts.isNotEmpty)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => setState(() => _impacts.removeLast()),
                        icon: const Icon(Icons.undo_rounded, size: 18),
                        label: const Text('Undo last arrow'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Impact {
  const _Impact(this.x, this.y, this.score);
  final double x;
  final double y;
  final int score;
}

class _ImpactMarker extends StatelessWidget {
  const _ImpactMarker({
    required this.impact,
    required this.size,
    required this.onRemove,
    required this.onMove,
  });

  final _Impact impact;
  final Size size;
  final VoidCallback onRemove;
  final ValueChanged<Offset> onMove;

  @override
  Widget build(BuildContext context) {
    final x = size.width * (0.5 + impact.x * 0.48) - 14;
    final y = size.height * (0.5 + impact.y * 0.48) - 14;
    return Positioned(
      left: x,
      top: y,
      child: GestureDetector(
        onTap: onRemove,
        onPanUpdate: (details) => onMove(details.globalPosition),
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF245B48),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Text(
            '${impact.score}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
