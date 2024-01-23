import 'package:finamp/components/AlbumScreen/song_list_tile.dart';
import 'package:finamp/components/AlbumScreen/song_menu.dart';
import 'package:finamp/components/album_image.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/screens/add_to_playlist_screen.dart';
import 'package:finamp/screens/album_screen.dart';
import 'package:finamp/services/audio_service_helper.dart';
import 'package:finamp/services/downloads_helper.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:finamp/services/process_artist.dart';
import 'package:flutter/material.dart' hide ReorderableList;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart' as jellyfin_models;
import 'package:finamp/services/queue_service.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:get_it/get_it.dart';

import '../../services/isar_downloads.dart';

class QueueListItem extends StatefulWidget {
  final FinampQueueItem item;
  final int listIndex;
  final int actualIndex;
  final int indexOffset;
  final List<FinampQueueItem> subqueue;
  final bool isCurrentTrack;
  final bool isPreviousTrack;
  final bool allowReorder;
  final void Function() onTap;

  const QueueListItem({
    Key? key,
    required this.item,
    required this.listIndex,
    required this.actualIndex,
    required this.indexOffset,
    required this.subqueue,
    required this.onTap,
    this.allowReorder = true,
    this.isCurrentTrack = false,
    this.isPreviousTrack = false,
  }) : super(key: key);
  @override
  State<QueueListItem> createState() => _QueueListItemState();
}

class _QueueListItemState extends State<QueueListItem>
    with AutomaticKeepAliveClientMixin {
  final _audioServiceHelper = GetIt.instance<AudioServiceHelper>();
  final _queueService = GetIt.instance<QueueService>();
  final _jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    jellyfin_models.BaseItemDto baseItem = jellyfin_models.BaseItemDto.fromJson(
        widget.item.item.extras?["itemJson"]);

    return Dismissible(
      key: Key(widget.item.id),
      onDismissed: (direction) async {
        Vibrate.feedback(FeedbackType.impact);
        await _queueService.removeAtOffset(widget.indexOffset);
        setState(() {});
      },
      child: GestureDetector(
          onLongPressStart: (details) => showModalSongMenu(
              context: context,
              item: baseItem,
          ),
          child: Opacity(
            opacity: widget.isPreviousTrack ? 0.8 : 1.0,
            child: Card(
                color: const Color.fromRGBO(255, 255, 255, 0.075),
                elevation: 0,
                margin:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 5.0),
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: ListTile(
                  visualDensity: VisualDensity.standard,
                  minVerticalPadding: 0.0,
                  horizontalTitleGap: 10.0,
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 0.0, horizontal: 0.0),
                  tileColor: widget.isCurrentTrack
                      ? Theme.of(context).colorScheme.secondary.withOpacity(0.1)
                      : null,
                  leading: AlbumImage(
                    item: widget.item.item.extras?["itemJson"] == null
                        ? null
                        : jellyfin_models.BaseItemDto.fromJson(
                            widget.item.item.extras?["itemJson"]),
                    borderRadius: BorderRadius.zero,
                  ),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(0.0),
                        child: Text(
                          widget.item.item.title,
                          style: widget.isCurrentTrack
                              ? TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.secondary,
                                  fontSize: 16,
                                  fontFamily: 'Lexend Deca',
                                  fontWeight: FontWeight.w400,
                                  overflow: TextOverflow.ellipsis)
                              : null,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Text(
                          processArtist(widget.item.item.artist, context),
                          style: TextStyle(
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium!
                                  .color!,
                              fontSize: 13,
                              fontFamily: 'Lexend Deca',
                              fontWeight: FontWeight.w300,
                              overflow: TextOverflow.ellipsis),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  trailing: Container(
                    alignment: Alignment.centerRight,
                    margin: const EdgeInsets.only(right: 8.0),
                    padding: const EdgeInsets.only(right: 6.0),
                    width: widget.allowReorder
                        ? 72.0
                        : 42.0, //TODO make this responsive
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          "${widget.item.item.duration?.inMinutes.toString()}:${((widget.item.item.duration?.inSeconds ?? 0) % 60).toString().padLeft(2, '0')}",
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                        if (widget.allowReorder)
                          ReorderableDragStartListener(
                            index: widget.listIndex,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 5.0, left: 6.0),
                              child: Icon(
                                TablerIcons.grip_horizontal,
                                color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
                                size: 28.0,
                                weight: 1.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  onTap: widget.onTap,
                )),
          )),
    );
  }
}
