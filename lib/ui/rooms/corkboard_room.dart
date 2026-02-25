import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/corkboard_store.dart';
import '../room_frame.dart';
import '../theme/tempus_theme.dart';
import '../theme/tempus_ui.dart';
import '../theme/tv_textfield.dart';

class CorkboardRoom extends StatefulWidget {
  final String roomName;
  const CorkboardRoom({super.key, required this.roomName});

  @override
  State<CorkboardRoom> createState() => _CorkboardRoomState();
}

class _CorkboardRoomState extends State<CorkboardRoom> {
  final GlobalKey _boardKey = GlobalKey();
  List<CorkNoteModel> _notes = const [];
  bool _loading = true;

  String? _dragId;
  Offset _dragStart = Offset.zero;
  Offset _noteStart = Offset.zero;

  Timer? _persistThrottle;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _persistThrottle?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final notes = await CorkboardStore.list();
    if (!mounted) return;
    setState(() {
      _notes = notes;
      _loading = false;
    });
  }

  Future<void> _createAt(Offset local) async {
    await CorkboardStore.addText('', x: local.dx, y: local.dy);
    await _load();
    // Immediately open editor for the newest note.
    final created = _notes.isNotEmpty ? _notes.last : null;
    if (created != null && mounted) {
      _edit(created);
    }
  }

  Future<void> _edit(CorkNoteModel n) async {
    final ctrl = TextEditingController(text: n.text);
    final res = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final b = ctx.tv;
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Edit note', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 10),
              TvTextField(
                controller: ctrl,
                autofocus: true,
                maxLines: 6,
),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    final v = (res ?? '').trim();
    if (v.isEmpty) return;
    await CorkboardStore.updateText(n.id, v);
    await _load();
  }

  Future<void> _delete(CorkNoteModel n) async {
    await CorkboardStore.delete(n.id);
    await _load();
  }

  RenderBox? _boardBox() => _boardKey.currentContext?.findRenderObject() as RenderBox?;

  Offset _toBoardLocal(Offset global) {
    final box = _boardBox();
    if (box == null) return Offset.zero;
    return box.globalToLocal(global);
  }

  void _bringToFront(String id) {
    // Fire and forget: z-order update happens in DB, refresh later.
    CorkboardStore.bringToFront(id);
  }

  void _persistPositionThrottled(String id, Offset pos) {
    _persistThrottle?.cancel();
    _persistThrottle = Timer(const Duration(milliseconds: 120), () {
      CorkboardStore.updatePosition(id, pos.dx, pos.dy);
    });
  }

  @override
  Widget build(BuildContext context) {
    final b = context.tv;

    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : LayoutBuilder(
            builder: (ctx, c) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => FocusScope.of(ctx).unfocus(),
                onDoubleTapDown: (d) async {
                  // Create note where you double-tap.
                  final local = _toBoardLocal(d.globalPosition);
                  await _createAt(local);
                },
                child: Stack(
                  key: _boardKey,
                  children: [
                    // Cork texture background (lighter than current).
                    Positioned.fill(child: CustomPaint(painter: _CorkPainter(isDark: Theme.of(ctx).brightness == Brightness.dark))),
                    // Notes
                    ..._notes.map((n) => _noteWidget(ctx, n)).toList(growable: false),
                    // Helper text
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 14,
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: 0.75,
                          child: Text(
                            'Drag notes freely. Double‑tap to create. Tap a note to edit. Long‑press to delete.',
                            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: b.muted),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );

    return RoomFrame(
      title: 'Corkboard',
      child: body,
      headerTrailing: IconButton(
        tooltip: 'Refresh',
        onPressed: _load,
        icon: const Icon(Icons.refresh),
      ),
      floating: FloatingActionButton.extended(
        onPressed: () async {
          // Create a new note near the top-left if user wants explicit.
          await CorkboardStore.addText('', x: 40, y: 120);
          await _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('New note'),
      ),
    );
  }

  Widget _noteWidget(BuildContext ctx, CorkNoteModel n) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    final ink = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);

    final colors = [
      const Color(0xFFFFF176), // yellow
      const Color(0xFFA7FFEB), // mint
      const Color(0xFFFF8A80), // coral
      const Color(0xFFB388FF), // purple
      const Color(0xFF80D8FF), // blue
      const Color(0xFFFFD180), // orange
      const Color(0xFFCCFF90), // lime
      const Color(0xFFF8BBD0), // pink
    ];
    final paper = colors[n.colorIndex % colors.length].withOpacity(isDark ? 0.85 : 0.95);

    final size = 122.0; // square notes
    final pos = Offset(n.x, n.y);

    return Positioned(
      left: pos.dx,
      top: pos.dy,
      child: Listener(
        onPointerDown: (e) {
          // This is the key: touching begins drag immediately.
          _dragId = n.id;
          _dragStart = e.position;
          _noteStart = pos;
          _bringToFront(n.id);
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) {
            _dragId = n.id;
            _dragStart = d.globalPosition;
            _noteStart = pos;
            _bringToFront(n.id);
          },
          onPanUpdate: (d) {
            if (_dragId != n.id) return;
            final delta = d.globalPosition - _dragStart;
            final next = _noteStart + delta;

            setState(() {
              _notes = _notes
                  .map((x) => x.id == n.id
                      ? CorkNoteModel(
                          id: x.id,
                          text: x.text,
                          x: next.dx,
                          y: next.dy,
                          z: x.z,
                          colorIndex: x.colorIndex,
                          createdAtEpochMs: x.createdAtEpochMs,
                          updatedAtEpochMs: x.updatedAtEpochMs,
                        )
                      : x)
                  .toList(growable: false);
            });

            _persistPositionThrottled(n.id, next);
          },
          onPanEnd: (_) {
            _dragId = null;
          },
          onTap: () => _edit(n),
          onLongPress: () => _delete(n),
          child: Transform.rotate(
            angle: (((n.id.codeUnitAt(0) + n.id.codeUnitAt(1)) % 9) - 4) * (math.pi / 180) * 0.9,
            child: Container(
              width: size,
              height: size,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: paper,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.black.withOpacity(isDark ? 0.25 : 0.18)),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 14,
                    offset: const Offset(0, 10),
                    color: Colors.black.withOpacity(isDark ? 0.35 : 0.18),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // pin dot
                  Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.redAccent.withOpacity(isDark ? 0.9 : 0.85),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                            color: Colors.black.withOpacity(isDark ? 0.45 : 0.25),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Text(
                      n.text.isEmpty ? '…' : n.text,
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                            color: ink,
                            fontWeight: FontWeight.w700, // inkier
                            height: 1.2,
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

class _CorkPainter extends CustomPainter {
  final bool isDark;
  _CorkPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    // Lighter cork base, even in dark mode.
    final base = isDark ? const Color(0xFF3A2B1F) : const Color(0xFFD2B48C);
    final base2 = isDark ? const Color(0xFF4A3627) : const Color(0xFFC9A97C);

    final paint = Paint()..color = base;
    canvas.drawRect(Offset.zero & size, paint);

    // Soft variation wash
    final grad = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          base2.withOpacity(0.55),
          Colors.transparent,
          base2.withOpacity(0.35),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, grad);

    // Speckles/grain
    final r = math.Random(1337);
    final dot = Paint()..style = PaintingStyle.fill;
    final count = (size.width * size.height / 2600).clamp(600, 1400).toInt();
    for (var i = 0; i < count; i++) {
      final x = r.nextDouble() * size.width;
      final y = r.nextDouble() * size.height;
      final s = r.nextDouble() * 1.8 + 0.3;
      final c = Color.lerp(
        Colors.black.withOpacity(isDark ? 0.24 : 0.14),
        Colors.white.withOpacity(isDark ? 0.05 : 0.18),
        r.nextDouble(),
      )!;
      dot.color = c;
      canvas.drawCircle(Offset(x, y), s, dot);
    }

    // Faint “fiber” lines
    final line = Paint()
      ..strokeWidth = 1
      ..color = Colors.black.withOpacity(isDark ? 0.10 : 0.06);
    for (var i = 0; i < 28; i++) {
      final y = (i / 28) * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y + (r.nextDouble() * 18 - 9)), line);
    }
  }

  @override
  bool shouldRepaint(covariant _CorkPainter oldDelegate) => oldDelegate.isDark != isDark;
}
