import 'package:flutter/material.dart';

/// A compact composite icon for "Mietanfragen":
/// - Open cardboard box (primary, bottom)
/// - Rounded speech bubble (secondary, above and clearly smaller)
/// Matches Material outlined style with no background.
class BoxChatIcon extends StatelessWidget {
  const BoxChatIcon({super.key, this.size = 24, this.color});

  /// The overall square size of the composed icon.
  final double size;

  /// The color to apply to both glyphs. Defaults to iconTheme.color.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? Theme.of(context).iconTheme.color ?? Colors.white;

    // Proportional sizing tuned for balance and clarity
    // Make dialog (bubble) a little larger, box a touch smaller (per feedback)
    final boxSize = size * 0.76;   // slightly smaller box
    final bubbleSize = size * 0.56; // slightly larger bubble

    // Ensure the bubble never touches the box by enforcing a minimum vertical gap
    final minGap = size * 0.06; // required empty space between bubble bottom and box top
    // Box top Y (from top of the square) when aligned to bottom: size - boxSize
    final boxTopY = size - boxSize;
    // Desired bubble bottom Y so that bubble doesn't touch the box
    final desiredBubbleBottomY = (boxTopY - minGap).clamp(0.0, size);
    // Without translation, bubble bottom Y would be bubbleSize. We translate by dy to reach desired Y.
    double bubbleDy = desiredBubbleBottomY - bubbleSize;
    // Keep bubble visible and comfortably inside/near the frame
    final minDy = -size * 0.40; // don't push too far above
    final maxDy = size * 0.10;  // don't push below top area
    bubbleDy = bubbleDy.clamp(minDy, maxDy);

    // Place the bubble to the right side; a tiny outward nudge for separation
    final bubbleDx = size * 0.01; // subtle nudge to the right
    // Keep the box low to increase vertical separation from the bubble
    final boxDy = 0.0;

    return Semantics(
      label: 'Offene Box mit runder Sprechblase',
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(children: [
          // Rounded speech bubble above the box, shifted to the right side
          Align(
            alignment: Alignment.topRight,
            child: Transform.translate(
              offset: Offset(bubbleDx, bubbleDy),
              child: Icon(Icons.maps_ugc_outlined, size: bubbleSize, color: iconColor),
            ),
          ),
          // Open cardboard box (inventory_2_outlined looks like an open carton)
          Align(
            alignment: Alignment.bottomCenter,
            child: Transform.translate(
              offset: Offset(0, -boxDy),
              child: Icon(Icons.inventory_2_outlined, size: boxSize, color: iconColor),
            ),
          ),
        ]),
      ),
    );
  }
}
