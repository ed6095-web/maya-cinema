// MAYA — Loading widget
import 'package:flutter/material.dart';
import 'package:maya_app/app/theme.dart';

class MayaLoading extends StatelessWidget {
  final String? message;
  const MayaLoading({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: MayaColors.accent, strokeWidth: 2),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message!, style: MayaTextStyles.bodySmall),
          ],
        ],
      ),
    );
  }
}
