import 'dart:async';
import 'package:better_player/src/configuration/better_player_controls_configuration.dart';
import 'package:better_player/src/controls/better_player_clickable_widget.dart';
import 'package:better_player/src/controls/better_player_controls_state.dart';
import 'package:better_player/src/controls/better_player_material_progress_bar.dart';
import 'package:better_player/src/controls/better_player_multiple_gesture_detector.dart';
import 'package:better_player/src/controls/better_player_progress_colors.dart';
import 'package:better_player/src/core/better_player_controller.dart';
import 'package:better_player/src/core/better_player_utils.dart';
import 'package:better_player/src/video_player/video_player.dart';

// Flutter imports:
import 'package:flutter/material.dart';

class BetterPlayerMaterialControls extends StatefulWidget {
  ///Callback used to send information if player bar is hidden or not
  final Function(bool visbility) onControlsVisibilityChanged;

  ///Controls config
  final BetterPlayerControlsConfiguration controlsConfiguration;

  const BetterPlayerMaterialControls({
    Key? key,
    required this.onControlsVisibilityChanged,
    required this.controlsConfiguration,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _BetterPlayerMaterialControlsState();
  }
}

class _BetterPlayerMaterialControlsState
    extends BetterPlayerControlsState<BetterPlayerMaterialControls> {
  VideoPlayerValue? _latestValue;
  double? _latestVolume;
  bool controlsNotVisible = true;
  Timer? _hideTimer;
  Timer? _initTimer;
  Timer? _showAfterExpandCollapseTimer;
  bool _displayTapped = false;
  bool _wasLoading = false;
  bool _isActionLocked = false;
  VideoPlayerController? _controller;
  BetterPlayerController? _betterPlayerController;
  StreamSubscription? _controlsVisibilityStreamSubscription;

  BetterPlayerControlsConfiguration get _controlsConfiguration =>
      widget.controlsConfiguration;

  void onActionLockToggle() {
    setState(() {
      _isActionLocked = !_isActionLocked;
    });
    cancelAndRestartTimer();
  }

  @override
  VideoPlayerValue? get latestValue => _latestValue;

  @override
  BetterPlayerController? get betterPlayerController => _betterPlayerController;

  @override
  BetterPlayerControlsConfiguration get betterPlayerControlsConfiguration =>
      _controlsConfiguration;

  @override
  void onShowMoreClicked() {
    if (_controlsConfiguration.onShowMoreClicked != null) {
      _controlsConfiguration.onShowMoreClicked
          ?.call(context, betterPlayerController!);
    } else {
      super.onShowMoreClicked();
    }
  }

  @override
  Widget build(BuildContext context) {
    return buildLTRDirectionality(_buildMainWidget());
  }

  ///Builds main widget of the controls.
  Widget _buildMainWidget() {
    _wasLoading = isLoading(latestValue);
    if (latestValue?.hasError == true) {
      return Container(
        color: Colors.black,
        child: _buildErrorWidget(),
      );
    }
    return GestureDetector(
        onTap: () {
          if (BetterPlayerMultipleGestureDetector.of(context) != null) {
            BetterPlayerMultipleGestureDetector.of(context)!.onTap?.call();
          }
          controlsNotVisible
              ? cancelAndRestartTimer()
              : changePlayerControlsNotVisible(true);
        },
        onDoubleTap: () {
          if (BetterPlayerMultipleGestureDetector.of(context) != null) {
            BetterPlayerMultipleGestureDetector.of(context)!
                .onDoubleTap
                ?.call();
          }
          cancelAndRestartTimer();
          _onPlayPause();
        },
        onLongPress: () {
          if (BetterPlayerMultipleGestureDetector.of(context) != null) {
            BetterPlayerMultipleGestureDetector.of(context)!
                .onLongPress
                ?.call();
          }
        },
        child: AbsorbPointer(
            absorbing: controlsNotVisible,
            child: Column(
              children: [
                if (!_isActionLocked) _buildTopBar(),
                if (_wasLoading)
                  Expanded(child: Center(child: _buildLoadingWidget()))
                else
                  _buildHitArea(),
                if (!_isActionLocked) _buildBottomBar(),
              ],
            )));
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  void _dispose() {
    _controller?.removeListener(_updateState);
    _hideTimer?.cancel();
    _initTimer?.cancel();
    _showAfterExpandCollapseTimer?.cancel();
    _controlsVisibilityStreamSubscription?.cancel();
  }

  @override
  void didChangeDependencies() {
    final _oldController = _betterPlayerController;
    _betterPlayerController = BetterPlayerController.of(context);
    _controller = _betterPlayerController!.videoPlayerController;
    _latestValue = _controller!.value;

    if (_oldController != _betterPlayerController) {
      _dispose();
      _initialize();
    }

    super.didChangeDependencies();
  }

  Widget _buildErrorWidget() {
    final errorBuilder =
        _betterPlayerController!.betterPlayerConfiguration.errorBuilder;
    if (errorBuilder != null) {
      return errorBuilder(
          context,
          _betterPlayerController!
              .videoPlayerController!.value.errorDescription);
    } else {
      final textStyle = TextStyle(color: _controlsConfiguration.textColor);
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.warning,
              color: _controlsConfiguration.iconsColor,
              size: 42,
            ),
            Text(
              _betterPlayerController!.translations.generalDefaultError,
              style: textStyle,
            ),
            if (_controlsConfiguration.enableRetry)
              TextButton(
                onPressed: () {
                  _betterPlayerController!.retryDataSource();
                },
                child: Text(
                  _betterPlayerController!.translations.generalRetry,
                  style: textStyle.copyWith(fontWeight: FontWeight.bold),
                ),
              )
          ],
        ),
      );
    }
  }

  Widget _buildTopBar() {
    if (!betterPlayerController!.controlsEnabled) {
      return const SizedBox();
    }
    Widget current = Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      if (_controlsConfiguration.enablePip)
        _buildPipButtonWrapperWidget(controlsNotVisible, _onPlayerHide)
      else
        const SizedBox(),
      if (_controlsConfiguration.enableOverflowMenu)
        Container(
          height: _controlsConfiguration.controlBarHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildMoreButton(),
            ],
          ),
        )
      else
        const SizedBox()
    ]);

    if (_controlsConfiguration.enableNavback) {
      current = Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [BackButton(color: Colors.white), current],
      );
    }
    if (_controlsConfiguration.topBarGradient != null) {
      current = Container(
        child: current,
        decoration:
            BoxDecoration(gradient: _controlsConfiguration.topBarGradient),
      );
    }

    return AnimatedOpacity(
        opacity: controlsNotVisible ? 0.0 : 1.0,
        duration: _controlsConfiguration.controlsHideTime,
        onEnd: _onPlayerHide,
        child: current);
  }

  Widget _buildPipButton() {
    return BetterPlayerMaterialClickableWidget(
      onTap: () {
        betterPlayerController!.enablePictureInPicture(
            betterPlayerController!.betterPlayerGlobalKey!);
      },
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          betterPlayerControlsConfiguration.pipMenuIcon,
          color: betterPlayerControlsConfiguration.iconsColor,
        ),
      ),
    );
  }

  Widget _buildPipButtonWrapperWidget(
      bool hideStuff, void Function() onPlayerHide) {
    return FutureBuilder<bool>(
      future: betterPlayerController!.isPictureInPictureSupported(),
      builder: (context, snapshot) {
        final bool isPipSupported = snapshot.data ?? false;
        if (isPipSupported &&
            _betterPlayerController!.betterPlayerGlobalKey != null) {
          return AnimatedOpacity(
              opacity: hideStuff ? 0.0 : 1.0,
              duration: betterPlayerControlsConfiguration.controlsHideTime,
              onEnd: onPlayerHide,
              child: Container(
                height: betterPlayerControlsConfiguration.controlBarHeight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildPipButton(),
                  ],
                ),
              ));
        } else {
          return const SizedBox();
        }
      },
    );
  }

  Widget _buildMoreButton() {
    return BetterPlayerMaterialClickableWidget(
      onTap: () {
        onShowMoreClicked();
      },
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          _controlsConfiguration.overflowMenuIcon,
          color: _controlsConfiguration.iconsColor,
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    if (!betterPlayerController!.controlsEnabled) {
      return const SizedBox();
    }
    return AnimatedOpacity(
      opacity: controlsNotVisible ? 0.0 : 1.0,
      duration: _controlsConfiguration.controlsHideTime,
      onEnd: _onPlayerHide,
      child: Container(
        height: _controlsConfiguration.controlBarHeight,
        decoration: BoxDecoration(
            gradient: _controlsConfiguration.controlBarGradient,
            color: _controlsConfiguration.controlBarColor),
        child: Row(
          children: [
            if (_controlsConfiguration.enablePlayPause)
              _buildPlayPause(_controller!)
            else
              const SizedBox(),
            if (_betterPlayerController!.isLiveStream())
              _buildLiveWidget()
            else
              _controlsConfiguration.enableProgressText
                  ? _buildPosition()
                  : const SizedBox(),
            if (_betterPlayerController!.isLiveStream())
              const SizedBox()
            else
              _controlsConfiguration.enableProgressBar
                  ? _buildProgressBar()
                  : const SizedBox(),
            if (_controlsConfiguration.enableProgressText) _buildTotal(),
            if (_controlsConfiguration.enableMute)
              _buildMuteButton(_controller)
            else
              const SizedBox(),
            if (_controlsConfiguration.enableFullscreen)
              _buildExpandButton()
            else
              const SizedBox(),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveWidget() {
    return Expanded(
      child: Text(
        _betterPlayerController!.translations.controlsLive,
        style: TextStyle(
            color: _controlsConfiguration.liveTextColor,
            fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildExpandButton() {
    return BetterPlayerMaterialClickableWidget(
      onTap: _onExpandCollapse,
      child: AnimatedOpacity(
        opacity: controlsNotVisible ? 0.0 : 1.0,
        duration: _controlsConfiguration.controlsHideTime,
        child: Container(
          height: _controlsConfiguration.controlBarHeight,
          margin: const EdgeInsets.only(right: 12.0),
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Center(
            child: Icon(
              _betterPlayerController!.isFullScreen
                  ? Icons.fullscreen_exit
                  : Icons.fullscreen,
              color: _controlsConfiguration.iconsColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHitArea() {
    if (!betterPlayerController!.controlsEnabled) {
      return const SizedBox();
    }
    return Expanded(
      child: Container(
        color: Colors.transparent,
        child: Center(
          child: AnimatedOpacity(
            opacity: controlsNotVisible ? 0.0 : 1.0,
            duration: _controlsConfiguration.controlsHideTime,
            child: Stack(
              children: [
                _buildMiddleRow(),
                _buildNextVideoWidget(),
                if (_controlsConfiguration.enableActionLock)
                  _buildActionLockButton()
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiddleRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_controlsConfiguration.enableSkips)
            _buildSkipButton()
          else
            const SizedBox(),
          _buildReplayButton(),
          if (_controlsConfiguration.enableSkips)
            _buildForwardButton()
          else
            const SizedBox(),
        ],
      ),
    );
  }

  Widget _buildHitAreaClickableButton(
      {required Widget icon, required Function() onClicked}) {
    return BetterPlayerMaterialClickableWidget(
      onTap: onClicked,
      child: Align(
        child: Container(
          decoration: BoxDecoration(
            color: _controlsConfiguration.controlBarColor,
            borderRadius: BorderRadius.circular(48),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Stack(
              children: [icon],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkipButton() {
    return _buildHitAreaClickableButton(
      icon: Icon(
        _controlsConfiguration.skipBackIcon,
        size: 24,
        color: _controlsConfiguration.iconsColor,
      ),
      onClicked: skipBack,
    );
  }

  Widget _buildForwardButton() {
    return _buildHitAreaClickableButton(
      icon: Icon(
        _controlsConfiguration.skipForwardIcon,
        size: 24,
        color: _controlsConfiguration.iconsColor,
      ),
      onClicked: skipForward,
    );
  }

  Widget _buildActionLockButton() {
    return Row(children: [
      Align(
        child: GestureDetector(
            onTap: onActionLockToggle,
            child: Padding(
                padding: EdgeInsets.all(12),
                child: Container(
                    child: Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                            _isActionLocked
                                ? Icons.lock_outline
                                : Icons.lock_open,
                            size: 20,
                            color: Colors.white)),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: Color.fromRGBO(0, 0, 0, 0.4))))),
      )
    ], mainAxisAlignment: MainAxisAlignment.end);
  }

  Widget _buildReplayButton() {
    final bool isFinished = isVideoFinished(latestValue);
    return _buildHitAreaClickableButton(
      icon: isFinished
          ? Icon(
              Icons.replay,
              size: 42,
              color: _controlsConfiguration.iconsColor,
            )
          : Icon(
              _controller!.value.isPlaying
                  ? _controlsConfiguration.pauseIcon
                  : _controlsConfiguration.playIcon,
              size: 42,
              color: _controlsConfiguration.iconsColor,
            ),
      onClicked: () {
        if (isFinished) {
          if (latestValue != null && latestValue!.isPlaying) {
            if (_displayTapped) {
              changePlayerControlsNotVisible(true);
            } else {
              cancelAndRestartTimer();
            }
          } else {
            _onPlayPause();
            changePlayerControlsNotVisible(true);
          }
        } else {
          _onPlayPause();
        }
      },
    );
  }

  Widget _buildNextVideoWidget() {
    return StreamBuilder<int?>(
      stream: _betterPlayerController!.nextVideoTimeStream,
      builder: (context, snapshot) {
        final time = snapshot.data;
        if (time != null && time > 0) {
          return BetterPlayerMaterialClickableWidget(
            onTap: () {
              _betterPlayerController!.playNextVideo();
            },
            child: Align(
              alignment: Alignment.bottomRight,
              child: Container(
                margin: EdgeInsets.only(
                    bottom: _controlsConfiguration.controlBarHeight + 20,
                    right: 24),
                decoration: BoxDecoration(
                  color: _controlsConfiguration.controlBarColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    "${_betterPlayerController!.translations.controlsNextVideoIn} $time...",
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          );
        } else {
          return const SizedBox();
        }
      },
    );
  }

  Widget _buildMuteButton(
    VideoPlayerController? controller,
  ) {
    return BetterPlayerMaterialClickableWidget(
      onTap: () {
        cancelAndRestartTimer();
        if (latestValue!.volume == 0) {
          _betterPlayerController!.setVolume(_latestVolume ?? 0.5);
        } else {
          _latestVolume = controller!.value.volume;
          _betterPlayerController!.setVolume(0.0);
        }
      },
      child: AnimatedOpacity(
        opacity: controlsNotVisible ? 0.0 : 1.0,
        duration: _controlsConfiguration.controlsHideTime,
        child: ClipRect(
          child: Container(
            height: _controlsConfiguration.controlBarHeight,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(
              (latestValue != null && latestValue!.volume > 0)
                  ? _controlsConfiguration.muteIcon
                  : _controlsConfiguration.unMuteIcon,
              color: _controlsConfiguration.iconsColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayPause(VideoPlayerController controller) {
    return BetterPlayerMaterialClickableWidget(
      key: const Key("better_player_material_controls_play_pause_button"),
      onTap: _onPlayPause,
      child: Container(
        height: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Icon(
          controller.value.isPlaying
              ? _controlsConfiguration.pauseIcon
              : _controlsConfiguration.playIcon,
          color: _controlsConfiguration.iconsColor,
        ),
      ),
    );
  }

  Widget _buildPosition() {
    final position =
        latestValue != null ? latestValue!.position : const Duration();

    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: Text(
        BetterPlayerUtils.formatDuration(position),
        style: TextStyle(
          color: _controlsConfiguration.textColor,
          fontSize: 12.0,
        ),
      ),
    );
  }

  Widget _buildRemaining() {
    final position = latestValue != null && latestValue!.duration != null
        ? latestValue!.duration! - latestValue!.position
        : const Duration();

    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: Text(
        '-${BetterPlayerUtils.formatDuration(position)}',
        style:
            TextStyle(color: _controlsConfiguration.textColor, fontSize: 12.0),
      ),
    );
  }

  Widget _buildTotal() {
    final duration = latestValue != null && latestValue!.duration != null
        ? latestValue!.duration!
        : Duration.zero;

    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: Text(
        BetterPlayerUtils.formatDuration(duration),
        style: TextStyle(
          color: _controlsConfiguration.textColor,
          fontSize: 12.0,
        ),
      ),
    );
  }

  @override
  void cancelAndRestartTimer() {
    _hideTimer?.cancel();
    _startHideTimer();

    changePlayerControlsNotVisible(false);
    _displayTapped = true;
  }

  Future<void> _initialize() async {
    _controller!.addListener(_updateState);

    _updateState();

    if ((_controller?.value != null && _controller!.value.isPlaying) ||
        _betterPlayerController!.betterPlayerConfiguration.autoPlay) {
      _startHideTimer();
    }

    if (_controlsConfiguration.showControlsOnInitialize) {
      _initTimer = Timer(const Duration(milliseconds: 200), () {
        changePlayerControlsNotVisible(false);
      });
    }

    _controlsVisibilityStreamSubscription =
        _betterPlayerController!.controlsVisibilityStream.listen((state) {
      changePlayerControlsNotVisible(!state);
      if (!controlsNotVisible) {
        cancelAndRestartTimer();
      }
    });
  }

  void _onExpandCollapse() {
    changePlayerControlsNotVisible(true);
    _betterPlayerController!.toggleFullScreen();
    _showAfterExpandCollapseTimer =
        Timer(_controlsConfiguration.controlsHideTime, () {
      setState(() {
        cancelAndRestartTimer();
      });
    });
  }

  void _onPlayPause() async {
    bool isFinished = false;

    if (_latestValue?.position != null && _latestValue?.duration != null) {
      isFinished = _latestValue!.position >= _latestValue!.duration!;
    }

    if (_controller!.value.isPlaying) {
      changePlayerControlsNotVisible(false);
      _hideTimer?.cancel();
      _betterPlayerController!.pause();
    } else {
      cancelAndRestartTimer();

      if (!_controller!.value.initialized) {
      } else {
        if (isFinished) {
          _betterPlayerController!.seekTo(const Duration());
        }
        _betterPlayerController!.play();
        _betterPlayerController!.cancelNextVideoTimer();
      }
    }
  }

  void _startHideTimer() {
    if (_betterPlayerController!.controlsAlwaysVisible) {
      return;
    }
    _hideTimer = Timer(const Duration(milliseconds: 3000), () {
      changePlayerControlsNotVisible(true);
    });
  }

  void _updateState() {
    if (mounted) {
      if (!controlsNotVisible ||
          isVideoFinished(_controller!.value) ||
          _wasLoading ||
          isLoading(_controller!.value)) {
        setState(() {
          _latestValue = _controller!.value;
          if (isVideoFinished(_latestValue) &&
              _betterPlayerController?.isLiveStream() == false) {
            changePlayerControlsNotVisible(false);
          }
        });
      }
    }
  }

  Widget _buildProgressBar() {
    return Expanded(
      flex: 40,
      child: Container(
        alignment: Alignment.bottomCenter,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: BetterPlayerMaterialVideoProgressBar(
          _controller,
          _betterPlayerController,
          onDragStart: () {
            _hideTimer?.cancel();
          },
          onDragEnd: () {
            _startHideTimer();
          },
          onTapDown: () {
            cancelAndRestartTimer();
          },
          colors: BetterPlayerProgressColors(
              playedColor: _controlsConfiguration.progressBarPlayedColor,
              handleColor: _controlsConfiguration.progressBarHandleColor,
              bufferedColor: _controlsConfiguration.progressBarBufferedColor,
              backgroundColor:
                  _controlsConfiguration.progressBarBackgroundColor),
        ),
      ),
    );
  }

  void _onPlayerHide() {
    _betterPlayerController!.toggleControlsVisibility(!controlsNotVisible);
    widget.onControlsVisibilityChanged(!controlsNotVisible);
  }

  Widget? _buildLoadingWidget() {
    if (_controlsConfiguration.loadingWidget != null) {
      return Container(
        color: _controlsConfiguration.controlBarColor,
        child: _controlsConfiguration.loadingWidget,
      );
    }

    return CircularProgressIndicator(
      valueColor:
          AlwaysStoppedAnimation<Color>(_controlsConfiguration.loadingColor),
    );
  }
}
