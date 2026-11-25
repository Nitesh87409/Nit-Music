import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:musify/constants/app_constants.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/screens/search_page.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/utilities/app_utils.dart';
import 'package:musify/utilities/async_loader.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/services/router_service.dart';
import 'package:musify/widgets/announcement_box.dart';
import 'package:musify/widgets/overflow_menu_button.dart';
import 'package:musify/widgets/mini_player_bottom_space.dart';
import 'package:musify/widgets/skeleton_loader.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:palette_generator/palette_generator.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final Future<List> _suggestedPlaylistsFuture;
  late Future<List> _recommendedSongsFuture;
  late final Future<List> _trendingSongsFuture;
  late final Future<List> _quickPicksFuture;
  late final Future<List> _popularAlbumsFuture;
  late final Future<List> _popularRadioFuture;
  late final Future<List> _popularArtistsFuture;
  late final Future<List> _commutePlaylistsFuture;
  StreamSubscription? _mediaItemSub;
  Color? _dynamicColor;
  final PageController _quickPicksPageController = PageController(viewportFraction: 0.90);
  final PageController _commutePageController = PageController(viewportFraction: 0.88);

  String? _selectedMood;
  Future<List>? _moodSongsFuture;
  Future<List>? _moodPlaylistsFuture;

  Color _getMoodColor(String? mood) {
    switch (mood) {
      case 'Romance':
        return const Color(0xFF5A1428); // Deep Rose/Wine
      case 'Feel good':
        return const Color(0xFF5C4312); // Golden Amber
      case 'Work out':
        return const Color(0xFF6E1B12); // Fiery Crimson
      case 'Relax':
        return const Color(0xFF0F3242); // Deep Ocean Teal
      case 'Energize':
        return const Color(0xFF451961); // Electric Violet
      case 'Podcasts':
        return const Color(0xFF332724); // Warm Slate
      default:
        return _dynamicColor ?? const Color(0xFF5A2A18); // Default YouTube Music warm ambient glow
    }
  }

  void _toggleMood(String mood) {
    setState(() {
      if (_selectedMood == mood) {
        _selectedMood = null;
        _moodSongsFuture = null;
        _moodPlaylistsFuture = null;
      } else {
        _selectedMood = mood;
        _moodSongsFuture = getMoodTracks(mood);
        _moodPlaylistsFuture = getMoodPlaylists(mood);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _suggestedPlaylistsFuture = getPlaylists(
      playlistsNum: recommendedCubesNumber,
    );
    _recommendedSongsFuture = getRecommendedSongs();
    _trendingSongsFuture = getTrendingSongs();
    _quickPicksFuture = getQuickPicks();
    _popularAlbumsFuture = getPopularAlbumsAndSingles();
    _popularRadioFuture = getPopularRadioStations();
    _popularArtistsFuture = getPopularArtistsList();
    _commutePlaylistsFuture = getMoodPlaylists('Commute');
    externalRecommendations.addListener(_refreshRecommendedSongs);
    searchHistoryNotifier.addListener(_refreshRecommendedSongs);
    _mediaItemSub = audioHandler.mediaItem.listen(_updatePalette);
  }

  @override
  void dispose() {
    externalRecommendations.removeListener(_refreshRecommendedSongs);
    searchHistoryNotifier.removeListener(_refreshRecommendedSongs);
    _mediaItemSub?.cancel();
    _quickPicksPageController.dispose();
    _commutePageController.dispose();
    super.dispose();
  }

  Future<void> _updatePalette(MediaItem? item) async {
    if (item?.artUri == null) {
      if (mounted) setState(() => _dynamicColor = null);
      return;
    }
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        ResizeImage(
          NetworkImage(item!.artUri!.toString()),
          width: 50,
          height: 50,
        ),
        maximumColorCount: 3,
        timeout: const Duration(seconds: 3),
      );
      if (mounted) {
        setState(() {
          _dynamicColor = palette.vibrantColor?.color ?? palette.dominantColor?.color;
        });
      }
    } catch (_) {}
  }

  void _refreshRecommendedSongs() {
    if (!mounted) return;
    setState(() {
      _recommendedSongsFuture = getRecommendedSongs();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final playlistHeight = MediaQuery.sizeOf(context).height * 0.25 / 1.1;
    final activeMoodColor = _getMoodColor(_selectedMood);
    final surfaceColor = theme.colorScheme.surface;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: surfaceColor,
        body: Stack(
          children: [
            // Top atmospheric ambient gradient glow
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 420,
              child: IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        activeMoodColor.withOpacity(0.65),
                        activeMoodColor.withOpacity(0.25),
                        surfaceColor.withOpacity(0.0),
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        _buildTopBar(context),
                        const SizedBox(height: 12),
                        _buildMoodChipsRow(),
                        const SizedBox(height: 16),
                        if (_selectedMood != null) ...[
                          _buildMoodFeedSection(playlistHeight),
                        ] else ...[
                          ValueListenableBuilder<String?>(
                            valueListenable: announcementURL,
                            builder: (_, _url, __) {
                              if (_url == null) return const SizedBox.shrink();
                              final isSponsorshipAnnouncement =
                                  isSponsorshipAnnouncementUrl(_url);
                              final _message = isSponsorshipAnnouncement
                                  ? context.l10n!.sponsorProject
                                  : context.l10n!.newAnnouncement;
                              final _icon = isSponsorshipAnnouncement
                                  ? FluentIcons.heart_24_filled
                                  : FluentIcons.megaphone_24_filled;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 24.0),
                                child: AnnouncementBox(
                                  message: _message,
                                  url: _url,
                                  icon: _icon,
                                  onDismiss: () async {
                                    announcementURL.value = null;
                                  },
                                ),
                              );
                            },
                          ),
                          _buildQuickPicksSection(),
                          const SizedBox(height: 24),
                          _buildCommuteSection(),
                          const SizedBox(height: 24),
                          _buildSpeedDialSection(),
                          const SizedBox(height: 24),
                          _buildSuggestedPlaylists(playlistHeight),
                          const SizedBox(height: 24),
                          _buildTrendingSection(),
                          const SizedBox(height: 24),
                          _buildPopularAlbumsSection(),
                          const SizedBox(height: 24),
                          _buildPopularRadioSection(),
                          const SizedBox(height: 24),
                          _buildPopularArtistsSection(),
                          const SizedBox(height: 24),
                          _buildRecommendedSongsSection(),
                        ],
                        const MiniPlayerBottomSpace(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildMoodChipsRow() {
    const moods = ['Podcasts', 'Romance', 'Feel good', 'Work out', 'Relax', 'Energize'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: moods.map((mood) {
          final isSelected = _selectedMood == mood;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: GestureDetector(
              onTap: () => _toggleMood(mood),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.white.withOpacity(0.12),
                    width: 1,
                  ),
                ),
                child: Text(
                  mood,
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMoodFeedSection(double playlistHeight) {
    final mood = _selectedMood ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$mood hits',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              tooltip: 'Clear mood',
              onPressed: () => _toggleMood(mood),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AsyncLoader<List<dynamic>>(
          future: _moodSongsFuture ?? Future.value([]),
          loadingWidget: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 5,
            padding: EdgeInsets.zero,
            itemBuilder: (context, index) => const SongBarSkeleton(),
          ),
          builder: (context, songs) {
            if (songs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Center(
                  child: Text(
                    'No songs found for $mood',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: songs.length,
              padding: EdgeInsets.zero,
              itemBuilder: (context, index) {
                return _buildRecommendedSongTile(songs[index], index, songs);
              },
            );
          },
        ),
        const SizedBox(height: 24),
        Text(
          '$mood playlists',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        AsyncLoader<List<dynamic>>(
          future: _moodPlaylistsFuture ?? Future.value([]),
          loadingWidget: SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 4,
              itemBuilder: (context, index) => const Padding(
                padding: EdgeInsets.only(right: 16),
                child: MixCardSkeleton(),
              ),
            ),
          ),
          builder: (context, playlists) {
            if (playlists.isEmpty) return const SizedBox.shrink();
            return SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: playlists.length,
                itemBuilder: (context, index) {
                  final playlist = playlists[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: GestureDetector(
                      onTap: () =>
                          context.push('/home/playlist/${playlist['ytid']}'),
                      child: _buildMixCard(playlist),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final titleColor = _dynamicColor ?? const Color(0xFFE11D48);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IconButton(
          icon: ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: Image.asset('assets/logo.png', width: 28, height: 28),
          ),
          onPressed: () {
            Scaffold.of(context).openDrawer();
          },
        ),
        const SizedBox(width: 4),
        Text(
          'Nit',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 26,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          'Music',
          style: TextStyle(
            color: titleColor,
            fontWeight: FontWeight.bold,
            fontSize: 26,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickPicksSection() {
    return AsyncLoader<List<dynamic>>(
      future: _quickPicksFuture,
      loadingWidget: _buildQuickPicksSkeleton(),
      builder: (context, data) {
        if (data.isEmpty) return const SizedBox.shrink();

        final pageCount = (data.length / 4).ceil();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Quick picks',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(FluentIcons.flash_24_filled, color: Colors.amber, size: 20),
                  ],
                ),
                Container(
                  height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: TextButton(
                    onPressed: () async {
                      await audioHandler.playPlaylistSong(
                        playlist: {'title': 'Quick Picks', 'list': data},
                        songIndex: 0,
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Play all',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 252,
              child: PageView.builder(
                controller: _quickPicksPageController,
                padEnds: false,
                itemCount: pageCount,
                itemBuilder: (context, pageIndex) {
                  final startIndex = pageIndex * 4;
                  final endIndex = (startIndex + 4 > data.length)
                      ? data.length
                      : startIndex + 4;
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = startIndex; i < endIndex; i++)
                          _buildRecommendedSongTile(data[i], i, data),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickPicksSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Quick picks',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 4,
          padding: EdgeInsets.zero,
          itemBuilder: (context, index) {
            return const SongBarSkeleton();
          },
        ),
      ],
    );
  }

  Widget _buildSpeedDialSection() {
    return ValueListenableBuilder<List>(
      valueListenable: userRecentlyPlayed,
      builder: (context, history, _) {
        final speedDialItems = getSpeedDial();
        if (speedDialItems.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Speed dial',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 99,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: speedDialItems.length,
                itemBuilder: (context, index) {
                  final item = speedDialItems[index];
                  final title = item['title']?.toString() ?? '';
                  final imageUrl = item['image']?.toString() ?? '';

                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTap: () async {
                        await audioHandler.playPlaylistSong(
                          playlist: {'title': 'Speed Dial', 'list': speedDialItems},
                          songIndex: index,
                        );
                      },
                      child: Container(
                        width: 176,
                        height: 99,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          image: imageUrl.isNotEmpty
                              ? DecorationImage(
                                  image: CachedNetworkImageProvider(imageUrl, maxWidth: 400, maxHeight: 225),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.8),
                                ],
                              ),
                            ),
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSuggestedPlaylists(double playlistHeight) {
    return AsyncLoader<List<dynamic>>(
      future: _suggestedPlaylistsFuture,
      loadingWidget: _buildSuggestedPlaylistsSkeleton(),
      builder: (context, playlists) =>
          _buildSuggestedPlaylistsSection(playlistHeight, playlists),
    );
  }

  Widget _buildSuggestedPlaylistsSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Your top mixes',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 172,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 4,
            itemBuilder: (context, index) {
              return const Padding(
                padding: EdgeInsets.only(right: 16),
                child: MixCardSkeleton(),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestedPlaylistsSection(
    double playlistHeight,
    List<dynamic> playlists,
  ) {
    if (playlists.isEmpty) return const SizedBox.shrink();
    final itemsNumber = playlists.length.clamp(0, recommendedCubesNumber);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Your top mixes',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton(
              onPressed: () {
                context.push(
                  '/home/generic_grid',
                  extra: {
                    'title': 'Your top mixes',
                    'items': playlists,
                  },
                );
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'See all',
                style: TextStyle(
                  color: Color(0xFFE11D48),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 172,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: itemsNumber,
            itemBuilder: (context, index) {
              final playlist = playlists[index];
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: GestureDetector(
                  onTap: () =>
                      context.push('/home/playlist/${playlist['ytid']}'),
                  child: _buildMixCard(playlist),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMixCard(dynamic playlist) {
    final imageUrl = playlist['image'].toString();
    final title = playlist['title'].toString();
    
    return SizedBox(
      width: 192,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 192,
            height: 108,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              image: DecorationImage(
                image: CachedNetworkImageProvider(imageUrl, maxWidth: 480, maxHeight: 270),
                fit: BoxFit.cover,
              ),
            ),
            child: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Colors.black87,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    FluentIcons.play_16_filled,
                    color: Theme.of(context).colorScheme.onSurface,
                    size: 16,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Mix',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingSection() {
    return AsyncLoader<List<dynamic>>(
      future: _trendingSongsFuture,
      loadingWidget: _buildTrendingSectionSkeleton(),
      builder: (context, data) {
        if (data.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Trending Now ',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text('🔥', style: TextStyle(fontSize: 20)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: data.length,
                itemBuilder: (context, index) {
                  final song = data[index];
                  final title = song['title']?.toString() ?? '';
                  final imageUrl = song['image']?.toString() ?? '';
                  return Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: GestureDetector(
                      onTap: () async {
                        await audioHandler.playPlaylistSong(
                          playlist: {'title': 'Trending Now', 'list': data},
                          songIndex: index,
                        );
                      },
                      child: SizedBox(
                        width: 220,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 220,
                              height: 124,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                image: imageUrl.isNotEmpty
                                    ? DecorationImage(
                                        image: CachedNetworkImageProvider(imageUrl, maxWidth: 480, maxHeight: 270),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: Align(
                                alignment: Alignment.bottomRight,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: const BoxDecoration(
                                      color: Colors.black87,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      FluentIcons.play_16_filled,
                                      color: Theme.of(context).colorScheme.onSurface,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              song['artist']?.toString() ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTrendingSectionSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'Trending Now ',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text('🔥', style: TextStyle(fontSize: 20)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 172,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 4,
            itemBuilder: (context, index) {
              return const Padding(
                padding: EdgeInsets.only(right: 16),
                child: MixCardSkeleton(),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPopularAlbumsSection() {
    return AsyncLoader<List<dynamic>>(
      future: _popularAlbumsFuture,
      loadingWidget: _buildPopularAlbumsSkeleton(),
      builder: (context, data) {
        if (data.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Popular albums and singles',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 172,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: data.length,
                itemBuilder: (context, index) {
                  final item = data[index];
                  final title = item['title']?.toString() ?? '';
                  final subtitle = item['subtitle']?.toString() ?? (item['artist']?.toString() ?? 'Album');
                  final imageUrl = item['image']?.toString() ?? '';
                  final isAlbum = item['isAlbum'] == true;

                  return Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: GestureDetector(
                      onTap: () async {
                        if (isAlbum) {
                          unawaited(context.push('/home/playlist/${item['ytid']}'));
                        } else {
                          await audioHandler.playPlaylistSong(
                            playlist: {'title': 'Popular albums and singles', 'list': data},
                            songIndex: index,
                          );
                        }
                      },
                      child: SizedBox(
                        width: 192,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 192,
                              height: 108,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                image: imageUrl.isNotEmpty
                                    ? DecorationImage(
                                        image: CachedNetworkImageProvider(imageUrl, maxWidth: 480, maxHeight: 270),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: Align(
                                alignment: Alignment.bottomRight,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: const BoxDecoration(
                                      color: Colors.black87,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      FluentIcons.play_16_filled,
                                      color: Theme.of(context).colorScheme.onSurface,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPopularAlbumsSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Popular albums and singles',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 172,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 4,
            itemBuilder: (context, index) {
              return const Padding(
                padding: EdgeInsets.only(right: 16),
                child: MixCardSkeleton(),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPopularRadioSection() {
    return AsyncLoader<List<dynamic>>(
      future: _popularRadioFuture,
      loadingWidget: _buildPopularRadioSkeleton(),
      builder: (context, data) {
        if (data.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Popular radio',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: data.length,
                itemBuilder: (context, index) {
                  final item = data[index];
                  final title = item['title']?.toString() ?? '';
                  final subtitle = item['subtitle']?.toString() ?? '';
                  final imageUrl = item['image']?.toString() ?? '';

                  return Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: GestureDetector(
                      onTap: () async {
                        final ytid = item['ytid']?.toString() ?? '';
                        if (item['isRadio'] == true && ytid.isNotEmpty) {
                          if (ytid.startsWith('PL') || ytid.startsWith('RD') || ytid.length > 15) {
                            unawaited(context.push('/home/playlist/$ytid'));
                          } else {
                            await audioHandler.playPlaylistSong(
                              playlist: {'title': title, 'list': data},
                              songIndex: index,
                            );
                          }
                        }
                      },
                      child: SizedBox(
                        width: 200,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Stack(
                              children: [
                                Container(
                                  width: 200,
                                  height: 112,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    image: imageUrl.isNotEmpty
                                        ? DecorationImage(
                                            image: CachedNetworkImageProvider(imageUrl, maxWidth: 480, maxHeight: 270),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: Align(
                                    alignment: Alignment.bottomRight,
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Container(
                                        width: 32,
                                        height: 32,
                                        decoration: const BoxDecoration(
                                          color: Colors.black87,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          FluentIcons.play_16_filled,
                                          color: Theme.of(context).colorScheme.onSurface,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 10,
                                  right: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.65),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'RADIO',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle.isNotEmpty ? subtitle : 'Radio station',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPopularRadioSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Popular radio',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 4,
            itemBuilder: (context, index) {
              return const Padding(
                padding: EdgeInsets.only(right: 16),
                child: MixCardSkeleton(),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPopularArtistsSection() {
    return AsyncLoader<List<dynamic>>(
      future: _popularArtistsFuture,
      loadingWidget: _buildPopularArtistsSkeleton(),
      builder: (context, data) {
        if (data.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Popular artists',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 175,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: data.length,
                itemBuilder: (context, index) {
                  final item = data[index];
                  final name = item['title']?.toString() ?? '';
                  final imageUrl = item['image']?.toString() ?? '';

                  return Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: GestureDetector(
                      onTap: () {
                        if (name.isNotEmpty) {
                          unawaited(
                            context.push(
                              '/home/artist/${Uri.encodeComponent(name)}',
                              extra: {
                                'title': name,
                                'ytid': item['ytid'] ?? name,
                                'image': imageUrl,
                                'isArtist': true,
                                'isVerifiedArtist': true,
                              },
                            ),
                          );
                        }
                      },
                      child: SizedBox(
                        width: 110,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                image: imageUrl.isNotEmpty
                                    ? DecorationImage(
                                        image: CachedNetworkImageProvider(imageUrl, maxWidth: 300, maxHeight: 300),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: imageUrl.isEmpty
                                  ? Icon(
                                      FluentIcons.person_24_filled,
                                      size: 44,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Artist',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPopularArtistsSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Popular artists',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 175,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 4,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 110,
                  child: Column(
                    children: [
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: 70,
                        height: 12,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendedSongsSection() {
    return AsyncLoader<List<dynamic>>(
      future: _recommendedSongsFuture,
      loadingWidget: _buildRecommendedSongsSkeleton(),
      builder: (context, data) {
        if (data.isEmpty) return const SizedBox.shrink();
        return _buildRecommendedForYouSection(context, data);
      },
    );
  }

  Widget _buildRecommendedSongsSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recommended for you',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 4,
          padding: EdgeInsets.zero,
          itemBuilder: (context, index) {
            return const SongBarSkeleton();
          },
        ),
      ],
    );
  }

  Widget _buildRecommendedForYouSection(
    BuildContext context,
    List<dynamic> data,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recommended for you',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton(
              onPressed: () {
                context.push(
                  '/home/playlist_data',
                  extra: {
                    'title': 'Recommended for you',
                    'list': data,
                  },
                );
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'See all',
                style: TextStyle(
                  color: Color(0xFFE11D48),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: data.length,
          padding: EdgeInsets.zero,
          itemBuilder: (context, index) {
            return _buildRecommendedSongTile(data[index], index, data);
          },
        ),
      ],
    );
  }

  Widget _buildRecommendedSongTile(dynamic song, int index, List<dynamic> data) {
    final title = song['title'].toString();
    final artist = song['artist']?.toString() ?? 'Unknown Artist';
    final imageUrl = song['image']?.toString() ?? '';

    return InkWell(
      onTap: () async {
        await audioHandler.playPlaylistSong(
          playlist: {'title': 'Recommended for you', 'list': data},
          songIndex: index,
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 45,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                image: DecorationImage(
                  image: CachedNetworkImageProvider(imageUrl, maxWidth: 240, maxHeight: 135),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            OverflowMenuButton<String>(
              onSelected: (value) async {
                switch (value) {
                  case 'play_next':
                    await audioHandler.playNext(song);
                    if (context.mounted) showToast(context, context.l10n!.songAdded);
                    break;
                  case 'add_to_queue':
                    await audioHandler.addToQueue(song);
                    if (context.mounted) showToast(context, context.l10n!.songAdded);
                    break;
                  case 'go_to_artist':
                    final artistName = song['artist']?.toString().trim() ?? '';
                    if (artistName.isNotEmpty && context.mounted) {
                      context.push(
                        '${NavigationManager.searchPath}/artist/${Uri.encodeComponent(artistName)}',
                        extra: {'title': artistName, 'ytid': artistName},
                      );
                    }
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'play_next',
                  child: Row(
                    children: [
                      Icon(FluentIcons.receipt_play_24_regular, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(context.l10n!.playNext, style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'add_to_queue',
                  child: Row(
                    children: [
                      Icon(FluentIcons.text_bullet_list_add_24_regular, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(context.l10n!.addToQueue, style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
                    ],
                  ),
                ),
                if ((song['artist']?.toString().trim() ?? '').isNotEmpty)
                  PopupMenuItem(
                    value: 'go_to_artist',
                    child: Row(
                      children: [
                        Icon(FluentIcons.person_24_regular, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(context.l10n!.goToArtist, style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommuteSection() {
    return AsyncLoader<List<dynamic>>(
      future: _commutePlaylistsFuture,
      loadingWidget: const SizedBox.shrink(),
      builder: (context, playlists) {
        if (playlists.isEmpty) return const SizedBox.shrink();
        final items = playlists.take(8).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Commute',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    context.push(
                      '/home/generic_grid',
                      extra: {
                        'title': 'Commute',
                        'items': playlists,
                      },
                    );
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    FluentIcons.chevron_right_24_regular,
                    color: Theme.of(context).colorScheme.onSurface,
                    size: 22,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 428,
              child: PageView.builder(
                controller: _commutePageController,
                padEnds: false,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _CommuteMixCard(playlist: items[index]),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CommuteMixCard extends StatefulWidget {
  const _CommuteMixCard({required this.playlist});

  final dynamic playlist;

  @override
  State<_CommuteMixCard> createState() => _CommuteMixCardState();
}

class _CommuteMixCardState extends State<_CommuteMixCard> {
  late final Future<Map?> _detailsFuture;
  Color? _tintColor;

  @override
  void initState() {
    super.initState();
    final ytid = widget.playlist['ytid']?.toString() ?? '';
    _detailsFuture = ytid.isNotEmpty
        ? getPlaylistInfoForWidget(ytid)
        : Future.value(null);
    _extractTint();
  }

  Future<void> _extractTint() async {
    final imageUrl = widget.playlist['image']?.toString() ?? '';
    if (imageUrl.isEmpty) return;
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        ResizeImage(NetworkImage(imageUrl), width: 48, height: 48),
        maximumColorCount: 3,
        timeout: const Duration(seconds: 3),
      );
      final color = palette.dominantColor?.color ?? palette.vibrantColor?.color;
      if (mounted && color != null) {
        setState(() => _tintColor = color);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final ytid = widget.playlist['ytid']?.toString() ?? '';
    final title = widget.playlist['title']?.toString() ?? 'Mix';
    final imageUrl = widget.playlist['image']?.toString() ?? '';
    final fallbackCount = widget.playlist['songCount']?.toString() ?? '';

    final cardColor = _tintColor != null
        ? Color.alphaBlend(
            _tintColor!.withValues(alpha: isDark ? 0.24 : 0.14),
            colorScheme.surfaceContainerHigh,
          )
        : colorScheme.surfaceContainerHigh;

    return FutureBuilder<Map?>(
      future: _detailsFuture,
      builder: (context, snapshot) {
        final resolved = snapshot.data;
        final rawTracks = resolved?['list'];
        final tracks = rawTracks is List ? rawTracks : const <dynamic>[];
        final previewTracks = tracks.take(3).toList();
        final resolvedImage = resolved?['image']?.toString() ?? imageUrl;
        final countLabel = tracks.isNotEmpty
            ? '${tracks.length} songs'
            : fallbackCount.isNotEmpty
                ? '$fallbackCount songs'
                : 'Playlist';

        return Material(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: ytid.isNotEmpty
                ? () => context.push('/home/playlist/$ytid', extra: resolved)
                : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: resolvedImage.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: resolvedImage,
                              width: 150,
                              height: 150,
                              fit: BoxFit.cover,
                              memCacheWidth: 360,
                            )
                          : Container(
                              width: 150,
                              height: 150,
                              color: colorScheme.surfaceContainerHighest,
                              child: Icon(
                                FluentIcons.music_note_2_24_regular,
                                size: 42,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'YouTube Music • $countLabel',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Material(
                        color: colorScheme.onSurface.withValues(alpha: 0.14),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () async {
                            final playlistToPlay = resolved ?? await _detailsFuture;
                            if (playlistToPlay != null &&
                                playlistToPlay['list'] is List &&
                                (playlistToPlay['list'] as List).isNotEmpty) {
                              await audioHandler.playPlaylistSong(
                                playlist: Map<dynamic, dynamic>.from(
                                  playlistToPlay,
                                ),
                                songIndex: 0,
                              );
                            } else if (ytid.isNotEmpty && context.mounted) {
                              context.push('/home/playlist/$ytid');
                            }
                          },
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: Icon(
                              FluentIcons.play_24_filled,
                              size: 20,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      previewTracks.isEmpty)
                    for (var i = 0; i < 3; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    height: 12,
                                    width: 140,
                                    decoration: BoxDecoration(
                                      color: colorScheme.onSurface.withValues(
                                        alpha: 0.08,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    height: 10,
                                    width: 90,
                                    decoration: BoxDecoration(
                                      color: colorScheme.onSurface.withValues(
                                        alpha: 0.06,
                                      ),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                  else
                    for (var i = 0; i < previewTracks.length; i++)
                      _buildTrackRow(
                        context,
                        previewTracks[i],
                        i,
                        resolved,
                        colorScheme,
                      ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrackRow(
    BuildContext context,
    dynamic song,
    int index,
    Map? resolvedPlaylist,
    ColorScheme colorScheme,
  ) {
    final trackTitle = song['title']?.toString() ?? '';
    final trackArtist = song['artist']?.toString() ?? '';
    final trackThumb =
        song['highResImage']?.toString() ??
        song['image']?.toString() ??
        song['lowResImage']?.toString() ??
        '';

    return InkWell(
      onTap: resolvedPlaylist != null
          ? () => audioHandler.playPlaylistSong(
              playlist: Map<dynamic, dynamic>.from(resolvedPlaylist),
              songIndex: index,
            )
          : null,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: trackThumb.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: trackThumb,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      memCacheWidth: 132,
                    )
                  : Container(
                      width: 44,
                      height: 44,
                      color: colorScheme.surfaceContainerHighest,
                      child: Icon(
                        FluentIcons.music_note_1_24_regular,
                        size: 18,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    trackTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  if (trackArtist.isNotEmpty)
                    Text(
                      trackArtist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              FluentIcons.play_16_regular,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

