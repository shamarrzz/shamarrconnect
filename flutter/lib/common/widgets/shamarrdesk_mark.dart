import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Place, not product. The window is ShamarrConnect; this line is your desk.
///
/// Lowercase Manrope ExtraBold. Light: ink + brand blue. Dark: white + #8FA8F8.
class YourDeskMark extends StatefulWidget {
  const YourDeskMark({
    Key? key,
    this.height = 22,
    this.animate = true,
  }) : super(key: key);

  final double height;
  final bool animate;

  @override
  State<YourDeskMark> createState() => _YourDeskMarkState();
}

class _YourDeskMarkState extends State<YourDeskMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    if (widget.animate) {
      _c.forward();
    } else {
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final mark = SvgPicture.asset(
      dark ? 'assets/your-desk-dark.svg' : 'assets/your-desk.svg',
      height: widget.height,
      fit: BoxFit.contain,
      semanticsLabel: 'your desk',
    );
    final fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    final slide = Tween<Offset>(
      begin: const Offset(-0.035, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: mark,
      ),
    );
  }
}
