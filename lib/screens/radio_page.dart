import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:musify/main.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/utilities/async_loader.dart';
import 'package:musify/widgets/spinner.dart';

class RadioPage extends StatefulWidget {
  const RadioPage({super.key});

  @override
  State<RadioPage> createState() => _RadioPageState();
}

class _RadioPageState extends State<RadioPage> {
  late Future<List<dynamic>> _radioFuture;

  @override
  void initState() {
    super.initState();
    _radioFuture = getPopularRadioStations();
  }

  Future<void> _refresh() async {
    setState(() {
      _radioFuture = getPopularRadioStations();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Radio',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(FluentIcons.arrow_clockwise_24_regular),
            onPressed: _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: AsyncLoader<List<dynamic>>(
          future: _radioFuture,
          loadingWidget: const Spinner(),
          builder: (context, data) {
            if (data.isEmpty) {
              return Center(
                child: Text(
                  'No radio stations available',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              );
            }

            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 18,
                childAspectRatio: 1.12,
              ),
              itemCount: data.length,
              itemBuilder: (context, index) {
                final item = data[index];
                final title = item['title']?.toString() ?? '';
                final subtitle = item['subtitle']?.toString() ?? 'Radio Station';
                final imageUrl = item['image']?.toString() ?? '';

                return GestureDetector(
                  onTap: () async {
                    final ytid = item['ytid']?.toString() ?? '';
                    if (ytid.isNotEmpty) {
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: ColoredBox(
                                color: colorScheme.surfaceContainerHighest,
                                child: imageUrl.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: imageUrl,
                                        fit: BoxFit.cover,
                                        memCacheWidth: 480,
                                        errorWidget: (_, __, ___) => Center(
                                          child: Icon(
                                            Icons.radio_rounded,
                                            size: 40,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: Icon(
                                          Icons.radio_rounded,
                                          size: 40,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                              ),
                            ),
                            Positioned(
                              right: 8,
                              bottom: 8,
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.75),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  FluentIcons.play_16_filled,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
