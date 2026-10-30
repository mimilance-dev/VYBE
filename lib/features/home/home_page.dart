import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/responsive_breakpoints.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_state_notifier.dart';
import '../../theme/app_colors.dart';
import '../../widgets/vybe_avatar.dart';
import '../auth/auth_widgets.dart';
import '../spotify/spotify_connect_card.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with TickerProviderStateMixin {
  late final AnimationController _ambientController;
  late final AnimationController _entranceController;
  late final CurvedAnimation _entrance;

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat(reverse: true);
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();
    _entrance = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _entrance.dispose();
    _ambientController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    if (authState.isLoading) return const AuthLoadingPage();

    final profile = authState.valueOrNull;
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= ResponsiveBreakpoints.desktop;
    final isMobile = width < ResponsiveBreakpoints.mobile;
    final name = _firstName(profile?.displayName);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _ambientController,
              builder: (context, _) {
                final t = _ambientController.value;
                return DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.lerp(
                        const Alignment(-0.88, -0.95),
                        const Alignment(0.9, -0.55),
                        t,
                      )!,
                      radius: 1.15,
                      colors: [
                        AppColors.primary.withValues(alpha: 0.19),
                        AppColors.background.withValues(alpha: 0.01),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _entrance,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.025),
                  end: Offset.zero,
                ).animate(_entrance),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isDesktop) _DesktopNavigation(onSignOut: _signOut),
                    Expanded(
                      child: _MainContent(
                        profile: profile,
                        firstName: name,
                        isMobile: isMobile,
                        isDesktop: isDesktop,
                        onCreateRoom: _showCreateRoom,
                        onJoinRoom: _showJoinRoom,
                        onShowProfile: () => _showProfile(profile, name),
                      ),
                    ),
                    if (isDesktop)
                      _ProfilePanel(
                        profile: profile,
                        name: name,
                        onSignOut: _signOut,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: isMobile
          ? _MobileNavigation(
              onCreateRoom: _showCreateRoom,
              onShowProfile: () => _showProfile(profile, name),
            )
          : null,
    );
  }

  void _signOut() => ref.read(authStateProvider.notifier).signOut();

  void _showCreateRoom() {
    try {
      context.go('/room/create');
    } catch (_) {
      showDialog<void>(
        context: context,
        builder: (context) => const _RoomInfoDialog(
          title: 'Create a listening room',
          message:
              'Room creation will be ready as soon as listening rooms are connected.',
          icon: Icons.add_rounded,
        ),
      );
    }
  }

  void _showJoinRoom() {
    showDialog<void>(
      context: context,
      builder: (context) => const _JoinRoomDialog(),
    );
  }

  void _showProfile(UserProfile? profile, String name) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.elevatedSurface,
        title: const Text('Your profile'),
        content: Row(
          children: [
            _ProfileAvatar(profile: profile, name: name, size: 44),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleMedium),
                  if (profile?.email case final email?)
                    Text(email, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _signOut();
            },
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

String _firstName(String? displayName) {
  final name = displayName?.trim();
  if (name == null || name.isEmpty) return 'there';
  return name.split(RegExp(r'\s+')).first;
}

class _MainContent extends StatelessWidget {
  const _MainContent({
    required this.profile,
    required this.firstName,
    required this.isMobile,
    required this.isDesktop,
    required this.onCreateRoom,
    required this.onJoinRoom,
    required this.onShowProfile,
  });

  final UserProfile? profile;
  final String firstName;
  final bool isMobile;
  final bool isDesktop;
  final VoidCallback onCreateRoom;
  final VoidCallback onJoinRoom;
  final VoidCallback onShowProfile;

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = isDesktop ? 48.0 : (isMobile ? 22.0 : 36.0);
    return Column(
      children: [
        if (!isDesktop)
          _TopBar(
            profile: profile,
            name: firstName,
            onShowProfile: onShowProfile,
          ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              isDesktop ? 62 : 34,
              horizontalPadding,
              48,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1050),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Greeting(name: firstName, isMobile: isMobile),
                    const SizedBox(height: 36),
                    _ActionCards(
                      isMobile: isMobile,
                      onCreateRoom: onCreateRoom,
                      onJoinRoom: onJoinRoom,
                    ),
                    const SizedBox(height: 28),
                    const SpotifyConnectCard(),
                    const SizedBox(height: 46),
                    _RecentSections(isMobile: isMobile),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DesktopNavigation extends StatelessWidget {
  const _DesktopNavigation({required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 218,
      padding: const EdgeInsets.fromLTRB(26, 30, 18, 24),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.white.withValues(alpha: 0.055)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Brand(),
          const SizedBox(height: 62),
          const _NavItem(
            icon: Icons.home_rounded,
            label: 'Home',
            selected: true,
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: onSignOut,
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Sign out'),
            style: TextButton.styleFrom(foregroundColor: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary.withValues(alpha: 0.16) : null,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon,
              size: 19,
              color: selected ? AppColors.secondary : AppColors.muted),
          const SizedBox(width: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: selected ? AppColors.textPrimary : AppColors.muted,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient:
                const LinearGradient(colors: AppColors.violetMagentaGradient),
          ),
          child: const Icon(Icons.graphic_eq_rounded,
              color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        Text(
          'VYBE',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.profile,
    required this.name,
    required this.onShowProfile,
  });

  final UserProfile? profile;
  final String name;
  final VoidCallback onShowProfile;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
      child: Row(
        children: [
          const _Brand(),
          const Spacer(),
          IconButton(
            tooltip: 'Your profile',
            onPressed: onShowProfile,
            icon: _ProfileAvatar(profile: profile, name: name, size: 36),
          ),
        ],
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name, required this.isMobile});

  final String name;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.displayMedium?.copyWith(
          fontSize: isMobile ? 35 : 48,
          height: 1.12,
          letterSpacing: -1.6,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: 9),
            Text(
              'YOUR LISTENING SPACE',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                    letterSpacing: 1.3,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 21),
        Text('Good afternoon, $name', style: titleStyle),
        const SizedBox(height: 9),
        Text(
          'Ready for a shared vibe?',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: isMobile ? 16 : 18,
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: 24),
        Text(
          'Who do you want to listen with?',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary.withValues(alpha: 0.82),
                fontWeight: FontWeight.w600,
                fontSize: isMobile ? 20 : 26,
                letterSpacing: -0.5,
              ),
        ),
      ],
    );
  }
}

class _ActionCards extends StatelessWidget {
  const _ActionCards({
    required this.isMobile,
    required this.onCreateRoom,
    required this.onJoinRoom,
  });

  final bool isMobile;
  final VoidCallback onCreateRoom;
  final VoidCallback onJoinRoom;

  @override
  Widget build(BuildContext context) {
    final createCard = _ActionCard(
      title: 'Create a listening room',
      description: 'Invite someone and start listening together.',
      action: 'CREATE A ROOM',
      icon: Icons.add_rounded,
      colors: AppColors.violetMagentaGradient,
      onTap: onCreateRoom,
      isCreate: true,
      compact: isMobile,
    );
    final joinCard = _ActionCard(
      title: 'Join a room',
      description: "Enter your friend's room code.",
      action: 'JOIN A ROOM',
      icon: Icons.arrow_forward_rounded,
      colors: const [Color(0xFF252052), Color(0xFF14112A)],
      onTap: onJoinRoom,
      isCreate: false,
      compact: isMobile,
    );

    if (isMobile) {
      return Column(
        children: [
          createCard,
          const SizedBox(height: 14),
          joinCard,
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: createCard),
        const SizedBox(width: 18),
        Expanded(child: joinCard),
      ],
    );
  }
}

class _ActionCard extends StatefulWidget {
  const _ActionCard({
    required this.title,
    required this.description,
    required this.action,
    required this.icon,
    required this.colors,
    required this.onTap,
    required this.isCreate,
    this.compact = false,
  });

  final String title;
  final String description;
  final String action;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;
  final bool isCreate;
  final bool compact;

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hovering ? -5 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            if (_hovering)
              BoxShadow(
                color: widget.colors.first.withValues(alpha: 0.25),
                blurRadius: 28,
                spreadRadius: 1,
              ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(24),
            child: Ink(
              height: widget.compact ? 130 : 242,
              padding: EdgeInsets.all(widget.compact ? 18 : 23),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: widget.isCreate
                      ? [
                          widget.colors.first.withValues(alpha: 0.36),
                          AppColors.elevatedSurface,
                        ]
                      : [
                          widget.colors.first.withValues(alpha: 0.54),
                          widget.colors.last,
                        ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color:
                      Colors.white.withValues(alpha: _hovering ? 0.15 : 0.08),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!widget.compact)
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.11),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child:
                              Icon(widget.icon, color: Colors.white, size: 23),
                        ),
                        const Spacer(),
                        if (widget.isCreate)
                          const _AlbumArtwork()
                        else
                          const _RoomCodeArtwork(),
                      ],
                    ),
                  const Spacer(),
                  Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if (!widget.compact) ...[
                    const SizedBox(height: 5),
                    Text(
                      widget.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                  SizedBox(height: widget.compact ? 12 : 17),
                  Row(
                    children: [
                      Text(
                        widget.action,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                      ),
                      const SizedBox(width: 9),
                      const Icon(Icons.arrow_forward_rounded,
                          color: Colors.white, size: 16),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AlbumArtwork extends StatelessWidget {
  const _AlbumArtwork();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: SizedBox(
        width: 52,
        height: 52,
        child: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFEB86C7),
                      Color(0xFF7956D8),
                      Color(0xFF18122E)
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: -14,
              top: -18,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                    width: 1.3,
                  ),
                ),
              ),
            ),
            const Center(
              child:
                  Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 23),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomCodeArtwork extends StatelessWidget {
  const _RoomCodeArtwork();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        'VYBE  ·  0000',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              fontSize: 9,
              letterSpacing: 1.1,
            ),
      ),
    );
  }
}

class _RecentSections extends StatelessWidget {
  const _RecentSections({required this.isMobile});

  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    const recentRooms = _EmptySection(
      title: 'Recent rooms',
      subtitle: 'Your listening rooms will live here.',
      icon: Icons.headphones_rounded,
    );
    const recentlyPlayed = _EmptySection(
      title: 'Recently played',
      subtitle: 'Your shared tracks will find a home here.',
      icon: Icons.album_rounded,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pick up where you left off',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 18),
        if (isMobile) ...[
          recentRooms,
          const SizedBox(height: 12),
          recentlyPlayed,
        ] else
          const Row(
            children: [
              Expanded(child: recentRooms),
              SizedBox(width: 16),
              Expanded(child: recentlyPlayed),
            ],
          ),
      ],
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 102,
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.025),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: Colors.white.withValues(alpha: 0.055)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 20, color: AppColors.secondary),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfilePanel extends StatelessWidget {
  const _ProfilePanel({
    required this.profile,
    required this.name,
    required this.onSignOut,
  });

  final UserProfile? profile;
  final String name;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 234,
      padding: const EdgeInsets.fromLTRB(18, 26, 24, 24),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: Colors.white.withValues(alpha: 0.055)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Sign out',
              onPressed: onSignOut,
              icon: const Icon(Icons.logout_rounded, size: 19),
              color: AppColors.muted,
            ),
          ),
          const Spacer(),
          Center(child: _ProfileAvatar(profile: profile, name: name, size: 58)),
          const SizedBox(height: 14),
          Center(
            child: Text(
              name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (profile?.email case final email?) ...[
            const SizedBox(height: 3),
            Center(
              child: Text(
                email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
              ),
            ),
          ],
          const SizedBox(height: 13),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                'HERE FOR THE MUSIC',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.success,
                      fontSize: 9,
                      letterSpacing: 0.7,
                    ),
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.profile,
    required this.name,
    required this.size,
  });

  final UserProfile? profile;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final photoUrl = profile?.photoUrl;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: AppColors.elevatedSurface,
        backgroundImage: NetworkImage(photoUrl),
      );
    }
    return VYBEAvatar(
      initials: name.isEmpty ? 'A' : name[0].toUpperCase(),
      label: name,
      color: AppColors.primary,
      size: size,
    );
  }
}

class _MobileNavigation extends StatelessWidget {
  const _MobileNavigation({
    required this.onCreateRoom,
    required this.onShowProfile,
  });

  final VoidCallback onCreateRoom;
  final VoidCallback onShowProfile;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.96),
        border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.07))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              const _BottomNavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                selected: true,
              ),
              _BottomNavItem(
                icon: Icons.add_circle_outline_rounded,
                label: 'Create',
                onTap: onCreateRoom,
              ),
              _BottomNavItem(
                icon: Icons.person_outline_rounded,
                label: 'Profile',
                onTap: onShowProfile,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 76,
        height: 58,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 21,
              color: selected ? AppColors.secondary : AppColors.muted,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    color: selected ? AppColors.textPrimary : AppColors.muted,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomInfoDialog extends StatelessWidget {
  const _RoomInfoDialog({
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.elevatedSurface,
      icon: Icon(icon, color: AppColors.secondary, size: 30),
      title: Text(title),
      content: Text(message, textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Got it'),
        ),
      ],
    );
  }
}

class _JoinRoomDialog extends StatefulWidget {
  const _JoinRoomDialog();

  @override
  State<_JoinRoomDialog> createState() => _JoinRoomDialogState();
}

String refContextCode(String code) =>
    code.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

class _JoinRoomDialogState extends State<_JoinRoomDialog> {
  final _codeController = TextEditingController();
  bool _showUnavailableMessage = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.elevatedSurface,
      icon: const Icon(Icons.headphones_rounded,
          color: AppColors.secondary, size: 30),
      title: const Text('Join a room'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("Enter your friend's room code to listen together."),
          const SizedBox(height: 20),
          TextField(
            controller: _codeController,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _tryJoin(),
            decoration: const InputDecoration(
              labelText: 'Room code',
              hintText: 'e.g. VYBE-1234',
            ),
          ),
          if (_showUnavailableMessage) ...[
            const SizedBox(height: 12),
            Text(
              'Joining rooms is not connected yet.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.accent,
                  ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _tryJoin,
          child: const Text('Join room'),
        ),
      ],
    );
  }

  void _tryJoin() {
    if (_codeController.text.trim().isEmpty) {
      setState(() => _showUnavailableMessage = false);
      return;
    }
    try {
      context.go(
          '/room/join?code=${Uri.encodeComponent(refContextCode(_codeController.text))}');
    } catch (_) {
      setState(() => _showUnavailableMessage = true);
    }
  }
}
