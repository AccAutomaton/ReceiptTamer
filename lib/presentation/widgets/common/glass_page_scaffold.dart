import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:receipt_tamer/core/theme/app_system_ui.dart';
import 'package:receipt_tamer/presentation/widgets/common/liquid_glass_background.dart';

class GlassPageScaffold extends StatelessWidget {
  const GlassPageScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.extendBody = false,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.resizeToAvoidBottomInset,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final bool extendBody;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool? resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    final overlayStyle = AppSystemUi.overlayStyleFor(
      Theme.of(context).brightness,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: LiquidGlassBackground(
        child: Scaffold(
          extendBody: extendBody,
          backgroundColor: Colors.transparent,
          appBar: appBar,
          body: body,
          floatingActionButton: floatingActionButton,
          bottomNavigationBar: bottomNavigationBar,
          resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        ),
      ),
    );
  }
}
