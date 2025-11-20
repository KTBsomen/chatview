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
import 'dart:async';
import 'dart:io' show File, Platform;

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:chatview/src/utils/constants/constants.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../chatview.dart';
import '../utils/debounce.dart';
import '../utils/package_strings.dart';
import 'package:vs_media_picker/vs_media_picker.dart';
import 'package:geolocator/geolocator.dart';

class ChatUITextField extends StatefulWidget {
  ChatUITextField({
    super.key,
    this.sendMessageConfig,
    required this.focusNode,
    required this.textEditingController,
    required this.onPressed,
    required this.onRecordingComplete,
    required this.onImageSelected,
    this.onLocationSelected,
  });

  /// Provides configuration of default text field in chat.
  final SendMessageConfiguration? sendMessageConfig;

  /// Provides focusNode for focusing text field.
  final FocusNode focusNode;

  /// Provides functions which handles text field.
  final TextEditingController textEditingController;

  /// Provides callback when user tap on text field.
  final VoidCallBack onPressed;

  /// Provides callback once voice is recorded.
  final Function(String?) onRecordingComplete;

  /// Provides callback when user select images from camera/gallery.
  final PickedAssetCallBack onImageSelected;

  /// Provides location callbacks
  Function(String)? onLocationSelected;

  @override
  State<ChatUITextField> createState() => _ChatUITextFieldState();
}

class _ChatUITextFieldState extends State<ChatUITextField>
    with TickerProviderStateMixin {
  final ValueNotifier<String> _inputText = ValueNotifier('');

  final ImagePicker _imagePicker = ImagePicker();

  RecorderController? controller;

  ValueNotifier<bool> isRecording = ValueNotifier(false);

  SendMessageConfiguration? get sendMessageConfig => widget.sendMessageConfig;

  VoiceRecordingConfiguration? get voiceRecordingConfig =>
      widget.sendMessageConfig?.voiceRecordingConfiguration;

  ImagePickerIconsConfiguration? get imagePickerIconsConfig =>
      sendMessageConfig?.imagePickerIconsConfig;

  TextFieldConfiguration? get textFieldConfig =>
      sendMessageConfig?.textFieldConfig;

  CancelRecordConfiguration? get cancelRecordConfiguration =>
      sendMessageConfig?.cancelRecordConfiguration;

  OutlineInputBorder get _outLineBorder => OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.transparent),
        borderRadius: widget.sendMessageConfig?.textFieldConfig?.borderRadius ??
            BorderRadius.circular(textFieldBorderRadius),
      );

  ValueNotifier<TypeWriterStatus> composingStatus =
      ValueNotifier(TypeWriterStatus.typed);

  late Debouncer debouncer;
  late AnimationController attachController;
  late Animation<double> rotateAnimation;
  bool showAttachOptions = false;

  @override
  void initState() {
    attachListeners();
    debouncer = Debouncer(
        sendMessageConfig?.textFieldConfig?.compositionThresholdTime ??
            const Duration(seconds: 1));
    super.initState();
    attachController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );

    rotateAnimation = Tween(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: attachController, curve: Curves.easeOut),
    );
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      controller = RecorderController();
    }
  }

  @override
  void dispose() {
    debouncer.dispose();
    composingStatus.dispose();
    isRecording.dispose();
    _inputText.dispose();
    attachController.dispose();

    super.dispose();
  }

  void attachListeners() {
    composingStatus.addListener(() {
      widget.sendMessageConfig?.textFieldConfig?.onMessageTyping
          ?.call(composingStatus.value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final outlineBorder = _outLineBorder;
    return Container(
      padding:
          textFieldConfig?.padding ?? const EdgeInsets.symmetric(horizontal: 6),
      margin: textFieldConfig?.margin,
      decoration: BoxDecoration(
        borderRadius: textFieldConfig?.borderRadius ??
            BorderRadius.circular(textFieldBorderRadius),
        color: sendMessageConfig?.textFieldBackgroundColor ?? Colors.white,
      ),
      child: ValueListenableBuilder<bool>(
        valueListenable: isRecording,
        builder: (_, isRecordingValue, child) {
          return Row(
            children: [
              if (isRecordingValue && controller != null && !kIsWeb)
                Expanded(
                  child: AudioWaveforms(
                    size: const Size(double.maxFinite, 50),
                    recorderController: controller!,
                    margin: voiceRecordingConfig?.margin,
                    padding: voiceRecordingConfig?.padding ??
                        EdgeInsets.symmetric(
                          horizontal: cancelRecordConfiguration == null ? 8 : 5,
                        ),
                    decoration: voiceRecordingConfig?.decoration ??
                        BoxDecoration(
                          color: voiceRecordingConfig?.backgroundColor,
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                    waveStyle: voiceRecordingConfig?.waveStyle ??
                        WaveStyle(
                          extendWaveform: true,
                          showMiddleLine: false,
                          waveColor:
                              voiceRecordingConfig?.waveStyle?.waveColor ??
                                  Colors.black,
                        ),
                  ),
                )
              else
                Expanded(
                  child: TextField(
                    focusNode: widget.focusNode,
                    controller: widget.textEditingController,
                    style: textFieldConfig?.textStyle ??
                        const TextStyle(color: Colors.white),
                    maxLines: textFieldConfig?.maxLines ?? 5,
                    minLines: textFieldConfig?.minLines ?? 1,
                    keyboardType: textFieldConfig?.textInputType,
                    inputFormatters: textFieldConfig?.inputFormatters,
                    onChanged: _onChanged,
                    enabled: textFieldConfig?.enabled,
                    textCapitalization: textFieldConfig?.textCapitalization ??
                        TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText:
                          textFieldConfig?.hintText ?? PackageStrings.message,
                      fillColor: sendMessageConfig?.textFieldBackgroundColor ??
                          Colors.white,
                      filled: true,
                      hintStyle: textFieldConfig?.hintStyle ??
                          TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: Colors.grey.shade600,
                            letterSpacing: 0.25,
                          ),
                      contentPadding: textFieldConfig?.contentPadding ??
                          const EdgeInsets.symmetric(horizontal: 6),
                      border: outlineBorder,
                      focusedBorder: outlineBorder,
                      enabledBorder: outlineBorder,
                      disabledBorder: outlineBorder,
                    ),
                  ),
                ),
              ValueListenableBuilder<String>(
                valueListenable: _inputText,
                builder: (_, inputTextValue, child) {
                  if (inputTextValue.isNotEmpty) {
                    return IconButton(
                      color: sendMessageConfig?.defaultSendButtonColor ??
                          Colors.green,
                      onPressed: (textFieldConfig?.enabled ?? true)
                          ? () {
                              widget.onPressed();
                              _inputText.value = '';
                            }
                          : null,
                      icon: sendMessageConfig?.sendButtonIcon ??
                          const Icon(Icons.send),
                    );
                  } else {
                    return Row(
                      children: [
                        if (!isRecordingValue) ...[
                          /// NEW: LOCATION BUTTON
                          // _buildAnimatedButton(
                          //   visible: showAttachOptions,
                          //   offset: const Offset(0.5, 0),
                          //   icon: const Icon(Icons.location_on,
                          //       color: Colors.white),
                          //   onTap: () async {
                          //     await getLocation();
                          //   },
                          // ),

                          /// NEW: VIDEO CAMERA
                          _buildAnimatedButton(
                            visible: showAttachOptions,
                            offset: const Offset(0.4, 0),
                            icon: Icon(Icons.videocam,
                                color: imagePickerIconsConfig?.cameraIconColor),
                            onTap: () async {
                              final XFile? video = await _imagePicker.pickVideo(
                                source: ImageSource.camera,
                                preferredCameraDevice: CameraDevice.rear,
                              );
                              if (video == null) return;
                              widget.onImageSelected([
                                PickedAssetModel(
                                  id: video.name,
                                  path: video.path,
                                  type: "video",
                                  file: File(video.path),
                                )
                              ], '', false);
                            },
                          ),

                          // /// NEW: FILE PICKER (PDF, DOC, ZIP…)
                          // _buildAnimatedButton(
                          //   visible: showAttachOptions,
                          //   offset: const Offset(0.4, 0),
                          //   icon: const Icon(Icons.insert_drive_file,
                          //       color: Colors.white),
                          //   onTap: () async {
                          //     /// YOU plug in your file picker here:
                          //     /// e.g. file_picker plugin
                          //     /*
                          //     FilePickerResult? result = await FilePicker.platform.pickFiles();
                          //     if (result != null) { ... }
                          //     */

                          //     widget.onImageSelected(
                          //         [], "file_picker_request", false);
                          //   },
                          // ),

                          /// CAMERA ICON (Animated)
                          if (sendMessageConfig?.enableCameraImagePicker ??
                              true)
                            _buildAnimatedButton(
                              visible: showAttachOptions,
                              offset: const Offset(0.3, 0),
                              icon: imagePickerIconsConfig
                                      ?.cameraImagePickerIcon ??
                                  Icon(Icons.camera_alt_outlined,
                                      color: imagePickerIconsConfig
                                          ?.cameraIconColor),
                              onTap: () => _onIconPressed(
                                ImageSource.camera,
                                config:
                                    sendMessageConfig?.imagePickerConfiguration,
                              ),
                            ),

                          /// GALLERY ICON (Animated)
                          if (sendMessageConfig?.enableGalleryImagePicker ??
                              true)
                            _buildAnimatedButton(
                              visible: showAttachOptions,
                              offset: const Offset(0.2, 0),
                              icon: imagePickerIconsConfig
                                      ?.galleryImagePickerIcon ??
                                  Icon(Icons.image,
                                      color: imagePickerIconsConfig
                                          ?.galleryIconColor),
                              onTap: () => show(context),
                            ),

                          /// ATTACHMENT TOGGLER (rotates)
                        ],
                        if (!isRecordingValue)
                          AnimatedBuilder(
                            animation: rotateAnimation,
                            builder: (_, child) {
                              return Transform.rotate(
                                angle: rotateAnimation.value * 3.14,
                                child: IconButton(
                                  icon: Icon(
                                    showAttachOptions
                                        ? Icons.close
                                        : Icons.attach_file,
                                    color: showAttachOptions
                                        ? Colors.white
                                        : imagePickerIconsConfig
                                            ?.galleryIconColor,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      showAttachOptions = !showAttachOptions;
                                      if (showAttachOptions) {
                                        attachController.forward();
                                      } else {
                                        attachController.reverse();
                                      }
                                    });
                                  },
                                ),
                              );
                            },
                          ),

                        /// VOICE RECORD LOGIC
                        if ((sendMessageConfig?.allowRecordingVoice ?? false) &&
                            !kIsWeb &&
                            (Platform.isIOS || Platform.isAndroid))
                          IconButton(
                            onPressed: (textFieldConfig?.enabled ?? true)
                                ? _recordOrStop
                                : null,
                            icon: (isRecordingValue
                                    ? voiceRecordingConfig?.stopIcon
                                    : voiceRecordingConfig?.micIcon) ??
                                Icon(
                                  isRecordingValue ? Icons.stop : Icons.mic,
                                  color:
                                      voiceRecordingConfig?.recorderIconColor,
                                ),
                          ),

                        /// CANCEL RECORD BUTTON
                        if (isRecordingValue &&
                            cancelRecordConfiguration != null)
                          IconButton(
                            onPressed: () {
                              cancelRecordConfiguration?.onCancel?.call();
                              _cancelRecording();
                            },
                            icon: cancelRecordConfiguration?.icon ??
                                const Icon(Icons.cancel_outlined),
                            color: cancelRecordConfiguration?.iconColor ??
                                voiceRecordingConfig?.recorderIconColor,
                          ),
                      ],
                    );

                    // return Row(
                    //   children: [
                    //     if (!isRecordingValue) ...[
                    //       if (sendMessageConfig?.enableCameraImagePicker ??
                    //           true)
                    //         IconButton(
                    //           constraints: const BoxConstraints(),
                    //           onPressed: (textFieldConfig?.enabled ?? true)
                    //               ? () => _onIconPressed(
                    //                     ImageSource.camera,
                    //                     config: sendMessageConfig
                    //                         ?.imagePickerConfiguration,
                    //                   )
                    //               : null,
                    //           icon: imagePickerIconsConfig
                    //                   ?.cameraImagePickerIcon ??
                    //               Icon(
                    //                 Icons.camera_alt_outlined,
                    //                 color:
                    //                     imagePickerIconsConfig?.cameraIconColor,
                    //               ),
                    //         ),
                    //       if (sendMessageConfig?.enableGalleryImagePicker ??
                    //           true)
                    //         IconButton(
                    //           constraints: const BoxConstraints(),
                    //           onPressed: (textFieldConfig?.enabled ?? true)
                    //               ? () => show(context)
                    //               : null,
                    //           icon: imagePickerIconsConfig
                    //                   ?.galleryImagePickerIcon ??
                    //               Icon(
                    //                 Icons.image,
                    //                 color: imagePickerIconsConfig
                    //                     ?.galleryIconColor,
                    //               ),
                    //         ),
                    //     ],
                    //     if ((sendMessageConfig?.allowRecordingVoice ?? false) &&
                    //         !kIsWeb &&
                    //         (Platform.isIOS || Platform.isAndroid))
                    //       IconButton(
                    //         onPressed: (textFieldConfig?.enabled ?? true)
                    //             ? _recordOrStop
                    //             : null,
                    //         icon: (isRecordingValue
                    //                 ? voiceRecordingConfig?.stopIcon
                    //                 : voiceRecordingConfig?.micIcon) ??
                    //             Icon(
                    //               isRecordingValue ? Icons.stop : Icons.mic,
                    //               color:
                    //                   voiceRecordingConfig?.recorderIconColor,
                    //             ),
                    //       ),
                    //     if (isRecordingValue &&
                    //         cancelRecordConfiguration != null)
                    //       IconButton(
                    //         onPressed: () {
                    //           cancelRecordConfiguration?.onCancel?.call();
                    //           _cancelRecording();
                    //         },
                    //         icon: cancelRecordConfiguration?.icon ??
                    //             const Icon(Icons.cancel_outlined),
                    //         color: cancelRecordConfiguration?.iconColor ??
                    //             voiceRecordingConfig?.recorderIconColor,
                    //       ),
                    //   ],
                    // );
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  FutureOr<void> _cancelRecording() async {
    assert(
      defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android,
      "Voice messages are only supported with android and ios platform",
    );
    if (!isRecording.value) return;
    final path = await controller?.stop();
    if (path == null) {
      isRecording.value = false;
      return;
    }
    final file = File(path);

    if (await file.exists()) {
      await file.delete();
    }

    isRecording.value = false;
  }

  Future<void> _recordOrStop() async {
    assert(
      defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android,
      "Voice messages are only supported with android and ios platform",
    );
    if (!isRecording.value) {
      await controller?.record(
        sampleRate: voiceRecordingConfig?.sampleRate,
        bitRate: voiceRecordingConfig?.bitRate,
        androidEncoder: voiceRecordingConfig?.androidEncoder,
        iosEncoder: voiceRecordingConfig?.iosEncoder,
        androidOutputFormat: voiceRecordingConfig?.androidOutputFormat,
      );
      isRecording.value = true;
    } else {
      final path = await controller?.stop();
      isRecording.value = false;
      widget.onRecordingComplete(path);
    }
  }

  void _onIconPressed(
    ImageSource imageSource, {
    ImagePickerConfiguration? config,
  }) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: imageSource,
        // maxHeight: config?.maxHeight,
        // maxWidth: config?.maxWidth,
        // imageQuality: config?.imageQuality,
        preferredCameraDevice:
            config?.preferredCameraDevice ?? CameraDevice.rear,
      );
      // show(context);
      String? imagePath = image?.path;
      if (config?.onImagePicked != null) {
        String? updatedImagePath = await config?.onImagePicked!(imagePath);
        if (updatedImagePath != null) imagePath = updatedImagePath;
      }

      widget.onImageSelected([
        PickedAssetModel(
          id: image?.name,
          title: image?.name,
          path: imagePath,
          type: "image",
          file: File(image!.path),
        )
      ], '', false);
    } catch (e) {
      print("Error is $e");
      widget.onImageSelected([], e.toString(), false);
    }
  }

  void _onChanged(String inputText) {
    debouncer.run(() {
      composingStatus.value = TypeWriterStatus.typed;
    }, () {
      composingStatus.value = TypeWriterStatus.typing;
    });
    _inputText.value = inputText;
  }

  final ScrollController _scrollController2 = ScrollController();
//show the picker
  void show(BuildContext context) {
    ValueNotifier<bool> isNextButtonVisible = ValueNotifier(false);
    ValueNotifier<bool> isOneTime = ValueNotifier(false);
    List<PickedAssetModel> selectedFiles = <PickedAssetModel>[];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (context) => Stack(
        children: [
          VSMediaPicker(
            maxPickImages: 100,
            gridViewController: _scrollController2,
            singlePick: false,
            onlyImages: false,
            appBarColor: Colors.black,
            gridViewPhysics: const ScrollPhysics(),
            pathList: (path) {
              if (path.isNotEmpty) {
                print("path: ${path.map((e) => e.type).toList()}");
              }
              selectedFiles = path;
              isNextButtonVisible.value = selectedFiles.isNotEmpty;
            },
            appBarLeadingWidget: Padding(
              padding: const EdgeInsets.only(bottom: 15, right: 15),
              child: Align(
                alignment: Alignment.bottomRight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white,
                              width: 1.2,
                            )),
                        child: const Row(
                          children: [
                            Text(
                              'Cancel',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    RepaintBoundary(
                      child: ValueListenableBuilder<bool>(
                        valueListenable: isNextButtonVisible,
                        builder: (context, isVisible, child) {
                          return isVisible
                              ? InkWell(
                                  onTap: () async {
                                    print("Selected files: $selectedFiles");
                                    Navigator.pop(context);
                                    widget.onImageSelected(
                                        selectedFiles, '', isOneTime.value);

                                    // await Navigator.pushReplacement(
                                    //   context,
                                    //   MaterialPageRoute(
                                    //       builder: (context) => FilePreviewPage(
                                    //             files: selectedFiles,
                                    //           )),
                                    // );
                                    // Navigator.pop(context);
                                    // showModalBottomSheet(
                                    //   context: context,
                                    //   isScrollControlled: true,
                                    //   isDismissible: false,
                                    //   enableDrag: false,
                                    //   backgroundColor: Colors.black,
                                    //   builder: (context) =>
                                    //       FlutterStoryEditor(
                                    //     controller: controller,
                                    //     captionController:
                                    //         _captionController,
                                    //     selectedFiles: selectedFiles
                                    //         .map(
                                    //           (e) =>
                                    //               e.file ??
                                    //               File(e.path ?? ""),
                                    //         )
                                    //         .toList(),
                                    //     onSaveClickListener: (files) {
                                    //       // Handle save click logic here
                                    //       print(
                                    //         "Selected files: ${files.map((e) => e.path).toList()}",
                                    //       );
                                    //     },
                                    //   ),
                                    // );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                        color: Colors.blue,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 1.2,
                                        )),
                                    child: const Row(
                                      children: [
                                        Text(
                                          'Next',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.w400),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ValueListenableBuilder(
              valueListenable: isOneTime,
              builder: (context, _isOneTime, child) {
                return Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () {
                      isOneTime.value = !_isOneTime;
                    },
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.95),
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(20),
                        ),
                      ),
                      child: Center(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Checkbox(
                              value: _isOneTime,
                              onChanged: (bool? value) {
                                isOneTime.value = value ?? false;
                              },
                              activeColor: Colors.green,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Send as One Time',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
        ],
      ),
    );
  }

  Widget _buildAnimatedButton({
    required bool visible,
    required Offset offset,
    required Widget icon,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: visible ? 52 : 0,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Transform.translate(
            offset: visible ? Offset.zero : offset,
            child: IconButton(
              constraints: const BoxConstraints(),
              onPressed: visible ? onTap : null,
              icon: icon,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> getLocation() async {
    try {
      final LocationPermission permission =
          await Geolocator.requestPermission();

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: LocationAccuracy.best),
      );

      final String locationString =
          '${position.latitude}|${position.longitude}';

      widget.onLocationSelected?.call(locationString);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: $e')),
      );
    }
  }
}
