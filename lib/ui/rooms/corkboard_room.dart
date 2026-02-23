import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/corkboard_store.dart';
import '../room_frame.dart';
import '../theme/tempus_ui.dart';
import '../theme/tv_textfield.dart';

class CorkboardRoom extends StatefulWidget {
  final String roomName;
  const CorkboardRoom({super.key, required this.roomName});

  @override
  State<CorkboardRoom> createState() => _CorkboardRoomState();
}

class _CorkboardRoomState extends State<CorkboardRoom> {
  final _ctrl = TextEditingController();
  List<CorkNoteModel> _notes = const [];
  bool _loading = true;

  // drag state
  String? _activeId;
  Offset _dragStartLocal = Offset.zero;
  Offset _noteStart = Offset.zero;

  Timer? _debouncePersist;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debouncePersist?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await CorkboardStore.list();
    if (!mounted) return;
    setState(() {
      _notes = list;
      _loading = false;
    });
  }

  Future<void> _add() async {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    _ctrl.clear();
    await CorkboardStore.addText(t);
    await _load();
  }

  Color _noteColor(BuildContext context, int idx) {
    // Soft pastel palette; color is “irrelevant for now”, but we need variety.
    const palette = [
      Color(0xFFFFF2A8),
      Color(0xFFFFD7E5),
      Color(0xFFBFE8FF),
      Color(0xFFCFF7D3),
      Color(0xFFFFE0B8),
      Color(0xFFE3D4FF),
      Color(0xFFD9FFF8),
      Color(0xFFFFF0D6),
    ];
    return palette[idx % palette.length];
  }

  double _rotationFor(String id) {
    // stable “hand placed” angle per id
    final h = id.codeUnits.fold<int>(0, (a, b) => a + b);
    final r = (h % 9) - 4; // -4..+4
    return r * (math.pi / 180.0);
  }

  void _schedulePersistPosition(String id, Offset pos) {
    _debouncePersist?.cancel();
    _debouncePersist = Timer(const Duration(milliseconds: 220), () async {
      await CorkboardStore.updatePosition(id, pos.dx, pos.dy);
    });
  }

  Future<void> _editNote(CorkNoteModel n) async {
    final c = TextEditingController(text: n.text);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 12,
              bottom: 12 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(child: Text('Edit note', style: TextStyle(fontWeight: FontWeight.w800))),
                    IconButton(
                      tooltip: 'Delete',
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        await CorkboardStore.delete(n.id);
                        await _load();
                      },
                      icon: const Icon(Icons.delete_outline),
                    )
                  ],
                ),
                TvTextField(
                  controller: c,
                  hintText: 'Note…',
                  maxLines: 6,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final t = c.text.trim();
                      if (t.isNotEmpty) {
                        await CorkboardStore.updateText(n.id, t);
                        await _load();
                      }
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return RoomFrame(
      title: widget.roomName,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: TvTextField(
                          controller: _ctrl,
                          hintText: 'Drop an idea… (no due date)',
                          onSubmitted: (_) => _add(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Add',
                        onPressed: _add,
                        icon: const Icon(Icons.add),
                      ),
                      IconButton(
                        tooltip: 'Refresh',
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      decoration: BoxDecoration(
                        color: _corkBase(context),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Stack(
                        children: [
                          // “cork-ish” background texture
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _CorkPainter(base: _corkBase(context)),
                            ),
                          ),
                          ..._notes.map((n) => _noteWidget(context, n)).toList(),
                          if (_notes.isEmpty)
                            Center(
                              child: TempusCard(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.push_pin, color: cs.primary),
                                    const SizedBox(height: 10),
                                    const Text('No notes yet', style: TextStyle(fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 6),
                                    Text('Add one above or “Corkboard It” from Signal Bay.', style: TextStyle(color: cs.onSurfaceVariant)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _noteWidget(BuildContext context, CorkNoteModel n) {
    final cs = Theme.of(context).colorScheme;
    final pos = Offset(n.x, n.y);
    final isActive = _activeId == n.id;

    return Positioned(
      left: pos.dx,
      top: pos.dy,
      child: Listener(
        onPointerDown: (_) async {
          // touching a note makes it top-most (primary)
          setState(() => _activeId = n.id);
          await CorkboardStore.bringToFront(n.id);
          await _load(); // refresh z-order
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) {
            setState(() => _activeId = n.id);
            _dragStartLocal = d.localPosition;
            _noteStart = Offset(n.x, n.y);
          },
          onPanUpdate: (d) {
            final newPos = _noteStart + (d.localPosition - _dragStartLocal);
            // update locally for smooth drag
            setState(() {
              _notes = _notes
                  .map((x) => x.id == n.id ? CorkNoteModel(
                        id: x.id,
                        text: x.text,
                        x: newPos.dx,
                        y: newPos.dy,
                        z: x.z,
                        colorIndex: x.colorIndex,
                        createdAtEpochMs: x.createdAtEpochMs,
                        updatedAtEpochMs: x.updatedAtEpochMs,
                      ) : x)
                  .toList(growable: false);
            });
            _schedulePersistPosition(n.id, newPos);
          },
          onLongPress: () => _editNote(n),
          child: Transform.rotate(
            angle: _rotationFor(n.id),
            child: Container(
              width: 172,
              constraints: const BoxConstraints(minHeight: 120),
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
              decoration: BoxDecoration(
                color: _noteColor(context, n.colorIndex),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black.withOpacity(.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isActive ? .26 : .18),
                    blurRadius: isActive ? 18 : 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      n.text,
                      maxLines: 7,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, height: 1.15),
                    ),
                  ),
                  Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _pinColor(n.id),
                        borderRadius: BorderRadius.circular(99),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(.25),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


Color _corkBase(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  // Warm cork tones; in dark mode we go deeper/less orange.
  return isDark ? const Color(0xFF3A2A1D) : const Color(0xFFC8A57A);
}

Color _pinColor(String id) {
  const pins = [
    Color(0xFFE53935), // red
    Color(0xFF1E88E5), // blue
    Color(0xFF43A047), // green
    Color(0xFFFDD835), // yellow
    Color(0xFF8E24AA), // purple
    Color(0xFFFB8C00), // orange
    Color(0xFF00ACC1), // cyan
    Color(0xFF6D4C41), // brown
  ];
  final h = id.codeUnits.fold<int>(0, (a, b) => (a * 31 + b) & 0x7fffffff);
  return pins[h % pins.length];
}


class _CorkPainter extends CustomPainter {
  final Color base;
  _CorkPainter({required this.base});

  @override
  void paint(Canvas canvas, Size size) {
    // Base cork tone.
    final bg = Paint()..color = base;
    canvas.drawRect(Offset.zero & size, bg);

    final rnd = math.Random(7);

    // Dark flecks.
    final dark = Paint()..color = Colors.black.withOpacity(.10);
    for (int i = 0; i < 1200; i++) {
      final dx = rnd.nextDouble() * size.width;
      final dy = rnd.nextDouble() * size.height;
      final r = 0.6 + rnd.nextDouble() * 1.6;
      canvas.drawCircle(Offset(dx, dy), r, dark);
    }

    // Light flecks.
    final light = Paint()..color = Colors.white.withOpacity(.08);
    for (int i = 0; i < 900; i++) {
      final dx = rnd.nextDouble() * size.width;
      final dy = rnd.nextDouble() * size.height;
      final r = 0.6 + rnd.nextDouble() * 1.8;
      canvas.drawCircle(Offset(dx, dy), r, light);
    }

    // Cork “grain” strokes.
    final grain = Paint()
      ..color = Colors.black.withOpacity(.05)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 160; i++) {
      final y = rnd.nextDouble() * size.height;
      final x0 = rnd.nextDouble() * size.width;
      final len = 40 + rnd.nextDouble() * 120;
      final wiggle = 6 + rnd.nextDouble() * 10;

      final path = Path()..moveTo(x0, y);
      for (int s = 1; s <= 6; s++) {
        final t = s / 6.0;
        final x = x0 + len * t;
        final yy = y + math.sin((t * math.pi * 2) + rnd.nextDouble()) * (wiggle * 0.25);
        path.lineTo(x, yy);
      }
      canvas.drawPath(path, grain);
    }

    // Subtle vignette to make notes “pop”.
    final rect = Offset.zero & size;
    final vignette = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          Colors.black.withOpacity(.18),
        ],
        stops: const [0.70, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, vignette);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
