// MAYA — Shared Widgets: Section header + skeleton loaders

import 'package:flutter/material.dart';
import 'package:maya_app/app/theme.dart';
import 'package:shimmer/shimmer.dart';

/// Section with a title header and child content.
class MayaSection extends StatelessWidget {
  final String title;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;

  const MayaSection({
    super.key,
    required this.title,
    required this.child,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: MayaTextStyles.titleMedium),
            if (actionLabel != null && onAction != null)
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ),
        const SizedBox(height: MayaSpacing.md),
        child,
      ],
    );
  }
}

/// Shimmer skeleton for a horizontal row of cards.
class MayaRowSkeleton extends StatelessWidget {
  const MayaRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SkeletonBox(width: 120, height: 18),
        const SizedBox(height: MayaSpacing.md),
        SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 5,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, __) => const _SkeletonBox(width: 120, height: 180, radius: 8),
          ),
        ),
      ],
    );
  }
}

/// Shimmer skeleton for a movie grid.
class MayaGridSkeleton extends StatelessWidget {
  const MayaGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SkeletonBox(width: 100, height: 18),
        const SizedBox(height: MayaSpacing.md),
        LayoutBuilder(builder: (context, constraints) {
          final cols = (constraints.maxWidth / 180).floor().clamp(2, 6);
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              childAspectRatio: 0.65,
              crossAxisSpacing: MayaSpacing.md,
              mainAxisSpacing: MayaSpacing.md,
            ),
            itemCount: 8,
            itemBuilder: (_, __) => const _SkeletonBox(width: double.infinity, height: double.infinity, radius: 8),
          );
        }),
      ],
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _SkeletonBox({required this.width, required this.height, this.radius = 4});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: MayaColors.surfaceSecondary,
      highlightColor: MayaColors.surfaceElevated,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: MayaColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}
