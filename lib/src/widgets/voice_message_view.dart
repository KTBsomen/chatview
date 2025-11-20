import 'dart:async';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:chatview/chatview.dart';
import 'package:chatview/src/widgets/reaction_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

final Map<String, PlayerController> voiceControllerCache = {};

class VoiceMessageView extends StatefulWidget {
  const VoiceMessageView({
    Key? key,
    required this.screenWidth,
    required this.message,
    required this.isMessageBySender,
    this.inComingChatBubbleConfig,
    this.outgoingChatBubbleConfig,
    this.onMaxDuration,
    this.messageReactionConfig,
    this.config,
  }) : super(key: key);

  final VoiceMessageConfiguration? config;
  final double screenWidth;
  final Message message;
  final Function(int)? onMaxDuration;
  final bool isMessageBySender;
  final MessageReactionConfiguration? messageReactionConfig;
  final ChatBubble? inComingChatBubbleConfig;
  final ChatBubble? outgoingChatBubbleConfig;

  @override
  State<VoiceMessageView> createState() => _VoiceMessageViewState();
}

class _VoiceMessageViewState extends State<VoiceMessageView> {
  late PlayerController controller;
  late StreamSubscription<PlayerState> playerStateSubscription;

  final ValueNotifier<PlayerState> _playerState =
      ValueNotifier(PlayerState.stopped);

  PlayerState get playerState => _playerState.value;

  PlayerWaveStyle playerWaveStyle = const PlayerWaveStyle(scaleFactor: 70);

  @override
  void initState() {
    super.initState();
    final audioKey = widget.message.message;

    if (!voiceControllerCache.containsKey(audioKey)) {
      final newController = PlayerController();
      voiceControllerCache[audioKey] = newController;

      newController
          .preparePlayer(
        path: audioKey,
        noOfSamples: widget.config?.playerWaveStyle
                ?.getSamplesForWidth(widget.screenWidth * 0.5) ??
            playerWaveStyle.getSamplesForWidth(widget.screenWidth * 0.5),
      )
          .whenComplete(() {
        widget.onMaxDuration?.call(newController.maxDuration);
      });
    }

    controller = voiceControllerCache[audioKey]!;

    playerStateSubscription = controller.onPlayerStateChanged
        .listen((state) => _playerState.value = state);
  }

  @override
  void dispose() {
    playerStateSubscription.cancel();
    // Do not dispose controller here to avoid killing cache
    _playerState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: widget.config?.decoration ??
              BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: widget.isMessageBySender
                    ? widget.outgoingChatBubbleConfig?.color
                    : widget.inComingChatBubbleConfig?.color,
              ),
          padding: widget.config?.padding ??
              const EdgeInsets.symmetric(horizontal: 8),
          margin: widget.config?.margin ??
              EdgeInsets.symmetric(
                horizontal: 8,
                vertical: widget.message.reaction.reactions.isNotEmpty ? 15 : 0,
              ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<PlayerState>(
                valueListenable: _playerState,
                builder: (context, state, child) {
                  return IconButton(
                    onPressed: _playOrPause,
                    icon: Stack(
                      alignment: Alignment.center,
                      children: [
                        state.isStopped || state.isPaused || state.isInitialised
                            ? widget.config?.playIcon ??
                                const Icon(
                                  Icons.play_arrow,
                                  color: Colors.white,
                                )
                            : widget.config?.pauseIcon ??
                                const Icon(
                                  Icons.stop,
                                  color: Colors.white,
                                ),
                        ValueListenableBuilder<double>(
                          valueListenable: widget.message.uploadProgress,
                          builder: (context, progress, _) {
                            if (progress >= 1.0) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.all(5),
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 5,
                                backgroundColor: Colors.grey.shade200,
                                color: Colors.blue,
                              ),
                            );
                          },
                        ),
                        child ?? const SizedBox.shrink(),
                      ],
                    ),
                  );
                },
              ),
              AudioFileWaveforms(
                size: Size(widget.screenWidth * 0.50, 60),
                playerController: controller,
                waveformType: WaveformType.fitWidth,
                playerWaveStyle:
                    widget.config?.playerWaveStyle ?? playerWaveStyle,
                padding: widget.config?.waveformPadding ??
                    const EdgeInsets.only(right: 10),
                margin: widget.config?.waveformMargin,
                animationCurve: widget.config?.animationCurve ?? Curves.easeIn,
                animationDuration: widget.config?.animationDuration ??
                    const Duration(milliseconds: 500),
                enableSeekGesture: widget.config?.enableSeekGesture ?? true,
              ),
            ],
          ),
        ),
        if (widget.message.reaction.reactions.isNotEmpty)
          ReactionWidget(
            isMessageBySender: widget.isMessageBySender,
            reaction: widget.message.reaction,
            messageReactionConfig: widget.messageReactionConfig,
          ),
      ],
    );
  }

  void _playOrPause() {
    assert(
      defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android,
      "Voice messages are only supported with android and ios platform",
    );
    if (playerState.isInitialised ||
        playerState.isPaused ||
        playerState.isStopped) {
      controller.startPlayer();
      controller.setFinishMode(finishMode: FinishMode.pause);
    } else {
      controller.pausePlayer();
    }
  }
}
