import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() async {
  final yt = YoutubeExplode();
  final search = await yt.search.search('Dabda Kithe Aa Full Video R Nait');
  final song = search.first;
  print('Song found: ${song.title} (${song.id})');
  final related = await yt.videos.getRelatedVideos(song);
  print('Found ${related?.length ?? 0} related videos.');
  if (related != null && related.isNotEmpty) {
    print('First related: ${related.first.title}');
  }
  yt.close();
}
