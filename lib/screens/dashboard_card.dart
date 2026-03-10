import 'package:flutter/material.dart';

class HoverCard extends StatefulWidget {
  final String title;
  final String value;
  final String? value2;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const HoverCard({
    super.key,
    required this.title,
    required this.value,
    this.value2,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // Get screen width to adjust sizes for responsiveness
    final width = MediaQuery.of(context).size.width;

    // Adjust height and font size based on screen width
    final isMobile = width < 600;
    final double cardHeight = isMobile ? 120 : 160;
    final double titleFontSize = isMobile ? 12 : 13;
    final double valueFontSize = isMobile ? 22 : 28;
    final double value2FontSize = isMobile ? 20 : 26;
    final double iconSize = isMobile ? 18 : 20;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: cardHeight,
        transform:
            _isHovered
                ? Matrix4.translationValues(0, -3, 0)
                : Matrix4.identity(),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: _isHovered ? Colors.grey.shade100 : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_isHovered ? 0.1 : 0.05),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: widget.onTap,
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(isMobile ? 8 : 10),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(widget.icon, color: Colors.white, size: iconSize),
                      SizedBox(width: isMobile ? 6 : 8),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: titleFontSize,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child:
                        widget.value2 == null
                            ? Text(
                              widget.value,
                              style: TextStyle(
                                fontSize: valueFontSize,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                            : Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Text(
                                  widget.value,
                                  style: TextStyle(
                                    fontSize: valueFontSize - 2,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  widget.value2!,
                                  style: TextStyle(
                                    fontSize: value2FontSize,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
