/*
 * Copyright (c) 2022 Simform Solutions
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 * #Edited by Somen Das (somen6562@gmail.com)
 */

import 'dart:convert';
import 'dart:io';

import 'package:chatview/src/extensions/extensions.dart';
import 'package:chatview/src/models/config_models/video_message_configuration.dart';
import 'package:chatview/src/models/models.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:chatview/src/services/chatUpload.dart';

import 'reaction_widget.dart';
import 'share_icon.dart';

class VideoMessageView extends StatelessWidget {
  const VideoMessageView({
    Key? key,
    required this.message,
    required this.isMessageBySender,
    this.VideoMessageConfig,
    this.messageReactionConfig,
    this.highlightVideo = false,
    this.highlightScale = 1.2,
  }) : super(key: key);

  /// Provides message instance of chat.
  final Message message;

  /// Represents current message is sent by current user.
  final bool isMessageBySender;

  /// Provides configuration for Video message appearance.
  final VideoMessageConfiguration? VideoMessageConfig;

  /// Provides configuration of reaction appearance in chat bubble.
  final MessageReactionConfiguration? messageReactionConfig;

  /// Represents flag of highlighting Video when user taps on replied Video.
  final bool highlightVideo;

  /// Provides scale of highlighted Video when user taps on replied Video.
  final double highlightScale;

  String get videoUrl => message.message;

  Widget get iconButton => VideoShareIcon(
        videoshareIconConfig: VideoMessageConfig?.shareIconConfig,
        videoUrl: videoUrl,
      );

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment:
          isMessageBySender ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (isMessageBySender && !(VideoMessageConfig?.hideShareIcon ?? false))
          iconButton,
        Stack(
          children: [
            GestureDetector(
              onTap: () => VideoMessageConfig?.onTap != null
                  ? VideoMessageConfig?.onTap!(message)
                  : null,
              child: Transform.scale(
                scale: highlightVideo ? highlightScale : 1.0,
                alignment: isMessageBySender
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  padding: VideoMessageConfig?.padding ?? EdgeInsets.zero,
                  margin: VideoMessageConfig?.margin ??
                      EdgeInsets.only(
                        top: 6,
                        right: isMessageBySender ? 6 : 0,
                        left: isMessageBySender ? 0 : 6,
                        bottom: message.reaction.reactions.isNotEmpty ? 15 : 0,
                      ),
                  height: VideoMessageConfig?.height ?? 200,
                  width: VideoMessageConfig?.width ?? 150,
                  child: ClipRRect(
                    borderRadius: VideoMessageConfig?.borderRadius ??
                        BorderRadius.circular(14),
                    child: (() {
                      if (videoUrl.isUrl) {
                        return Video.network(
                          videoUrl,
                          message.id,
                          fit: BoxFit.fitWidth,
                          // loadingBuilder: (context, child, loadingProgress) {
                          //   if (loadingProgress == null) return child;
                          //   return Center(
                          //     child: CircularProgressIndicator(
                          //       value: loadingProgress.expectedTotalBytes !=
                          //               null
                          //           ? loadingProgress.cumulativeBytesLoaded /
                          //               loadingProgress.expectedTotalBytes!
                          //           : null,
                          //     ),
                          //   );
                          // },
                        );
                      } else if (videoUrl.fromMemory) {
                        return Video.memory(
                          base64Decode(videoUrl
                              .substring(videoUrl.indexOf('base64') + 7)),
                          message.id,
                        );
                      } else {
                        return Video.file(
                          File(videoUrl),
                          message.id,
                        );
                      }
                    }()),
                  ),
                ),
              ),
            ),
            ValueListenableBuilder<double>(
              valueListenable: message.uploadProgress,
              builder: (context, progress, _) {
                if (progress >= 1.0) return const SizedBox.shrink();
                return Positioned.fill(
                  child: Container(
                    color: Colors.black45, // dim background
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 8,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(20),
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 6,
                              backgroundColor: Colors.grey.shade200,
                              color: Colors.blue,
                            ),
                          ),
                          // Show cancel or retry button based on progress
                          progress != -3.0
                              ? Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: GestureDetector(
                                    onTap: () {
                                      UploadService.cancelUpload(
                                        message.message,
                                      );
                                      // Reset progress to -3.0 to indicate cancellation
                                      message.uploadProgress.value = -3.0;
                                    },
                                    child: Container(
                                      width: 30,
                                      height: 30,
                                      alignment: Alignment.center,
                                      margin: const EdgeInsets.all(25),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.black,
                                      ),
                                      padding: const EdgeInsets.all(6),
                                      child: const Icon(Icons.close,
                                          color: Colors.white, size: 16),
                                    ),
                                  ),
                                )
                              : Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: GestureDetector(
                                    onTap: () {
                                      UploadService.retryUpload(
                                        message.message,
                                      ).then((response) {
                                        message.uploadProgress.value = 1.0;
                                        message.message = response.publicUrl;
                                        message.onRetry?.call(message);
                                      }).catchError((error) {
                                        // Handle retry error if needed
                                        print('Retry upload failed: $error');
                                        message.uploadProgress.value = -3.0;
                                      });
                                    },
                                    child: Container(
                                      width: 30,
                                      height: 30,
                                      alignment: Alignment.center,
                                      margin: const EdgeInsets.all(25),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.black,
                                      ),
                                      padding: const EdgeInsets.all(6),
                                      child: const Icon(Icons.replay_rounded,
                                          color: Colors.white, size: 16),
                                    ),
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            if (message.reaction.reactions.isNotEmpty)
              ReactionWidget(
                isMessageBySender: isMessageBySender,
                reaction: message.reaction,
                messageReactionConfig: messageReactionConfig,
              ),
          ],
        ),
        if (!isMessageBySender && !(VideoMessageConfig?.hideShareIcon ?? false))
          iconButton,
      ],
    );
  }
}

class Video extends StatefulWidget {
  final String? url;
  final Uint8List? memoryData;
  final File? file;
  final BoxFit fit;
  final String id;

  const Video.network(this.url, this.id, {this.fit = BoxFit.fitWidth, Key? key})
      : memoryData = null,
        file = null,
        super(key: key);

  const Video.memory(this.memoryData, this.id,
      {this.fit = BoxFit.fitWidth, Key? key})
      : url = null,
        file = null,
        super(key: key);

  const Video.file(this.file, this.id, {this.fit = BoxFit.fitWidth, Key? key})
      : url = null,
        memoryData = null,
        super(key: key);
  const Video({
    this.url,
    this.memoryData,
    this.file,
    this.fit = BoxFit.fitWidth,
    required this.id,
    Key? key,
  }) : super(key: key);
  @override
  State<Video> createState() => _VideoState();
}

class _VideoState extends State<Video> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.url != null) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url!));
    } else if (widget.memoryData != null) {
      // Decode the base64 string to Uint8List
      // and create a file from it
      final directory = Directory.systemTemp;
      final file = File('${directory.path}/video.mp4');
      file.writeAsBytesSync(widget.memoryData!);

      _controller = VideoPlayerController.file(file!);
    } else if (widget.file != null) {
      _controller = VideoPlayerController.file(widget.file!);
    }
    _controller?.initialize().then((_) {
      setState(() {}); // Refresh once video is ready
      //_controller?.play();
      //_controller?.setLooping(true);
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return Center(child: CircularProgressIndicator());
    }
    return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FullScreenVideoPlayer(
                controller: _controller,
                heroTag: widget.id, // <-- pass hero tag
              ),
            ),
          );
        },
        child: Hero(
          tag: widget.id,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (_controller!.value.isPlaying) {
                      _controller!.pause();
                    } else {
                      _controller!.play();
                    }
                  });
                },
                child: Icon(
                  _controller!.value.isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                  size: 64,
                  color: Colors.purple.withOpacity(1),
                ),
              ),
            ],
          ),
        ));
  }
}

class FullScreenVideoPlayer extends StatefulWidget {
  final VideoPlayerController? controller;
  final String heroTag;

  const FullScreenVideoPlayer({
    Key? key,
    this.controller,
    required this.heroTag,
  }) : super(key: key);

  @override
  State<FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<FullScreenVideoPlayer> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 12, 1, 31),
      body: Center(
        child: Hero(
          tag: widget.heroTag,
          child: AspectRatio(
            aspectRatio: widget.controller!.value.aspectRatio,
            child: VideoPlayer(widget.controller!),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (widget.controller!.value.isPlaying) {
            widget.controller!.pause();
            setState(() {});
          } else {
            widget.controller!.play();
            setState(() {});
          }
        },
        child: Icon(
          widget.controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
        ),
      ),
    );
  }
}

// import 'dart:convert';
// import 'dart:io';
// import 'dart:typed_data';

// import 'package:flutter/material.dart';
// import 'package:video_player/video_player.dart';
// import 'package:video_thumbnail/video_thumbnail.dart';

// import 'package:chatview/src/extensions/extensions.dart';
// import 'package:chatview/src/models/config_models/video_message_configuration.dart';
// import 'package:chatview/src/models/models.dart';
// import 'package:chatview/src/services/chatUpload.dart';

// import 'reaction_widget.dart';
// import 'share_icon.dart';
// import 'package:awesome_video_player/awesome_video_player.dart';

// class VideoMessageView extends StatefulWidget {
//   const VideoMessageView({
//     Key? key,
//     required this.message,
//     required this.isMessageBySender,
//     this.VideoMessageConfig,
//     this.messageReactionConfig,
//     this.highlightVideo = false,
//     this.highlightScale = 1.2,
//   }) : super(key: key);

//   final Message message;
//   final bool isMessageBySender;
//   final VideoMessageConfiguration? VideoMessageConfig;
//   final MessageReactionConfiguration? messageReactionConfig;
//   final bool highlightVideo;
//   final double highlightScale;

//   @override
//   State<VideoMessageView> createState() => _VideoMessageViewState();
// }

// class _VideoMessageViewState extends State<VideoMessageView> {
//   Uint8List? _thumbnailBytes;

//   String get videoUrl => widget.message.message;

//   @override
//   void initState() {
//     super.initState();
//     _generateThumbnail();
//   }

//   Future<void> _generateThumbnail() async {
//     try {
//       if (videoUrl.isUrl) {
//         final uint8list = await VideoThumbnail.thumbnailData(
//           video: videoUrl,
//           imageFormat: ImageFormat.PNG,
//           maxWidth: 150,
//           quality: 75,
//         );
//         if (uint8list != null) {
//           setState(() {
//             _thumbnailBytes = uint8list;
//           });
//         }
//       } else if (videoUrl.fromMemory) {
//         // For base64 videos, you might extract first frame separately or show placeholder
//         // Here we skip thumbnail extraction for memory videos
//       } else {
//         // local file
//         final uint8list = await VideoThumbnail.thumbnailData(
//           video: videoUrl,
//           imageFormat: ImageFormat.PNG,
//           maxWidth: 150,
//           quality: 75,
//         );
//         if (uint8list != null) {
//           setState(() {
//             _thumbnailBytes = uint8list;
//           });
//         }
//       }
//     } catch (e) {
//       // silently fail, fallback to placeholder
//     }
//   }

//   Widget get iconButton => VideoShareIcon(
//         videoshareIconConfig: widget.VideoMessageConfig?.shareIconConfig,
//         videoUrl: videoUrl,
//       );

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       mainAxisAlignment: widget.isMessageBySender
//           ? MainAxisAlignment.end
//           : MainAxisAlignment.start,
//       children: [
//         if (widget.isMessageBySender &&
//             !(widget.VideoMessageConfig?.hideShareIcon ?? false))
//           iconButton,
//         Stack(
//           children: [
//             GestureDetector(
//               onTap: () => widget.VideoMessageConfig?.onTap != null
//                   ? widget.VideoMessageConfig!.onTap!(widget.message)
//                   : Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                         builder: (_) => FullScreenVideoPlayer(
//                           videoUrl: videoUrl,
//                           heroTag: widget.message.id,
//                           fromMemory: videoUrl.fromMemory,
//                         ),
//                       ),
//                     ),
//               child: Transform.scale(
//                 scale: widget.highlightVideo ? widget.highlightScale : 1.0,
//                 alignment: widget.isMessageBySender
//                     ? Alignment.centerRight
//                     : Alignment.centerLeft,
//                 child: Container(
//                   padding:
//                       widget.VideoMessageConfig?.padding ?? EdgeInsets.zero,
//                   margin: widget.VideoMessageConfig?.margin ??
//                       EdgeInsets.only(
//                         top: 6,
//                         right: widget.isMessageBySender ? 6 : 0,
//                         left: widget.isMessageBySender ? 0 : 6,
//                         bottom: widget.message.reaction.reactions.isNotEmpty
//                             ? 15
//                             : 0,
//                       ),
//                   height: widget.VideoMessageConfig?.height ?? 200,
//                   width: widget.VideoMessageConfig?.width ?? 150,
//                   child: ClipRRect(
//                     borderRadius: widget.VideoMessageConfig?.borderRadius ??
//                         BorderRadius.circular(14),
//                     child: widget.message.isOneTime
//                         ? Stack(
//                             children: [
//                               Container(
//                                 color: Colors.black12,
//                                 child: const Center(
//                                   child: Icon(
//                                     Icons.visibility,
//                                     color: Colors.white70,
//                                     size: 48,
//                                   ),
//                                 ),
//                               ),
//                               Positioned.fill(
//                                 child: Container(
//                                   alignment: Alignment.center,
//                                   decoration: BoxDecoration(
//                                     color: Colors.black.withValues(alpha: 0.7),
//                                     borderRadius: widget
//                                             .VideoMessageConfig?.borderRadius ??
//                                         BorderRadius.circular(14),
//                                   ),
//                                   child: const Column(
//                                     mainAxisAlignment: MainAxisAlignment.center,
//                                     children: [
//                                       Icon(Icons.lock,
//                                           color: Colors.white, size: 40),
//                                       SizedBox(height: 12),
//                                       Text(
//                                         "One-time Video",
//                                         style: TextStyle(
//                                           color: Colors.white,
//                                           fontWeight: FontWeight.bold,
//                                           fontSize: 18,
//                                         ),
//                                       ),
//                                       SizedBox(height: 8),
//                                       Padding(
//                                         padding: EdgeInsets.all(8.0),
//                                         child: Text(
//                                           "Tap to view. This video can only be seen once.",
//                                           textAlign: TextAlign.center,
//                                           style: TextStyle(
//                                             color: Colors.white70,
//                                             fontSize: 14,
//                                           ),
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           )
//                         : _thumbnailBytes != null
//                             ? Stack(
//                                 fit: StackFit.expand,
//                                 children: [
//                                   Image.memory(
//                                     _thumbnailBytes!,
//                                     fit: BoxFit.cover,
//                                   ),
//                                   Container(
//                                     color: Colors.black26,
//                                   ),
//                                   Center(
//                                     child: Icon(
//                                       Icons.play_circle_fill,
//                                       color: Colors.white.withOpacity(0.8),
//                                       size: 64,
//                                     ),
//                                   ),
//                                 ],
//                               )
//                             : Container(
//                                 color: Colors.black12,
//                                 child: Center(
//                                   child: Icon(
//                                     Icons.videocam,
//                                     size: 48,
//                                     color: Colors.grey.shade700,
//                                   ),
//                                 ),
//                               ),
//                   ),
//                 ),
//               ),
//             ),
//             ValueListenableBuilder<double>(
//               valueListenable: widget.message.uploadProgress,
//               builder: (context, progress, _) {
//                 if (progress >= 1.0) return const SizedBox.shrink();
//                 return Positioned.fill(
//                   child: Container(
//                     color: Colors.black45,
//                     child: Center(
//                       child: Stack(
//                         alignment: Alignment.center,
//                         children: [
//                           Container(
//                             width: 120,
//                             height: 120,
//                             decoration: BoxDecoration(
//                               color: Colors.white.withOpacity(0.5),
//                               borderRadius: BorderRadius.circular(16),
//                               boxShadow: const [
//                                 BoxShadow(
//                                   color: Colors.black26,
//                                   blurRadius: 8,
//                                   offset: Offset(0, 4),
//                                 ),
//                               ],
//                             ),
//                             padding: const EdgeInsets.all(20),
//                             child: CircularProgressIndicator(
//                               value: progress,
//                               strokeWidth: 6,
//                               backgroundColor: Colors.grey.shade200,
//                               color: Colors.blue,
//                             ),
//                           ),
//                           progress != -3.0
//                               ? Positioned(
//                                   top: 0,
//                                   left: 0,
//                                   right: 0,
//                                   bottom: 0,
//                                   child: GestureDetector(
//                                     onTap: () {
//                                       UploadService.cancelUpload(
//                                           widget.message.message);
//                                       widget.message.uploadProgress.value =
//                                           -3.0;
//                                     },
//                                     child: Container(
//                                       width: 30,
//                                       height: 30,
//                                       alignment: Alignment.center,
//                                       margin: const EdgeInsets.all(25),
//                                       decoration: const BoxDecoration(
//                                         shape: BoxShape.circle,
//                                         color: Colors.black,
//                                       ),
//                                       padding: const EdgeInsets.all(6),
//                                       child: const Icon(Icons.close,
//                                           color: Colors.white, size: 16),
//                                     ),
//                                   ),
//                                 )
//                               : Positioned(
//                                   top: 0,
//                                   left: 0,
//                                   right: 0,
//                                   bottom: 0,
//                                   child: GestureDetector(
//                                     onTap: () {
//                                       UploadService.retryUpload(
//                                               widget.message.message)
//                                           .then((response) {
//                                         widget.message.uploadProgress.value =
//                                             1.0;
//                                         widget.message.message =
//                                             response.publicUrl;
//                                         widget.message.onRetry
//                                             ?.call(widget.message);
//                                       }).catchError((error) {
//                                         print('Retry upload failed: $error');
//                                         widget.message.uploadProgress.value =
//                                             -3.0;
//                                       });
//                                     },
//                                     child: Container(
//                                       width: 30,
//                                       height: 30,
//                                       alignment: Alignment.center,
//                                       margin: const EdgeInsets.all(25),
//                                       decoration: const BoxDecoration(
//                                         shape: BoxShape.circle,
//                                         color: Colors.black,
//                                       ),
//                                       padding: const EdgeInsets.all(6),
//                                       child: const Icon(Icons.replay_rounded,
//                                           color: Colors.white, size: 16),
//                                     ),
//                                   ),
//                                 ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 );
//               },
//             ),
//             if (widget.message.reaction.reactions.isNotEmpty)
//               ReactionWidget(
//                 isMessageBySender: widget.isMessageBySender,
//                 reaction: widget.message.reaction,
//                 messageReactionConfig: widget.messageReactionConfig,
//               ),
//           ],
//         ),
//         if (!widget.isMessageBySender &&
//             !(widget.VideoMessageConfig?.hideShareIcon ?? false))
//           iconButton,
//       ],
//     );
//   }
// }

// class FullScreenVideoPlayer extends StatefulWidget {
//   final String videoUrl;
//   final bool fromMemory;
//   final String heroTag;

//   const FullScreenVideoPlayer({
//     Key? key,
//     required this.videoUrl,
//     required this.heroTag,
//     this.fromMemory = false,
//   }) : super(key: key);

//   @override
//   State<FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
// }

// class _FullScreenVideoPlayerState extends State<FullScreenVideoPlayer> {
//   BetterPlayerController? _controller;

//   @override
//   void initState() {
//     super.initState();

//     BetterPlayerDataSource source;
//     if (widget.fromMemory) {
//       final base64String =
//           widget.videoUrl.substring(widget.videoUrl.indexOf('base64') + 7);
//       final bytes = base64Decode(base64String);
//       final tempDir = Directory.systemTemp;
//       final file = File('${tempDir.path}/${widget.heroTag}_video.mp4');
//       file.writeAsBytesSync(bytes);
//       source =
//           BetterPlayerDataSource(BetterPlayerDataSourceType.file, file.path);
//     } else if (widget.videoUrl.isUrl) {
//       source = BetterPlayerDataSource(
//           BetterPlayerDataSourceType.network, widget.videoUrl);
//     } else {
//       source = BetterPlayerDataSource(
//           BetterPlayerDataSourceType.file, widget.videoUrl);
//     }

//     _controller = BetterPlayerController(
//       const BetterPlayerConfiguration(
//         autoPlay: true,
//         looping: true,
//         fit: BoxFit.contain,
//       ),
//       betterPlayerDataSource: source,
//     );
//   }

//   @override
//   void dispose() {
//     _controller?.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: Center(
//         child: Hero(
//           tag: widget.heroTag,
//           child: AspectRatio(
//             aspectRatio: _controller?.getAspectRatio() ??
//                 9 / 16, // adjust based on your content
//             child: _controller != null
//                 ? BetterPlayer(controller: _controller!)
//                 : const CircularProgressIndicator(),
//           ),
//         ),
//       ),
//     );
//   }
// }
