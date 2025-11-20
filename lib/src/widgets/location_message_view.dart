import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:chatview/src/extensions/extensions.dart';
import 'package:chatview/src/models/models.dart';

import '../utils/constants/constants.dart';
import 'reaction_widget.dart';

class LocationMessageView extends StatelessWidget {
  const LocationMessageView({
    Key? key,
    required this.isMessageBySender,
    required this.message,
    this.chatBubbleMaxWidth,
    this.inComingChatBubbleConfig,
    this.outgoingChatBubbleConfig,
    this.messageReactionConfig,
    this.highlightMessage = false,
    this.highlightColor,
  }) : super(key: key);

  /// Represents current message is sent by current user.
  final bool isMessageBySender;

  /// Provides message instance of chat.
  final Message message;

  /// Allow users to give max width of chat bubble.
  final double? chatBubbleMaxWidth;

  /// Provides configuration of chat bubble appearance from other user of chat.
  final ChatBubble? inComingChatBubbleConfig;

  /// Provides configuration of chat bubble appearance from current user of chat.
  final ChatBubble? outgoingChatBubbleConfig;

  /// Provides configuration of reaction appearance in chat bubble.
  final MessageReactionConfiguration? messageReactionConfig;

  /// Represents message should highlight.
  final bool highlightMessage;

  /// Allow user to set color of highlighted message.
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    // Parse location data from message: "latitude,longitude,address"
    final parts = message.message.split('|');
    if (parts.length < 2) {
      return _buildErrorBubble();
    }

    final latitude = double.tryParse(parts[0]);
    final longitude = double.tryParse(parts[1]);
    final address = parts.length > 2 ? parts[2] : 'Location';

    if (latitude == null || longitude == null) {
      return _buildErrorBubble();
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: () => _openMaps(latitude, longitude, address),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: chatBubbleMaxWidth ??
                  MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              color: highlightMessage ? highlightColor : _color,
              borderRadius: _borderRadius,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                /// Map Preview
                ClipRRect(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: Container(
                    width: 250,
                    height: 180,
                    color: Colors.grey.shade300,
                    child: Stack(
                      children: [
                        FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(latitude, longitude),
                            initialZoom: 16,
                            interactionOptions: const InteractionOptions(
                              flags: ~InteractiveFlag.all,
                            ),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.example.app',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(latitude, longitude),
                                  width: 40,
                                  height: 40,
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Colors.red,
                                    size: 32,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        /// Tap hint overlay
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Tap to open',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                /// Address text
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$latitude, $longitude',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        /// Reactions
        if (message.reaction.reactions.isNotEmpty)
          ReactionWidget(
            key: key,
            isMessageBySender: isMessageBySender,
            reaction: message.reaction,
            messageReactionConfig: messageReactionConfig,
          ),

        /// Timestamp
        if (message.createdAt != null)
          Positioned(
            bottom: 5,
            right: 16,
            child: Text(
              "${TimeOfDay.fromDateTime(message.createdAt).format(context)}",
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildErrorBubble() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade400,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Invalid location data',
        style: TextStyle(color: Colors.white),
      ),
    );
  }

  Future<void> _openMaps(
      double latitude, double longitude, String address) async {
    final mapsUrl = 'https://maps.google.com/?q=$latitude,$longitude';

    try {
      // Try to launch Google Maps app first, fallback to web
      if (await canLaunchUrl(
          Uri.parse('google.navigation:q=$latitude,$longitude'))) {
        await launchUrl(
          Uri.parse('google.navigation:q=$latitude,$longitude'),
          mode: LaunchMode.externalApplication,
        );
      } else {
        // Fallback to web
        await launchUrl(
          Uri.parse(mapsUrl),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      print('Could not launch maps: $e');
    }
  }

  BorderRadiusGeometry get _borderRadius =>
      BorderRadius.circular(replyBorderRadius1);

  Color get _color => isMessageBySender
      ? outgoingChatBubbleConfig?.color ?? Colors.purple
      : inComingChatBubbleConfig?.color ?? Colors.grey.shade500;
}
