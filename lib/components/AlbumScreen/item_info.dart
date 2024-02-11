import 'package:flutter/material.dart';
import 'package:finamp/components/PlayerScreen/artist_chip.dart';
import 'package:finamp/components/artists_text_spans.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:get_it/get_it.dart';

import '../../models/jellyfin_models.dart';
import '../../screens/artist_screen.dart';
import '../../services/jellyfin_api_helper.dart';
import '../../services/process_artist.dart';
import '../icon_and_text.dart';
import '../print_duration.dart';

class ItemInfo extends StatelessWidget {
  const ItemInfo({
    super.key,
    required this.item,
    required this.itemSongs,
  });

  final BaseItemDto item;
  final int itemSongs;

// TODO: see if there's a way to expand this column to the row that it's in
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // if (item.type != "Playlist") IconAndText(
        //   iconData: Icons.person,
        //   textSpan: TextSpan(
        //     children: getArtistsTextSpans(
        //       item,
        //       null,
        //       context,
        //       false,
        //     ),
        //   ),
        // ),
        if (item.type != "Playlist") ArtistChips(
          baseItem: item,
          useAlbumArtist: true,
        ),
        IconAndText(
          iconData: Icons.music_note,
          textSpan: TextSpan(text: (itemSongs == (item.childCount ?? itemSongs))
              ? AppLocalizations.of(context)!.songCount(itemSongs)
              : AppLocalizations.of(context)!
                  .offlineSongCount(item.childCount!, itemSongs),
        )),
        IconAndText(
          iconData: Icons.timer,
          textSpan: TextSpan(text: printDuration(item.runTimeTicksDuration())),
        ),
        if (item.type != "Playlist")
          IconAndText(iconData: Icons.event, textSpan: TextSpan(text: item.productionYearString))
      ],
    );
  }
}

class _ArtistIconAndText extends StatelessWidget {
  const _ArtistIconAndText({Key? key, required this.album}) : super(key: key);

  final BaseItemDto album;

  @override
  Widget build(BuildContext context) {
    final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();

    return GestureDetector(
      onTap: () => jellyfinApiHelper
          .getItemById(album.albumArtists!.first.id)
          .then((artist) => Navigator.of(context)
              .pushNamed(ArtistScreen.routeName, arguments: artist)),
      child: IconAndText(
        iconData: Icons.person,
        textSpan: TextSpan(text: processArtist(album.albumArtist, context)),
      ),
    );
  }
}
