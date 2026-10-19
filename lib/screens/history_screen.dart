import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/score_repository.dart';
import '../models/shooting_round.dart';
import 'capture_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({required this.repository, super.key});

  final ScoreRepository repository;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<ShootingDay>> _days;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _days = widget.repository.loadDays();

  Future<void> _startRound() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CaptureScreen(repository: widget.repository),
      ),
    );
    if (mounted) setState(_reload);
  }

  Future<void> _deleteRound(ShootingRound round) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this round?'),
        content: const Text('Its scores will be removed from that day’s total.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep round'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.repository.deleteRound(round.id);
      if (mounted) setState(_reload);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<List<ShootingDay>>(
          future: _days,
          builder: (context, snapshot) {
            final days = snapshot.data ?? const <ShootingDay>[];
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3EEE7),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(Icons.adjust_rounded,
                              color: Color(0xFF245B48)),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('RINGSCORE',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  letterSpacing: 1.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF557066),
                                )),
                            Text('Your rounds', style: theme.textTheme.titleLarge),
                          ],
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Privacy: scores stay on this device',
                          onPressed: () => showAboutDialog(
                            context: context,
                            applicationName: 'RingScore',
                            applicationVersion: '0.1.0',
                            children: const [
                              Text(
                                'Round scores are stored on this device. Target photos are discarded after review.',
                              ),
                            ],
                          ),
                          icon: const Icon(Icons.shield_outlined),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  sliver: SliverToBoxAdapter(
                    child: _HeroCard(
                      roundCount: days.fold<int>(
                        0,
                        (count, day) => count + day.rounds.length,
                      ),
                      onTap: _startRound,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        Text('Score history', style: theme.textTheme.titleLarge),
                        const Spacer(),
                        Text('LOCAL ONLY',
                            style: theme.textTheme.labelSmall?.copyWith(
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF7B8982),
                            )),
                      ],
                    ),
                  ),
                ),
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (days.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyHistory(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
                    sliver: SliverList.builder(
                      itemCount: days.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _DayCard(
                          day: days[index],
                          onDelete: _deleteRound,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startRound,
        backgroundColor: const Color(0xFF245B48),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New round'),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.roundCount, required this.onTap});

  final int roundCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [Color(0xFF244E40), Color(0xFF326B53)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x22244E40), blurRadius: 22, offset: Offset(0, 9)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'One more end.\nOne clear score.',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 24,
                    height: 1.15,
                    letterSpacing: -0.6,
                  ),
                ),
              ),
              _MiniTarget(),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            roundCount == 0
                ? 'Your next round starts here.'
                : '$roundCount ${roundCount == 1 ? 'round' : 'rounds'} recorded',
            style: const TextStyle(color: Color(0xFFD2E2D8), fontSize: 14),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF2C65D),
                foregroundColor: const Color(0xFF26372F),
              ),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Score a round'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniTarget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final ring in const [
            (Color(0xFFF9FAF4), 74.0),
            (Color(0xFF222C29), 60.0),
            (Color(0xFF3572A0), 46.0),
            (Color(0xFFD9503F), 32.0),
            (Color(0xFFF3C84F), 18.0),
          ])
            Container(
              width: ring.$2,
              height: ring.$2,
              decoration: BoxDecoration(color: ring.$1, shape: BoxShape.circle),
            ),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day, required this.onDelete});

  final ShootingDay day;
  final ValueChanged<ShootingRound> onDelete;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(day.date);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(17, 16, 12, 8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(DateFormat('EEEE, d MMMM').format(date),
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 3),
                      Text('${day.rounds.length} ${day.rounds.length == 1 ? 'round' : 'rounds'}',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
                Text('${day.total}',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontSize: 30,
                          color: const Color(0xFF245B48),
                        )),
                const SizedBox(width: 6),
                Text('TOTAL',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          letterSpacing: 1,
                          color: const Color(0xFF7B8982),
                        )),
              ],
            ),
            const Divider(height: 19),
            for (var i = 0; i < day.rounds.length; i++)
              _RoundRow(
                index: day.rounds.length - i,
                round: day.rounds[i],
                onDelete: () => onDelete(day.rounds[i]),
              ),
          ],
        ),
      ),
    );
  }
}

class _RoundRow extends StatelessWidget {
  const _RoundRow({required this.index, required this.round, required this.onDelete});

  final int index;
  final ShootingRound round;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Text('Round $index', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(width: 9),
          Text('${round.scores.length} arrows',
              style: Theme.of(context).textTheme.bodySmall),
          const Spacer(),
          Text('${round.total}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Delete round',
            onPressed: onDelete,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(17),
              decoration: const BoxDecoration(
                color: Color(0xFFE9EFE9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.track_changes_rounded,
                  size: 30, color: Color(0xFF557066)),
            ),
            const SizedBox(height: 16),
            Text('No rounds yet', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            const Text(
              'Your saved scores will appear here, grouped by day.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
