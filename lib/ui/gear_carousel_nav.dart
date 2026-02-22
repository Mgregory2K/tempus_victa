import 'package:flutter/material.dart';
import 'modules.dart';

class GearCarouselNav extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const GearCarouselNav({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  State<GearCarouselNav> createState() => _GearCarouselNavState();
}

class _GearCarouselNavState extends State<GearCarouselNav> {
  static const double _height = 86;
  static const double _viewportFraction = 0.28;
  static const int _loopMultiplier = 2000;

  late final PageController _controller;

  int get _n => kPrimaryModules.length;
  int get _initialPage => (_n * _loopMultiplier) + widget.selectedIndex;

  int _lastCommittedIndex = -1;
  int _lastSnappedPage = -1;

  @override
  void initState() {
    super.initState();
    _controller = PageController(
      viewportFraction: _viewportFraction,
      initialPage: _initialPage,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _moduleIndexForPage(int page) => ((page % _n) + _n) % _n;

  double _currentPageDouble() {
    if (!_controller.hasClients) return _initialPage.toDouble();
    return _controller.page ?? _controller.initialPage.toDouble();
  }

  int _pageWithHalfThreshold(double p) {
    // Explicit 50% threshold:
    // If you're >= 0.5 into the next page, snap forward; otherwise snap back.
    final base = p.floor();
    final frac = p - base;
    return (frac >= 0.5) ? base + 1 : base;
  }

  void _commitIndexForPage(int page) {
    final idx = _moduleIndexForPage(page);
    if (idx == _lastCommittedIndex) return;
    _lastCommittedIndex = idx;
    widget.onSelect(idx);
  }

  Future<void> _snapToNearest() async {
    if (!_controller.hasClients) return;

    final p = _currentPageDouble();
    final targetPage = _pageWithHalfThreshold(p);

    if (targetPage == _lastSnappedPage) {
      _commitIndexForPage(targetPage);
      return;
    }
    _lastSnappedPage = targetPage;

    final distance = (targetPage - p).abs();
    final ms = (180 + (distance * 140)).clamp(180, 520).toInt();

    await _controller.animateToPage(
      targetPage,
      duration: Duration(milliseconds: ms),
      curve: Curves.easeOutCubic,
    );

    // HARD LOCK: remove any tiny fractional drift so the icon is *exactly centered*.
    // This is the part that fixes the "stops slightly off center" feel.
    if (_controller.hasClients) {
      _controller.jumpToPage(targetPage);
    }

    _commitIndexForPage(targetPage);
  }

  Future<void> _animateToModule(int targetModuleIndex) async {
    if (!_controller.hasClients) {
      widget.onSelect(targetModuleIndex);
      return;
    }

    final p = _currentPageDouble();
    final basePage = _pageWithHalfThreshold(p);
    final currentModule = _moduleIndexForPage(basePage);

    // Shortest direction around the ring
    int forward = (targetModuleIndex - currentModule) % _n;
    int backward = forward - _n;
    int delta = (forward.abs() <= backward.abs()) ? forward : backward;

    final targetPage = basePage + delta;

    final distance = delta.abs().toDouble();
    final ms = (180 + (distance * 120)).clamp(180, 620).toInt();

    await _controller.animateToPage(
      targetPage,
      duration: Duration(milliseconds: ms),
      curve: Curves.easeOutCubic,
    );

    if (_controller.hasClients) {
      _controller.jumpToPage(targetPage);
    }

    _commitIndexForPage(targetPage);
  }

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;

    return Material(
      elevation: 8,
      color: surface.withOpacity(0.92),
      child: SizedBox(
        height: _height,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: Container(height: 1, color: Colors.white12),
            ),

            NotificationListener<ScrollNotification>(
              onNotification: (n) {
                // Snap only when scrolling fully ends.
                if (n is ScrollEndNotification) {
                  _snapToNearest();
                }
                return false;
              },
              child: PageView.builder(
                controller: _controller,
                pageSnapping: false, // free spin
                physics: const ClampingScrollPhysics(), // Android-friendly, reduces “drifty” settle
                itemBuilder: (context, pageIndex) {
                  final moduleIndex = _moduleIndexForPage(pageIndex);
                  final mod = kPrimaryModules[moduleIndex];

                  return AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final page = _currentPageDouble();
                      final distance = (pageIndex - page).abs();

                      final t = (1.0 - (distance * 0.9)).clamp(0.0, 1.0);
                      final scale = 0.80 + (0.35 * t);
                      final opacity = 0.40 + (0.60 * t);

                      return Center(
                        child: Opacity(
                          opacity: opacity,
                          child: Transform.scale(
                            scale: scale,
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: _NavItem(
                      icon: mod.icon,
                      label: mod.name,
                      onTap: () => _animateToModule(moduleIndex),
                    ),
                  );
                },
              ),
            ),

            // Center “notch” marker
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  width: 44,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 44,
      child: Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 26),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}