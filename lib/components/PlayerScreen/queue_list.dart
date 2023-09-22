import 'package:audio_service/audio_service.dart';
import 'package:finamp/components/AlbumScreen/song_list_tile.dart';
import 'package:finamp/components/error_snackbar.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/screens/add_to_playlist_screen.dart';
import 'package:finamp/screens/album_screen.dart';
import 'package:finamp/screens/blurred_player_screen_background.dart';
import 'package:finamp/services/audio_service_helper.dart';
import 'package:finamp/services/downloads_helper.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:finamp/services/player_screen_theme_provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';
import 'package:rxdart/rxdart.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';

import '../album_image.dart';
import '../../models/jellyfin_models.dart' as jellyfin_models;
import '../../services/process_artist.dart';
import '../../services/media_state_stream.dart';
import '../../services/music_player_background_task.dart';
import '../../services/queue_service.dart';
import 'queue_list_item.dart';

class _QueueListStreamState {
  _QueueListStreamState(
    this.mediaState,
    this.playbackPosition,
    this.queueInfo,
  );

  final MediaState mediaState;
  final Duration playbackPosition;
  final QueueInfo queueInfo;
}

class QueueList extends StatefulWidget {
  const QueueList({
    Key? key,
    required this.scrollController,
    required this.previousTracksHeaderKey,
    required this.currentTrackKey,
    required this.nextUpHeaderKey,
  })
      : super(key: key);

  final ScrollController scrollController;
  final GlobalKey previousTracksHeaderKey;
  final Key currentTrackKey;
  final GlobalKey nextUpHeaderKey;

  @override
  State<QueueList> createState() => _QueueListState();

  void scrollDown() {
    scrollController.animateTo(
      scrollController.position.maxScrollExtent,
      duration: Duration(seconds: 2),
      curve: Curves.fastOutSlowIn,
    );
  }
}

void scrollToKey({
  required GlobalKey key,
  Duration? duration,
}) {
  if (duration == null) {
    Scrollable.ensureVisible(
      key.currentContext!,
    );
  } else {
    Scrollable.ensureVisible(
      key.currentContext!,
      duration: duration,
      curve: Curves.easeOut,
    );
  }
}

class _QueueListState extends State<QueueList> {
  final _queueService = GetIt.instance<QueueService>();

  QueueItemSource? _source;

  late List<Widget> _contents;
  bool isRecentTracksExpanded = false;

  @override
  void initState() {
    super.initState();

    _queueService.getQueueStream().listen((queueInfo) {
      _source = queueInfo.source;
    });

    _source = _queueService.getQueue().source;

    _contents = <Widget>[
      // const SliverPadding(padding: EdgeInsets.only(top: 0)),
      // Previous Tracks
      SliverList.list(
        children: const [],
      ),
      // Current Track
      SliverAppBar(
          key: UniqueKey(),
          pinned: true,
          collapsedHeight: 70.0,
          expandedHeight: 70.0,
          leading: const Padding(
            padding: EdgeInsets.zero,
          ),
          flexibleSpace: ListTile(
              leading: const AlbumImage(
                item: null,
              ),
              title: const Text("unknown"),
              subtitle: const Text("unknown"),
              onTap: () {}),
          
      ),
      SliverPersistentHeader(
          delegate: SectionHeaderDelegate(
        title: const Text("Queue"),
        nextUpHeaderKey: widget.nextUpHeaderKey,
      )),
      // Queue
      SliverList.list(
        key: widget.nextUpHeaderKey,
        children: const [],
      ),
    ];

  }

  void scrollToCurrentTrack() {
    // dynamic box = currentTrackKey.currentContext!.findRenderObject();
    // Offset position = box; //this is global position
    // double y = position.dy;

    // widget.scrollController.animateTo(
    //   y,
    //   // scrollController.position.maxScrollExtent,
    //   duration: Duration(seconds: 2),
    //   curve: Curves.fastOutSlowIn,
    // );
    if (widget.previousTracksHeaderKey.currentContext != null) {
      Scrollable.ensureVisible(
        widget.previousTracksHeaderKey.currentContext!,
        // duration: const Duration(milliseconds: 200),
        // curve: Curves.decelerate,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    _contents = <Widget>[
      // Previous Tracks
      if (isRecentTracksExpanded)
        PreviousTracksList(previousTracksHeaderKey: widget.previousTracksHeaderKey)
      ,
      //TODO replace this with a SliverPersistentHeader and add an `onTap` callback to the delegate
      SliverToBoxAdapter(
        key: widget.previousTracksHeaderKey,
        child: GestureDetector(
          onTap:() {
            Vibrate.feedback(FeedbackType.selection);
            setState(() => isRecentTracksExpanded = !isRecentTracksExpanded);
            if (!isRecentTracksExpanded) {
              Future.delayed(const Duration(milliseconds: 200), () => scrollToCurrentTrack());
            }
            // else {
            //   Future.delayed(const Duration(milliseconds: 300), () => scrollToCurrentTrack());
            // }
          },
          child: Padding(
            padding: const EdgeInsets.only(left: 14.0, right: 14.0, bottom: 12.0, top: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Text(AppLocalizations.of(context)!.recentlyPlayed),
                ),
                const SizedBox(width: 4.0),
                Icon(
                  isRecentTracksExpanded ? TablerIcons.chevron_up : TablerIcons.chevron_down,
                  size: 28.0,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        )
      ),
      CurrentTrack(
        // key: UniqueKey(),
        key: widget.currentTrackKey,
      ),
      // next up
      StreamBuilder(
        key: widget.nextUpHeaderKey,
        stream: _queueService.getQueueStream(),
        builder: (context, snapshot) {
          if (snapshot.data != null && snapshot.data!.nextUp.isNotEmpty) {
            return SliverPadding(
              // key: widget.nextUpHeaderKey,
              padding: const EdgeInsets.only(top: 20.0, bottom: 0.0),
              sliver: SliverPersistentHeader(
                pinned: false, //TODO use https://stackoverflow.com/a/69372976 to only ever have one of the headers pinned
                delegate: SectionHeaderDelegate(
                  title: Text(AppLocalizations.of(context)!.nextUp),
                  height: 30.0,
                  nextUpHeaderKey: widget.nextUpHeaderKey,
                ), // _source != null ? "Playing from ${_source?.name}" : "Queue",
              ),
            );
          } else {
            return const SliverToBoxAdapter();
          }
        },
      ),
      NextUpTracksList(previousTracksHeaderKey: widget.previousTracksHeaderKey),
      SliverPadding(
        padding: const EdgeInsets.only(top: 20.0, bottom: 0.0),
        sliver: SliverPersistentHeader(
          pinned: true,
          delegate: SectionHeaderDelegate(
            title: Row(
              children: [
                Text("${AppLocalizations.of(context)!.playingFrom} "),
                Text(_source?.name.getLocalized(context) ?? AppLocalizations.of(context)!.unknownName,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
            // _source != null ? "Playing from ${_source?.name}" : "Queue",
            controls: true,
            nextUpHeaderKey: widget.nextUpHeaderKey,
          ),
        ),
      ),
      // Queue
      QueueTracksList(previousTracksHeaderKey: widget.previousTracksHeaderKey),
    ];

    return CustomScrollView(
      controller: widget.scrollController,
      slivers: _contents,
    );
  }
}

Future<dynamic> showQueueBottomSheet(BuildContext context) {
  GlobalKey previousTracksHeaderKey = GlobalKey();
  Key currentTrackKey = UniqueKey();
  GlobalKey nextUpHeaderKey = GlobalKey();

  Vibrate.feedback(FeedbackType.impact);

  return showModalBottomSheet(
    // showDragHandle: true,
    useSafeArea: true,
    enableDrag: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
    ),
    clipBehavior: Clip.antiAlias,
    context: context,
    builder: (context) {
      return Consumer(
        builder: (BuildContext context, WidgetRef ref, Widget? child) {

          final imageTheme = ref.watch(playerScreenThemeProvider);

          return Theme(
            data: ThemeData(
              fontFamily: "LexendDeca",
              colorScheme: imageTheme,
              brightness: Theme.of(context).brightness,
              iconTheme: Theme.of(context).iconTheme.copyWith(
                color: imageTheme?.primary,
              ),
            ),
            child: DraggableScrollableSheet(
              snap: false,
              snapAnimationDuration: const Duration(milliseconds: 200),
              initialChildSize: 0.92,
              // maxChildSize: 0.92,
              expand: false,
              builder: (context, scrollController) {
                return Scaffold(
                  body: Stack(
                    children: [
                      if (FinampSettingsHelper
                        .finampSettings.showCoverAsPlayerBackground)
                        BlurredPlayerScreenBackground(brightnessFactor: Theme.of(context).brightness == Brightness.dark ? 1.0 : 1.0),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 10),
                          Container(
                            width: 40,
                            height: 3.5,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(3.5),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(AppLocalizations.of(context)!.queue,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Lexend Deca',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w300)),
                          const SizedBox(height: 20),
                          Expanded(
                            child: QueueList(
                              scrollController: scrollController,
                              previousTracksHeaderKey: previousTracksHeaderKey,
                              currentTrackKey: currentTrackKey,
                              nextUpHeaderKey: nextUpHeaderKey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  //TODO fade this out if the key is visible
                  floatingActionButton: FloatingActionButton(
                      onPressed: () {
                        Vibrate.feedback(FeedbackType.impact);
                        scrollToKey(
                          key: previousTracksHeaderKey,
                          duration: const Duration(milliseconds: 500));
                      },
                      backgroundColor: IconTheme.of(context).color!.withOpacity(0.70),
                      shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(16.0))),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Icon(
                          TablerIcons.focus_2,
                          size: 28.0,
                          color: Colors.white.withOpacity(0.85),
                        ),
                      )),
                );
                // )
                // return QueueList(
                //   scrollController: scrollController,
                // );
              },
            ),
          );
        } 
      );
    },
  );
}

class PreviousTracksList extends StatefulWidget {

  final GlobalKey previousTracksHeaderKey;
  
  const PreviousTracksList({
    Key? key,
    required this.previousTracksHeaderKey,
  }) : super(key: key);

  @override
  State<PreviousTracksList> createState() => _PreviousTracksListState();
}

class _PreviousTracksListState extends State<PreviousTracksList>
    with TickerProviderStateMixin {
  final _queueService = GetIt.instance<QueueService>();
  List<QueueItem>? _previousTracks;

  @override
  Widget build(context) {
    return StreamBuilder<QueueInfo>(
      // stream: AudioService.queueStream,
      // stream: Rx.combineLatest2<MediaState, QueueInfo, _QueueListStreamState>(
      //     mediaStateStream,
      //     _queueService.getQueueStream(),
      //     (a, b) => _QueueListStreamState(a, b)),
      stream: _queueService.getQueueStream(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _previousTracks ??= snapshot.data!.previousTracks;

          return SliverReorderableList(
            onReorder: (oldIndex, newIndex) {
              int draggingOffset = -(_previousTracks!.length - oldIndex);
              int newPositionOffset = -(_previousTracks!.length - newIndex);
              print("$draggingOffset -> $newPositionOffset");
              if (mounted) {
                Vibrate.feedback(FeedbackType.impact);
                setState(() {
                  // temporarily update internal queue
                  QueueItem tmp = _previousTracks!.removeAt(oldIndex);
                  _previousTracks!.insert(
                      newIndex < oldIndex ? newIndex : newIndex - 1, tmp);
                  // update external queue to commit changes, results in a rebuild
                  _queueService.reorderByOffset(
                      draggingOffset, newPositionOffset);
                });
              }
            },
            onReorderStart: (p0) {
              // Feedback.forLongPress(context);
              Vibrate.feedback(FeedbackType.selection);
            },
            itemCount: _previousTracks?.length ?? 0,
            itemBuilder: (context, index) {
              final item = _previousTracks![index];
              final actualIndex = index;
              final indexOffset = -((_previousTracks?.length ?? 0) - index);
              return QueueListItem(
                key: ValueKey(_previousTracks![actualIndex].id),
                item: item,
                listIndex: index,
                actualIndex: actualIndex,
                indexOffset: indexOffset,
                subqueue: _previousTracks!,
                allowReorder:
                    _queueService.playbackOrder == PlaybackOrder.linear,
                onTap: () async {
                  Vibrate.feedback(FeedbackType.selection);
                  await _queueService.skipByOffset(indexOffset);
                  scrollToKey(key: widget.previousTracksHeaderKey, duration: const Duration(milliseconds: 500));
                },
                isCurrentTrack: false,
                isPreviousTrack: true,
              );
            },
          );
        } else {
          return SliverList(delegate: SliverChildListDelegate([]));
        }
      },
    );
  }
}

class NextUpTracksList extends StatefulWidget {

  final GlobalKey previousTracksHeaderKey;
  
  const NextUpTracksList({
    Key? key,
    required this.previousTracksHeaderKey,
  }) : super(key: key);

  @override
  State<NextUpTracksList> createState() => _NextUpTracksListState();
}

class _NextUpTracksListState extends State<NextUpTracksList> {
  final _queueService = GetIt.instance<QueueService>();
  List<QueueItem>? _nextUp;

  @override
  Widget build(context) {
    return StreamBuilder<QueueInfo>(
      // stream: AudioService.queueStream,
      stream: _queueService.getQueueStream(),
      // stream: _queueService.getQueueStream(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _nextUp ??= snapshot.data!.nextUp;

          return SliverPadding(
              padding: const EdgeInsets.only(top: 0.0, left: 8.0, right: 8.0),
              sliver: SliverReorderableList(
                onReorder: (oldIndex, newIndex) {
                  int draggingOffset = oldIndex + 1;
                  int newPositionOffset = newIndex + 1;
                  print("$draggingOffset -> $newPositionOffset");
                  if (mounted) {
                    Vibrate.feedback(FeedbackType.impact);
                    setState(() {
                      // temporarily update internal queue
                      QueueItem tmp = _nextUp!.removeAt(oldIndex);
                      _nextUp!.insert(
                          newIndex < oldIndex ? newIndex : newIndex - 1, tmp);
                      // update external queue to commit changes, results in a rebuild
                      _queueService.reorderByOffset(
                          draggingOffset, newPositionOffset);
                    });
                  }
                },
                onReorderStart: (p0) {
                  Vibrate.feedback(FeedbackType.selection);
                },
                itemCount: _nextUp?.length ?? 0,
                itemBuilder: (context, index) {
                  final item = _nextUp![index];
                  final actualIndex = index;
                  final indexOffset = index + 1;
                  return QueueListItem(
                    key: ValueKey(_nextUp![actualIndex].id),
                    item: item,
                    listIndex: index,
                    actualIndex: actualIndex,
                    indexOffset: indexOffset,
                    subqueue: _nextUp!,
                    onTap: () async {
                      Vibrate.feedback(FeedbackType.selection);
                      await _queueService.skipByOffset(indexOffset);
                      scrollToKey(key: widget.previousTracksHeaderKey, duration: const Duration(milliseconds: 500));
                    },
                    isCurrentTrack: false,
                  );
                },
              ));
        } else {
          return SliverList(delegate: SliverChildListDelegate([]));
        }
      },
    );
  }
}

class QueueTracksList extends StatefulWidget {

  final GlobalKey previousTracksHeaderKey;
  
  const QueueTracksList({
    Key? key,
    required this.previousTracksHeaderKey,
  }) : super(key: key);

  @override
  State<QueueTracksList> createState() => _QueueTracksListState();
}

class _QueueTracksListState extends State<QueueTracksList> {
  final _queueService = GetIt.instance<QueueService>();
  List<QueueItem>? _queue;
  List<QueueItem>? _nextUp;

  @override
  Widget build(context) {
    return StreamBuilder<QueueInfo>(
      // stream: AudioService.queueStream,
      stream: _queueService.getQueueStream(),
      // stream: _queueService.getQueueStream(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _queue ??= snapshot.data!.queue;
          _nextUp ??= snapshot.data!.nextUp;

          return SliverReorderableList(
            onReorder: (oldIndex, newIndex) {
              int draggingOffset = oldIndex + (_nextUp?.length ?? 0) + 1;
              int newPositionOffset = newIndex + (_nextUp?.length ?? 0) + 1;
              print("$draggingOffset -> $newPositionOffset");
              if (mounted) {
                Vibrate.feedback(FeedbackType.impact);
                setState(() {
                  // temporarily update internal queue
                  QueueItem tmp = _queue!.removeAt(oldIndex);
                  _queue!.insert(
                      newIndex < oldIndex ? newIndex : newIndex - 1, tmp);
                  // update external queue to commit changes, results in a rebuild
                  _queueService.reorderByOffset(
                      draggingOffset, newPositionOffset);
                });
              }
            },
            onReorderStart: (p0) {
              Vibrate.feedback(FeedbackType.selection);
            },
            itemCount: _queue?.length ?? 0,
            itemBuilder: (context, index) {
              final item = _queue![index];
              final actualIndex = index;
              final indexOffset = index + _nextUp!.length + 1;
              return QueueListItem(
                key: ValueKey(_queue![actualIndex].id),
                item: item,
                listIndex: index,
                actualIndex: actualIndex,
                indexOffset: indexOffset,
                subqueue: _queue!,
                allowReorder:
                    _queueService.playbackOrder == PlaybackOrder.linear,
                onTap: () async {
                  Vibrate.feedback(FeedbackType.selection);
                  await _queueService.skipByOffset(indexOffset);
                  scrollToKey(key: widget.previousTracksHeaderKey, duration: const Duration(milliseconds: 500));
                },
                isCurrentTrack: false,
              );
            },
          );
        } else {
          return SliverList(delegate: SliverChildListDelegate([]));
        }
      },
    );
  }
}

class CurrentTrack extends StatefulWidget {
  const CurrentTrack({
    Key? key,
  }) : super(key: key);

  @override
  State<CurrentTrack> createState() => _CurrentTrackState();
}

class _CurrentTrackState extends State<CurrentTrack> {
  late QueueService _queueService;
  late MusicPlayerBackgroundTask _audioHandler;
  late AudioServiceHelper _audioServiceHelper;
  late JellyfinApiHelper _jellyfinApiHelper;

  @override
  void initState() {
    super.initState();
    _queueService = GetIt.instance<QueueService>();
    _audioHandler = GetIt.instance<MusicPlayerBackgroundTask>();
    _audioServiceHelper = GetIt.instance<AudioServiceHelper>();
    _jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
  }

  @override
  Widget build(context) {
    QueueItem? currentTrack;
    MediaState? mediaState;
    Duration? playbackPosition;

    return StreamBuilder<_QueueListStreamState>(
      stream: Rx.combineLatest3<MediaState, Duration, QueueInfo,
              _QueueListStreamState>(
          mediaStateStream,
          AudioService.position
              .startWith(_audioHandler.playbackState.value.position),
          _queueService.getQueueStream(),
          (a, b, c) => _QueueListStreamState(a, b, c)),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          currentTrack = snapshot.data!.queueInfo.currentTrack;
          mediaState = snapshot.data!.mediaState;
          playbackPosition = snapshot.data!.playbackPosition;

          return SliverAppBar(
            // key: currentTrackKey,
            pinned: true,
            collapsedHeight: 70.0,
            expandedHeight: 70.0,
            elevation: 10.0,
            leading: const Padding(
              padding: EdgeInsets.zero,
            ),
            backgroundColor: const Color.fromRGBO(0, 0, 0, 0.0),
            flexibleSpace: Container(
              // width: 58,
              height: 70.0,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: ShapeDecoration(
                  color: Color.alphaBlend(IconTheme.of(context).color!.withOpacity(0.35), Colors.black),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8.0)),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        AlbumImage(
                          item: currentTrack!.item.extras?["itemJson"] == null
                              ? null
                              : jellyfin_models.BaseItemDto.fromJson(
                                  currentTrack!.item.extras?["itemJson"]),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            bottomLeft: Radius.circular(8),
                          ),
                          itemsToPrecache: _queueService.getNextXTracksInQueue(3).map((e) {
                            final item = e.item.extras?["itemJson"] != null
                                ? jellyfin_models.BaseItemDto.fromJson(
                                    e.item.extras!["itemJson"] as Map<String, dynamic>)
                                : null;
                            return item!;
                          }).toList(),
                        ),
                        Container(
                            width: 70,
                            height: 70,
                            decoration: const ShapeDecoration(
                              shape: Border(),
                              color: Color.fromRGBO(0, 0, 0, 0.3),
                            ),
                            child: IconButton(
                              onPressed: () {
                                Vibrate.feedback(FeedbackType.success);
                                _audioHandler.togglePlayback();
                              },
                              icon: mediaState!.playbackState.playing
                                  ? const Icon(
                                      TablerIcons.player_pause,
                                      size: 32,
                                    )
                                  : const Icon(
                                      TablerIcons.player_play,
                                      size: 32,
                                    ),
                              color: Color.fromRGBO(255, 255, 255, 1.0),
                            )),
                      ],
                    ),
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned(
                            left: 0,
                            top: 0,
                            // child: RepaintBoundary(
                            child: Container(
                              width: 298 *
                                  (playbackPosition!.inMilliseconds /
                                      (mediaState?.mediaItem?.duration ??
                                              const Duration(seconds: 0))
                                          .inMilliseconds),
                              height: 70.0,
                              decoration: ShapeDecoration(
                                // color: Color.fromRGBO(188, 136, 86, 0.75),
                                color: IconTheme.of(context).color!.withOpacity(0.75),
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.only(
                                    topRight: Radius.circular(8),
                                    bottomRight: Radius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            // ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                height: 70,
                                width: 222,
                                padding:
                                    const EdgeInsets.only(left: 12, right: 4),
                                // child: Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      currentTrack?.item.title ?? AppLocalizations.of(context)!.unknownName,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontFamily: 'Lexend Deca',
                                          fontWeight: FontWeight.w500,
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          processArtist(
                                              currentTrack!.item.artist, context),
                                          style: TextStyle(
                                              color: Colors.white.withOpacity(0.85),
                                              fontSize: 13,
                                              fontFamily: 'Lexend Deca',
                                              fontWeight: FontWeight.w300,
                                              overflow: TextOverflow.ellipsis),
                                        ),
                                        Row(children: [
                                        Text(
                                        // '0:00',
                                        playbackPosition!.inHours >= 1.0
                                            ? "${playbackPosition?.inHours.toString()}:${((playbackPosition?.inMinutes ?? 0) % 60).toString().padLeft(2, '0')}:${((playbackPosition?.inSeconds ?? 0) % 60).toString().padLeft(2, '0')}"
                                            : "${playbackPosition?.inMinutes.toString()}:${((playbackPosition?.inSeconds ?? 0) % 60).toString().padLeft(2, '0')}",
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.8),
                                          fontSize: 14,
                                          fontFamily: 'Lexend Deca',
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        '/',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.8),
                                          fontSize: 14,
                                          fontFamily: 'Lexend Deca',
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        // '3:44',
                                        (mediaState?.mediaItem?.duration
                                                        ?.inHours ??
                                                    0.0) >=
                                                1.0
                                            ? "${mediaState?.mediaItem?.duration?.inHours.toString()}:${((mediaState?.mediaItem?.duration?.inMinutes ?? 0) % 60).toString().padLeft(2, '0')}:${((mediaState?.mediaItem?.duration?.inSeconds ?? 0) % 60).toString().padLeft(2, '0')}"
                                            : "${mediaState?.mediaItem?.duration?.inMinutes.toString()}:${((mediaState?.mediaItem?.duration?.inSeconds ?? 0) % 60).toString().padLeft(2, '0')}",
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.8),
                                          fontSize: 14,
                                          fontFamily: 'Lexend Deca',
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                        ],)
                                      ],
                                    )
                                  ],
                                ),
                                // ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: IconButton(
                                      iconSize: 16,
                                      visualDensity: const VisualDensity(horizontal: -4),
                                      icon: jellyfin_models.BaseItemDto.fromJson(currentTrack!.item.extras?["itemJson"]).userData!.isFavorite ? Icon(
                                        Icons.favorite,
                                        size: 28,
                                        color: IconTheme.of(context).color!,
                                        fill: 1.0,
                                        weight:
                                            1.5,
                                      ) : const Icon(
                                        Icons.favorite_outline,
                                        size: 28,
                                        color: Colors.white,
                                        weight:
                                            1.5,
                                      ),
                                      onPressed: () {
                                        Vibrate.feedback(FeedbackType.success);
                                        setState(() {
                                          setFavourite(currentTrack!);
                                        });
                                      },
                                    ),
                                  ),
                                  IconButton(
                                    iconSize: 28,
                                    visualDensity: const VisualDensity(horizontal: -4),
                                    // visualDensity: VisualDensity.compact,
                                    icon: const Icon(
                                      TablerIcons.dots_vertical,
                                      size: 28,
                                      color: Colors.white,
                                      weight: 1.5,
                                    ),
                                    onPressed: () =>
                                        showSongMenu(currentTrack!),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        } else {
          return SliverList(delegate: SliverChildListDelegate([]));
        }
      },
    );
  }

  void showSongMenu(QueueItem currentTrack) async {
    final item = jellyfin_models.BaseItemDto.fromJson(
        currentTrack?.item.extras?["itemJson"]);

    final canGoToAlbum = _isAlbumDownloadedIfOffline(item.parentId);

    // Some options are disabled in offline mode
    final isOffline = FinampSettingsHelper.finampSettings.isOffline;

    final selection = await showMenu<SongListTileMenuItems>(
      context: context,
      position: RelativeRect.fromLTRB(MediaQuery.of(context).size.width - 50.0,
          MediaQuery.of(context).size.height - 50.0, 0.0, 0.0),
      items: [
        PopupMenuItem<SongListTileMenuItems>(
          value: SongListTileMenuItems.addToQueue,
          child: ListTile(
            leading: const Icon(Icons.queue_music),
            title: Text(AppLocalizations.of(context)!.addToQueue),
          ),
        ),
        PopupMenuItem<SongListTileMenuItems>(
          value: SongListTileMenuItems.playNext,
          child: ListTile(
            leading: const Icon(TablerIcons.hourglass_low),
            title: Text(AppLocalizations.of(context)!.playNext),
          ),
        ),
        PopupMenuItem<SongListTileMenuItems>(
          value: SongListTileMenuItems.addToNextUp,
          child: ListTile(
            leading: const Icon(TablerIcons.hourglass_high),
            title: Text(AppLocalizations.of(context)!.addToNextUp),
          ),
        ),
        PopupMenuItem<SongListTileMenuItems>(
          enabled: !isOffline,
          value: SongListTileMenuItems.addToPlaylist,
          child: ListTile(
            leading: const Icon(Icons.playlist_add),
            title: Text(AppLocalizations.of(context)!.addToPlaylistTitle),
            enabled: !isOffline,
          ),
        ),
        PopupMenuItem<SongListTileMenuItems>(
          enabled: !isOffline,
          value: SongListTileMenuItems.instantMix,
          child: ListTile(
            leading: const Icon(Icons.explore),
            title: Text(AppLocalizations.of(context)!.instantMix),
            enabled: !isOffline,
          ),
        ),
        PopupMenuItem<SongListTileMenuItems>(
          enabled: canGoToAlbum,
          value: SongListTileMenuItems.goToAlbum,
          child: ListTile(
            leading: const Icon(Icons.album),
            title: Text(AppLocalizations.of(context)!.goToAlbum),
            enabled: canGoToAlbum,
          ),
        ),
        item.userData!.isFavorite
            ? PopupMenuItem<SongListTileMenuItems>(
                value: SongListTileMenuItems.removeFavourite,
                child: ListTile(
                  leading: const Icon(Icons.favorite_border),
                  title: Text(AppLocalizations.of(context)!.removeFavourite),
                ),
              )
            : PopupMenuItem<SongListTileMenuItems>(
                value: SongListTileMenuItems.addFavourite,
                child: ListTile(
                  leading: const Icon(Icons.favorite),
                  title: Text(AppLocalizations.of(context)!.addFavourite),
                ),
              ),
      ],
    );

    if (!mounted) return;

    switch (selection) {
      case SongListTileMenuItems.addToQueue:
        await _queueService.addToQueue(
            item,
            QueueItemSource(
                type: QueueItemSourceType.unknown,
                name: QueueItemSourceName(type: QueueItemSourceNameType.preTranslated, pretranslatedName: AppLocalizations.of(context)!.queue),
                id: currentTrack.source.id));

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context)!.addedToQueue),
        ));
        break;

      case SongListTileMenuItems.playNext:
        await _queueService.addNext(items: [item]);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context)!.confirmPlayNext("track")),
        ));
        break;

      case SongListTileMenuItems.addToNextUp:
        await _queueService.addToNextUp(items: [item]);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context)!.confirmAddToNextUp("track")),
        ));
        break;

      case SongListTileMenuItems.addToPlaylist:
        Navigator.of(context)
            .pushNamed(AddToPlaylistScreen.routeName, arguments: item.id);
        break;

      case SongListTileMenuItems.instantMix:
        await _audioServiceHelper.startInstantMixForItem(item);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context)!.startingInstantMix),
        ));
        break;
      case SongListTileMenuItems.goToAlbum:
        late jellyfin_models.BaseItemDto album;
        if (FinampSettingsHelper.finampSettings.isOffline) {
          // If offline, load the album's BaseItemDto from DownloadHelper.
          final downloadsHelper = GetIt.instance<DownloadsHelper>();

          // downloadedParent won't be null here since the menu item already
          // checks if the DownloadedParent exists.
          album = downloadsHelper.getDownloadedParent(item.parentId!)!.item;
        } else {
          // If online, get the album's BaseItemDto from the server.
          try {
            album = await _jellyfinApiHelper.getItemById(item.parentId!);
          } catch (e) {
            errorSnackbar(e, context);
            break;
          }
        }

        if (!mounted) return;

        Navigator.of(context)
            .pushNamed(AlbumScreen.routeName, arguments: album);
        break;
      case SongListTileMenuItems.addFavourite:
      case SongListTileMenuItems.removeFavourite:
        await setFavourite(currentTrack);
        break;
      case null:
        break;
    }
  }

  Future<void> setFavourite(QueueItem track) async {
    try {
      // We switch the widget state before actually doing the request to
      // make the app feel faster (without, there is a delay from the
      // user adding the favourite and the icon showing)
      jellyfin_models.BaseItemDto item = jellyfin_models.BaseItemDto.fromJson(track.item.extras!["itemJson"]);
      
      setState(() {
        item.userData!.isFavorite = !item.userData!.isFavorite;
      });

      // Since we flipped the favourite state already, we can use the flipped
      // state to decide which API call to make
      final newUserData = item.userData!.isFavorite
          ? await _jellyfinApiHelper.addFavourite(item.id)
          : await _jellyfinApiHelper.removeFavourite(item.id);


      item.userData = newUserData;

      if (!mounted) return;
      setState(() {
        //!!! update the QueueItem with the new BaseItemDto, then trigger a rebuild of the widget with the current snapshot (**which includes the modified QueueItem**)
        track.item.extras!["itemJson"] = item.toJson();
      });

      _queueService.refreshQueueStream();

    } catch (e) {
      errorSnackbar(e, context);
    }
  }
}

class PlaybackBehaviorInfo {
  final PlaybackOrder order;
  final LoopMode loop;

  PlaybackBehaviorInfo(this.order, this.loop);
}

class SectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget title;
  final bool controls;
  final double height;
  final GlobalKey nextUpHeaderKey;

  SectionHeaderDelegate({
    required this.title,
    required this.nextUpHeaderKey,
    this.controls = false,
    this.height = 30.0,
  });

  @override
  Widget build(context, double shrinkOffset, bool overlapsContent) {
    final _queueService = GetIt.instance<QueueService>();

    return StreamBuilder(
      stream: Rx.combineLatest2(
          _queueService.getPlaybackOrderStream(),
          _queueService.getLoopModeStream(),
          (a, b) => PlaybackBehaviorInfo(a, b)),
      builder: (context, snapshot) {
        PlaybackBehaviorInfo? info = snapshot.data as PlaybackBehaviorInfo?;

        return Container(
          // color: Colors.black.withOpacity(0.5),
          padding: const EdgeInsets.symmetric(horizontal: 14.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                  child: Flex(
                      direction: Axis.horizontal,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                    title,
                  ])),
              if (controls)
                IconButton(
                    padding: const EdgeInsets.only(bottom: 2.0),
                    iconSize: 28.0,
                    icon: info?.order == PlaybackOrder.shuffled
                        ? (const Icon(
                            TablerIcons.arrows_shuffle,
                          ))
                        : (const Icon(
                            TablerIcons.arrows_right,
                          )),
                    color: info?.order == PlaybackOrder.shuffled
                        ? IconTheme.of(context).color!
                        : Colors.white,
                    onPressed: () {
                      _queueService.togglePlaybackOrder();
                      Vibrate.feedback(FeedbackType.success);
                      //TODO why is the current track scrolled out of view **after** the queue is updated?
                      Future.delayed(
                          const Duration(milliseconds: 300),
                          () => scrollToKey(
                              key: nextUpHeaderKey,
                              duration: const Duration(milliseconds: 500)));
                      // scrollToKey(key: nextUpHeaderKey, duration: const Duration(milliseconds: 1000));
                    }),
              if (controls)
                IconButton(
                  padding: const EdgeInsets.only(bottom: 2.0),
                  iconSize: 28.0,
                  icon: info?.loop != LoopMode.none
                      ? (info?.loop == LoopMode.one
                          ? (const Icon(
                              TablerIcons.repeat_once,
                            ))
                          : (const Icon(
                              TablerIcons.repeat,
                            )))
                      : (const Icon(
                          TablerIcons.repeat_off,
                        )),
                  color: info?.loop != LoopMode.none
                      ? IconTheme.of(context).color!
                      : Colors.white,
                  onPressed: () {
                    _queueService.toggleLoopMode();
                    Vibrate.feedback(FeedbackType.success);
                  }
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(SliverPersistentHeaderDelegate oldDelegate) => false;
}

/// If offline, check if an album is downloaded. Always returns true if online.
/// Returns false if albumId is null.
bool _isAlbumDownloadedIfOffline(String? albumId) {
  if (albumId == null) {
    return false;
  } else if (FinampSettingsHelper.finampSettings.isOffline) {
    final downloadsHelper = GetIt.instance<DownloadsHelper>();
    return downloadsHelper.isAlbumDownloaded(albumId);
  } else {
    return true;
  }
}
