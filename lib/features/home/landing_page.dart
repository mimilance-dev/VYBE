import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../theme/app_colors.dart';
import '../../widgets/vybe_button.dart';
import '../../widgets/vybe_gradient_background.dart';
import 'widgets/listening_room_preview.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: VYBEGradientBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= AppConstants.desktopBreakpoint;
              final horizontalPadding = isDesktop
                  ? AppConstants.pageHorizontalPadding
                  : AppConstants.mobileHorizontalPadding;

              return SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppConstants.pageMaxWidth,
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                      child: Column(
                        children: [
                          _LandingHeader(isCompact: !isDesktop),
                          const SizedBox(height: 48),
                          if (isDesktop)
                            const _DesktopHero()
                          else
                            const _CompactHero(),
                          const SizedBox(height: 56),
                          const _FooterNote(),
                          const SizedBox(height: 28),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LandingHeader extends StatelessWidget {
  const _LandingHeader({required this.isCompact});

  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Row(
        children: [
          const _BrandMark(),
          const Spacer(),
          if (!isCompact) ...[
            const Icon(Icons.graphic_eq_rounded, color: AppColors.success, size: 16),
            const SizedBox(width: 8),
            Text(
              'A little closer, wherever you are',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary.withValues(alpha: 0.82),
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            gradient: const LinearGradient(colors: AppColors.violetMagentaGradient),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.28),
                blurRadius: 22,
              ),
            ],
          ),
          child: const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 11),
        Text(
          'VYBE',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}

class _DesktopHero extends StatelessWidget {
  const _DesktopHero();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(flex: 11, child: _HeroCopy(isCompact: false)),
        SizedBox(width: 68),
        Expanded(flex: 9, child: ListeningRoomPreview()),
      ],
    );
  }
}

class _CompactHero extends StatelessWidget {
  const _CompactHero();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeroCopy(isCompact: true),
        SizedBox(height: 48),
        ListeningRoomPreview(),
      ],
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({required this.isCompact});

  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final titleStyle = isCompact
        ? Theme.of(context).textTheme.displayMedium
        : Theme.of(context).textTheme.displayLarge;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.055),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  'YOUR OWN LITTLE LISTENING ROOM',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        Text(
          'Same song.\nSame moment.',
          style: titleStyle?.copyWith(height: 1.06),
        ),
        const SizedBox(height: 22),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 470),
          child: Text(
            'Connect with someone and listen together, in perfect sync.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 18),
          ),
        ),
        const SizedBox(height: 34),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            VYBEButton(
              label: 'Create a room',
              icon: Icons.add_rounded,
              onPressed: () => context.go('/login'),
            ),
            VYBEButton(
              label: 'Join a room',
              icon: Icons.arrow_forward_rounded,
              variant: VYBEButtonVariant.secondary,
              onPressed: () => context.go('/login'),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            const Icon(Icons.lock_outline_rounded, size: 15, color: AppColors.muted),
            Text(
              'Just the two of you. No noise, no pressure.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FooterNote extends StatelessWidget {
  const _FooterNote();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        Icon(Icons.favorite_rounded, size: 14, color: AppColors.accent.withValues(alpha: 0.8)),
        Text(
          'Made for the songs you want to share.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted),
        ),
      ],
    );
  }
}