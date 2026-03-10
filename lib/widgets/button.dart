import 'package:flutter/material.dart';

const double defaultBorderRadius = 3.0;

class StretchableButton extends StatelessWidget {
  final VoidCallback onPressed;
  final double borderRadius;
  final double buttonPadding;
  final Color buttonColor;
  final Color? splashColor;
  final Color? buttonBorderColor;
  final List<Widget> children;

  const StretchableButton({
    super.key,
    required this.onPressed,
    this.borderRadius = defaultBorderRadius,
    this.buttonPadding = 12.0,
    this.buttonColor = Colors.blue,
    this.splashColor,
    this.buttonBorderColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final contents = List<Widget>.from(children);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.minWidth == 0) {
          contents.add(const SizedBox.shrink());
        } else {
          contents.add(const Spacer());
        }

        final borderSide =
            buttonBorderColor != null
                ? BorderSide(color: buttonBorderColor!)
                : BorderSide.none;

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.fromBorderSide(borderSide),
          ),
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              splashFactory:
                  splashColor != null ? InkRipple.splashFactory : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              padding: EdgeInsets.all(buttonPadding),
              elevation: 0,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: contents),
          ),
        );
      },
    );
  }
}
