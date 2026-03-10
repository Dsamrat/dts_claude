import 'package:flutter/material.dart';
import 'package:dts/constants/common.dart';

@immutable
class Navbar extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final bool backButton;
  final bool transparent;

  final bool rightOptions;
  final bool showFilter;
  final VoidCallback? onFilterPressed;
  final bool filterEnabled;
  // final void Function(String)? getCurrentPage;
  final bool noShadow;
  final Color bgColor;

  const Navbar({
    super.key,
    this.title = "Home",

    this.transparent = false,
    this.rightOptions = false,
    this.showFilter = false, // 👈 NEW
    this.onFilterPressed,
    this.filterEnabled = false,
    // this.getCurrentPage,
    this.backButton = false,
    this.noShadow = false,
    this.bgColor = secondaryTeal,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  NavbarState createState() => NavbarState();
}

// class _NavbarState extends State<Navbar> {
class NavbarState extends State<Navbar> {
  late String activeTag;

  @override
  void initState() {
    super.initState();
    activeTag = '';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: kToolbarHeight + MediaQuery.of(context).padding.top,
      decoration: BoxDecoration(
        color: !widget.transparent ? widget.bgColor : Colors.transparent,
        boxShadow: [
          BoxShadow(
            color:
                !widget.transparent && !widget.noShadow
                    ? colorInitial
                    : Colors.transparent,
            spreadRadius: -10,
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Builder(
                        builder: (scaffoldContext) {
                          return IconButton(
                            icon: Icon(
                              widget.backButton
                                  ? Icons.arrow_back_ios
                                  : Icons.menu,
                              color: colorText,
                            ),
                            onPressed: () {
                              if (widget.backButton) {
                                Navigator.pop(context, true);
                              } else {
                                debugPrint('clicked burger menu');
                                Scaffold.of(context).openDrawer();
                              }
                            },
                          );
                        },
                      ),

                      /*IconButton(
                        icon: Icon(
                          widget.backButton ? Icons.arrow_back_ios : Icons.menu,
                          color:
                              !widget.transparent
                                  ? (widget.bgColor == colorText
                                      ? colorInitial
                                      : colorText)
                                  : colorText,
                          size: 24.0,
                        ),
                        onPressed: () {
                          if (widget.backButton) {
                            Navigator.pop(context, true);
                          } else {
                            debugPrint('clicked burger menu');
                            ScaffoldMessenger.of(context).openDrawer();
                          }
                        },
                      ),*/
                      Text(
                        widget.title,
                        style: TextStyle(
                          color:
                              !widget.transparent
                                  ? (widget.bgColor == colorText
                                      ? colorInitial
                                      : colorText)
                                  : colorText,
                          fontWeight: FontWeight.w600,
                          fontSize: 18.0,
                        ),
                      ),
                    ],
                  ),
                  if (widget.rightOptions)
                    Row(
                      children: [
                        if (widget.showFilter)
                          IconButton(
                            icon: Icon(
                              widget.filterEnabled
                                  ? Icons.filter_alt_off
                                  : Icons.filter_alt,
                              color: Colors.white,
                            ),
                            tooltip:
                                widget.filterEnabled
                                    ? "Hide Filters"
                                    : "Show Filters",
                            onPressed: widget.onFilterPressed,
                          ),

                        /*IconButton(
                          icon: Icon(
                            Icons.notifications_active,
                            color:
                                !widget.transparent
                                    ? (widget.bgColor == colorText
                                        ? colorInitial
                                        : colorText)
                                    : colorText,
                            size: 22.0,
                          ),
                          onPressed: () {
                            Navigator.pushNamed(context, '/pro');
                          },
                        ),*/
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
