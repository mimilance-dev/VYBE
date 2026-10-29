import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../widgets/vybe_avatar.dart';
import '../../../widgets/vybe_card.dart';
import '../../../widgets/vybe_tag.dart';

class ListeningRoomPreview extends StatelessWidget {
  const ListeningRoomPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Preview of a VYBE listening room with two connected listeners',
      child: VYBECard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.circle, size: 8, color: AppColors.success),
                const SizedBox(width: 9),
                Text(
                  'LATE NIGHT LOOP',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                const Icon(Icons.more_horiz_rounded, color: AppColors.muted),
              ],
            ),
            const SizedBox(height: 18),
            const _AlbumArtwork(),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Afterglow', style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 5),
                      Text('Mira Sol  ·  Blue Hour', style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
                const VYBETag(label: 'Spotify', icon: Icons.graphic_eq_rounded),
              ],
            ),
            const SizedBox(height: 22),
            const _ProgressPreview(),
            const SizedBox(height: 18),
            Row(
              children: [
                const _PreviewControl(icon: Icons.skip_previous_rounded),
                const SizedBox(width: 14),
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: AppColors.violetMagentaGradient),
                  ),
                  child: const Icon(Icons.pause_rounded, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                const _PreviewControl(icon: Icons.skip_next_rounded),
                const Spacer(),
                const VYBEAvatar(
                  initials: 'A',
                  label: 'Aditya',
                  color: AppColors.accent,
                  isOnline: true,
                  size: 36,
                ),
                Transform.translate(
                  offset: const Offset(-8, 0),
                  child: const VYBEAvatar(
                    initials: 'R',
                    label: 'Rahul',
                    color: AppColors.blue,
                    isOnline: true,
                    size: 36,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.035),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.favorite_rounded, size: 14, color: AppColors.accent),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Both listening',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ),
                  Text('now', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumArtwork extends StatelessWidget {
  const _AlbumArtwork();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.52,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF5B21B6), Color(0xFF171044), Color(0xFF07050F)],
                ),
              ),
            ),
            Positioned(
              top: -30,
              right: 6,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [AppColors.accent.withValues(alpha: 0.8), Colors.transparent],
                  ),
                ),
              ),
            ),
            CustomPaint(painter: _ArtworkPainter()),
            Positioned(
              left: 20,
              bottom: 18,
              child: Text(
                'BLUE\nHOUR',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtworkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.68, size.height * 0.46);
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (var index = 0; index < 7; index++) {
      ringPaint.color = Colors.white.withValues(alpha: 0.11 - index * 0.01);
      canvas.drawCircle(center, 22 + index * 17, ringPaint);
    }

    final hillPaint = Paint()..color = const Color(0xFF171044).withValues(alpha: 0.86);
    final hill = Path()
      ..moveTo(0, size.height * 0.72)
      ..cubicTo(size.width * 0.27, size.height * 0.52, size.width * 0.42,
          size.height * 0.91, size.width * 0.67, size.height * 0.68)
      ..cubicTo(size.width * 0.82, size.height * 0.53, size.width * 0.92,
          size.height * 0.75, size.width, size.height * 0.58)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(hill, hillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ProgressPreview extends StatelessWidget {
  const _ProgressPreview();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: const LinearProgressIndicator(
            value: 0.42,
            minHeight: 4,
            backgroundColor: Color(0xFF332B47),
            valueColor: AlwaysStoppedAnimation(AppColors.accent),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text('1:24', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
            const Spacer(),
            Text('3:18', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
          ],
        ),
      ],
    );
  }
}

class _PreviewControl extends StatelessWidget {
  const _PreviewControl({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Icon(icon, size: 25, color: AppColors.textSecondary);
  }
}