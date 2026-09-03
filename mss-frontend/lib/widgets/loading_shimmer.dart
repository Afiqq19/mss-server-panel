import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1E293B),
      highlightColor: const Color(0xFF334155),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class DashboardShimmerLoading extends StatelessWidget {
  const DashboardShimmerLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Host Monitor Shimmer
          const ShimmerBox(width: double.infinity, height: 260, borderRadius: 16),
          const SizedBox(height: 32),
          // Containers Header
          const ShimmerBox(width: 200, height: 28),
          const SizedBox(height: 16),
          // Containers Grid Shimmer
          Row(
            children: const [
              Expanded(child: ShimmerBox(width: double.infinity, height: 160, borderRadius: 16)),
              SizedBox(width: 16),
              Expanded(child: ShimmerBox(width: double.infinity, height: 160, borderRadius: 16)),
              SizedBox(width: 16),
              Expanded(child: ShimmerBox(width: double.infinity, height: 160, borderRadius: 16)),
            ],
          ),
          const SizedBox(height: 32),
          // App Launchers Header
          const ShimmerBox(width: 180, height: 28),
          const SizedBox(height: 16),
          // App Launchers Shimmer
          Row(
            children: const [
              Expanded(child: ShimmerBox(width: double.infinity, height: 110, borderRadius: 16)),
              SizedBox(width: 16),
              Expanded(child: ShimmerBox(width: double.infinity, height: 110, borderRadius: 16)),
              SizedBox(width: 16),
              Expanded(child: ShimmerBox(width: double.infinity, height: 110, borderRadius: 16)),
              SizedBox(width: 16),
              Expanded(child: ShimmerBox(width: double.infinity, height: 110, borderRadius: 16)),
            ],
          ),
        ],
      ),
    );
  }
}
