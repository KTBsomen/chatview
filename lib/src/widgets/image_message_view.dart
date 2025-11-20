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
 */
import 'dart:convert';
import 'dart:io';

import 'package:chatview/src/extensions/extensions.dart';
import 'package:chatview/src/models/models.dart';
import 'package:chatview/src/services/chatUpload.dart';
import 'package:flutter/material.dart';

import 'reaction_widget.dart';
import 'share_icon.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ImageMessageView extends StatelessWidget {
  const ImageMessageView({
    Key? key,
    required this.message,
    required this.isMessageBySender,
    this.imageMessageConfig,
    this.messageReactionConfig,
    this.highlightImage = false,
    this.highlightScale = 1.2,
  }) : super(key: key);

  /// Provides message instance of chat.
  final Message message;

  /// Represents current message is sent by current user.
  final bool isMessageBySender;

  /// Provides configuration for image message appearance.
  final ImageMessageConfiguration? imageMessageConfig;

  /// Provides configuration of reaction appearance in chat bubble.
  final MessageReactionConfiguration? messageReactionConfig;

  /// Represents flag of highlighting image when user taps on replied image.
  final bool highlightImage;

  /// Provides scale of highlighted image when user taps on replied image.
  final double highlightScale;

  String get imageUrl => message.message;

  Widget get iconButton => ShareIcon(
        shareIconConfig: imageMessageConfig?.shareIconConfig,
        imageUrl: imageUrl,
      );
  bool get isCanceled =>
      UploadService.isUploadCancelled(message.message) == true;
  bool get isRetrying =>
      UploadService.isUploadCancelled(message.message) == false &&
      message.uploadProgress.value < 1.0;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment:
          isMessageBySender ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (isMessageBySender && !(imageMessageConfig?.hideShareIcon ?? false))
          iconButton,
        Stack(
          children: [
            GestureDetector(
              onTap: () => imageMessageConfig?.onTap != null
                  ? imageMessageConfig?.onTap!(message)
                  : null,
              child: Transform.scale(
                scale: highlightImage ? highlightScale : 1.0,
                alignment: isMessageBySender
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  padding: imageMessageConfig?.padding ?? EdgeInsets.zero,
                  margin: imageMessageConfig?.margin ??
                      EdgeInsets.only(
                        top: 6,
                        right: isMessageBySender ? 6 : 0,
                        left: isMessageBySender ? 0 : 6,
                        bottom: message.reaction.reactions.isNotEmpty ? 15 : 0,
                      ),
                  height: imageMessageConfig?.height ?? 200,
                  width: imageMessageConfig?.width ?? 150,
                  child: ClipRRect(
                    borderRadius: imageMessageConfig?.borderRadius ??
                        BorderRadius.circular(14),
                    child: (() {
                      if (message.isOneTime) {
                        return Stack(
                          children: [
                            Container(
                              color: Colors.black12,
                              child: const Center(
                                child: Icon(
                                  Icons.visibility,
                                  color: Colors.white70,
                                  size: 48,
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  borderRadius:
                                      imageMessageConfig?.borderRadius ??
                                          BorderRadius.circular(14),
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.lock,
                                        color: Colors.white, size: 40),
                                    SizedBox(height: 12),
                                    Text(
                                      "One-time image",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Text(
                                        "Tap to view. This image can only be seen once.",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      }
                      if (imageUrl.isUrl) {
                        return CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.fitHeight,
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(),
                          ),
                          errorWidget: (context, url, error) =>
                              const Icon(Icons.error),
                        );
                      } else if (imageUrl.fromMemory) {
                        return Image.memory(
                          base64Decode(imageUrl
                              .substring(imageUrl.indexOf('base64') + 7)),
                          fit: BoxFit.fill,
                        );
                      } else {
                        return Image.file(
                          File(imageUrl),
                          fit: BoxFit.fill,
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
                              boxShadow: const [
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
                                      decoration: const BoxDecoration(
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
                                      decoration: const BoxDecoration(
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
        if (!isMessageBySender && !(imageMessageConfig?.hideShareIcon ?? false))
          iconButton,
      ],
    );
  }
}
