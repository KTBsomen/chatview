import 'package:chatview/chatview.dart';
import 'package:example/data.dart';
import 'package:example/models/theme.dart';
import 'package:example/zoomableImagePopup.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const Example());
}

class Example extends StatelessWidget {
  const Example({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Chat UI Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xffEE5366),
        colorScheme:
            ColorScheme.fromSwatch(accentColor: const Color(0xffEE5366)),
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  AppTheme theme = LightTheme();
  bool isDarkTheme = false;
  final ScrollController _scrollController = ScrollController();

  late ChatController _chatController;

// Hook scroll listener to load older/newer messages

  void _showHideTypingIndicator() {
    _chatController.setTypingIndicator = !_chatController.showTypingIndicator;
  }

  bool _isLoadingOlder = false;
  bool _isLoadingNewer = false;
  final List<Message> _visibleMessages = [];

  // Window configuration
  final int _windowSize = 50; // Number of messages to keep in memory
  final int _fetchThreshold = 15; // When to fetch more messages

  // Pagination tracking
  final int _oldestVisibleId = -1; // Database ID of oldest message in view
  final int _newestVisibleId = -1; // Database ID of newest message in view
  final int _totalMessageCount = 0; // Total count in database

  final bool _isAtNewestMessages = true;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _chatController = ChatController(
      onReaction: (n) {
        /// Do with reaction
        debugPrint('Reaction');
      },
      onReactionRemoved: (message) {
        /// Do with reaction removed
        debugPrint('Reaction Removed');
      },
      initialMessageList: Data.messageList,
      scrollController: _scrollController,
      currentUser: ChatUser(
        id: '1',
        name: 'Flutter',
        profilePhoto: Data.profileImage.value,
      ),
      otherUsers: [
        ChatUser(
          id: '2',
          name: 'Simform',
          profilePhoto: Data.profileImage.value,
        ),
        ChatUser(
          id: '3',
          name: 'Jhon',
          profilePhoto: Data.profileImage.value,
        ),
        ChatUser(
          id: '4',
          name: 'Mike',
          profilePhoto: Data.profileImage.value,
        ),
        ChatUser(
          id: '5',
          name: 'Rich',
          profilePhoto: Data.profileImage.value,
        ),
      ],
    );
// Configuration variables

    _chatController.scrollToLastMessage();
  }

  void receiveMessage() async {
    _chatController.addMessage(
      Message(
        id: DateTime.now().toString(),
        message: 'I will schedule the meeting.',
        createdAt: DateTime.now(),
        sentBy: '2',
        uploadProgress: ValueNotifier<double>(1.0),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 500));
    _chatController.addReplySuggestions([
      const SuggestionItemData(text: 'Thanks.'),
      const SuggestionItemData(text: 'Thank you very much.'),
      const SuggestionItemData(text: 'Great.')
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ChatView(
        isLastPage: false,
        chatController: _chatController,
        onSendTap: _onSendTap,
        loadMoreData: () async {
          if (_isLoadingNewer) return;
          _isLoadingNewer = true;
          Future.delayed(const Duration(seconds: 2), () {
            print('Load more data');
            for (var i = 0; i < 100; i++) {
              _chatController.initialMessageList.insert(
                0,
                Message(
                  id: DateTime.now().toString(),
                  message: 'Hello $i',
                  createdAt: DateTime.now(),
                  sentBy: '2',
                  uploadProgress: ValueNotifier<double>(1.0),
                ),
              );
            }
            _chatController.messageStreamController.add(
              _chatController.initialMessageList,
            );
            _isLoadingNewer = false;
          });
        },
        loadPreviousData: () async {
          if (_isLoadingOlder) return;
          _isLoadingOlder = true;
          Future.delayed(const Duration(seconds: 2), () {
            _isLoadingOlder = false;
            print('Load previous data');
          });
        },
        loadingWidget: const Center(
          child: CircularProgressIndicator(),
        ),
        featureActiveConfig: const FeatureActiveConfig(
            lastSeenAgoBuilderVisibility: true,
            receiptsBuilderVisibility: true,
            enableScrollToBottomButton: true,
            enablePagination: true),
        scrollToBottomButtonConfig: ScrollToBottomButtonConfig(
          backgroundColor: theme.textFieldBackgroundColor,
          border: Border.all(
            color: isDarkTheme ? Colors.transparent : Colors.grey,
          ),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: theme.themeIconColor,
            weight: 10,
            size: 30,
          ),
        ),
        chatViewState: ChatViewState.hasMessages,
        chatViewStateConfig: ChatViewStateConfiguration(
          loadingWidgetConfig: ChatViewStateWidgetConfiguration(
            loadingIndicatorColor: theme.outgoingChatBubbleColor,
          ),
          onReloadButtonTap: () {},
        ),
        typeIndicatorConfig: TypeIndicatorConfiguration(
          flashingCircleBrightColor: theme.flashingCircleBrightColor,
          flashingCircleDarkColor: theme.flashingCircleDarkColor,
        ),
        appBar: ChatViewAppBar(
          elevation: theme.elevation,
          backGroundColor: theme.appBarColor,
          profilePicture: Data.profileImage.value,
          backArrowColor: theme.backArrowColor,
          chatTitle: "Chat view",
          chatTitleTextStyle: TextStyle(
            color: theme.appBarTitleTextStyle,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: 0.25,
          ),
          userStatus: "online",
          userStatusTextStyle: const TextStyle(color: Colors.grey),
          actions: [
            IconButton(
              onPressed: _onThemeIconTap,
              icon: Icon(
                isDarkTheme
                    ? Icons.brightness_4_outlined
                    : Icons.dark_mode_outlined,
                color: theme.themeIconColor,
              ),
            ),
            IconButton(
              tooltip: 'Toggle TypingIndicator',
              onPressed: _showHideTypingIndicator,
              icon: Icon(
                Icons.keyboard,
                color: theme.themeIconColor,
              ),
            ),
            IconButton(
              tooltip: 'Simulate Message receive',
              onPressed: receiveMessage,
              icon: Icon(
                Icons.supervised_user_circle,
                color: theme.themeIconColor,
              ),
            ),
          ],
        ),
        chatBackgroundConfig: ChatBackgroundConfiguration(
          messageTimeIconColor: theme.messageTimeIconColor,
          messageTimeTextStyle: TextStyle(color: theme.messageTimeTextColor),
          defaultGroupSeparatorConfig: DefaultGroupSeparatorConfiguration(
            textStyle: TextStyle(
              color: theme.chatHeaderColor,
              fontSize: 17,
            ),
          ),
          backgroundColor: theme.backgroundColor,
        ),
        sendMessageConfig: SendMessageConfiguration(
          imagePickerIconsConfig: ImagePickerIconsConfiguration(
            cameraIconColor: theme.cameraIconColor,
            galleryIconColor: theme.galleryIconColor,
          ),
          replyMessageColor: theme.replyMessageColor,
          defaultSendButtonColor: theme.sendButtonColor,
          replyDialogColor: theme.replyDialogColor,
          replyTitleColor: theme.replyTitleColor,
          textFieldBackgroundColor: theme.textFieldBackgroundColor,
          closeIconColor: theme.closeIconColor,
          textFieldConfig: TextFieldConfiguration(
            onMessageTyping: (status) {
              /// Do with status
              debugPrint(status.toString());
            },
            compositionThresholdTime: const Duration(seconds: 1),
            textStyle: TextStyle(color: theme.textFieldTextColor),
          ),
          micIconColor: theme.replyMicIconColor,
          voiceRecordingConfiguration: VoiceRecordingConfiguration(
            backgroundColor: theme.waveformBackgroundColor,
            recorderIconColor: theme.recordIconColor,
            waveStyle: WaveStyle(
              showMiddleLine: false,
              waveColor: theme.waveColor ?? Colors.white,
              extendWaveform: true,
            ),
          ),
        ),
        chatBubbleConfig: ChatBubbleConfiguration(
          outgoingChatBubbleConfig: ChatBubble(
            linkPreviewConfig: LinkPreviewConfiguration(
              backgroundColor: theme.linkPreviewOutgoingChatColor,
              bodyStyle: theme.outgoingChatLinkBodyStyle,
              titleStyle: theme.outgoingChatLinkTitleStyle,
            ),
            receiptsWidgetConfig:
                const ReceiptsWidgetConfig(showReceiptsIn: ShowReceiptsIn.all),
            color: theme.outgoingChatBubbleColor,
          ),
          inComingChatBubbleConfig: ChatBubble(
            linkPreviewConfig: LinkPreviewConfiguration(
              linkStyle: TextStyle(
                color: theme.inComingChatBubbleTextColor,
                decoration: TextDecoration.underline,
              ),
              backgroundColor: theme.linkPreviewIncomingChatColor,
              bodyStyle: theme.incomingChatLinkBodyStyle,
              titleStyle: theme.incomingChatLinkTitleStyle,
            ),
            textStyle: TextStyle(color: theme.inComingChatBubbleTextColor),
            onMessageRead: (message) {
              /// send your message reciepts to the other client
              debugPrint('Message Read');
              message.setStatus = MessageStatus.read;
            },
            senderNameTextStyle:
                TextStyle(color: theme.inComingChatBubbleTextColor),
            color: theme.inComingChatBubbleColor,
          ),
        ),
        replyPopupConfig: ReplyPopupConfiguration(
          backgroundColor: theme.replyPopupColor,
          buttonTextStyle: TextStyle(color: theme.replyPopupButtonColor),
          topBorderColor: theme.replyPopupTopBorderColor,
        ),
        reactionPopupConfig: ReactionPopupConfiguration(
          shadow: BoxShadow(
            color: isDarkTheme ? Colors.black54 : Colors.grey.shade400,
            blurRadius: 20,
          ),
          backgroundColor: theme.reactionPopupColor,
        ),
        messageConfig: MessageConfiguration(
          messageReactionConfig: MessageReactionConfiguration(
            backgroundColor: theme.messageReactionBackGroundColor,
            borderColor: theme.messageReactionBackGroundColor,
            reactedUserCountTextStyle:
                TextStyle(color: theme.inComingChatBubbleTextColor),
            reactionCountTextStyle:
                TextStyle(color: theme.inComingChatBubbleTextColor),
            reactionsBottomSheetConfig: ReactionsBottomSheetConfiguration(
              backgroundColor: theme.backgroundColor,
              reactedUserTextStyle: TextStyle(
                color: theme.inComingChatBubbleTextColor,
              ),
              reactionWidgetDecoration: BoxDecoration(
                color: theme.inComingChatBubbleColor,
                boxShadow: [
                  BoxShadow(
                    color: isDarkTheme ? Colors.black12 : Colors.grey.shade200,
                    offset: const Offset(0, 20),
                    blurRadius: 40,
                  )
                ],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          imageMessageConfig: ImageMessageConfiguration(
            onTap: (message) {
              Navigator.of(context).push(
                PageRouteBuilder(
                  opaque: false,
                  barrierDismissible: true,
                  pageBuilder: (BuildContext context, _, __) {
                    return ZoomableImagePopup(
                      imageUrl: message.message,
                      // onEdit: () => _editgroup(context),
                      onClose: () => Navigator.of(context).pop(),
                    );
                  },
                ),
              );
            },
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
            shareIconConfig: ShareIconConfiguration(
              defaultIconBackgroundColor: theme.shareIconBackgroundColor,
              defaultIconColor: theme.shareIconColor,
            ),
          ),
        ),
        profileCircleConfig: ProfileCircleConfiguration(
          profileImageUrl: Data.profileImage,
        ),
        repliedMessageConfig: RepliedMessageConfiguration(
          backgroundColor: theme.repliedMessageColor,
          verticalBarColor: theme.verticalBarColor,
          repliedMsgAutoScrollConfig: RepliedMsgAutoScrollConfig(
            enableHighlightRepliedMsg: true,
            highlightColor: Colors.pinkAccent.shade100,
            highlightScale: 1.1,
          ),
          textStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.25,
          ),
          replyTitleTextStyle: TextStyle(color: theme.repliedTitleTextColor),
        ),
        swipeToReplyConfig: SwipeToReplyConfiguration(
          replyIconColor: theme.swipeToReplyIconColor,
        ),
        replySuggestionsConfig: ReplySuggestionsConfig(
          itemConfig: SuggestionItemConfig(
            decoration: BoxDecoration(
              color: theme.textFieldBackgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.outgoingChatBubbleColor ?? Colors.white,
              ),
            ),
            textStyle: TextStyle(
              color: isDarkTheme ? Colors.white : Colors.black,
            ),
          ),
          onTap: (item) => _onSendTap(
              [item.text], const ReplyMessage(), MessageType.text, false),
        ),
      ),
    );
  }

  void _onSendTap(List<String> message, ReplyMessage replyMessage,
      MessageType messageType, bool isOneTime) {
    for (var element in message) {
      _chatController.addMessage(
        Message(
          id: DateTime.now().toString(),
          createdAt: DateTime.now(),
          message: element,
          sentBy: _chatController.currentUser.id,
          replyMessage: replyMessage,
          messageType: messageType,
          uploadProgress: ValueNotifier<double>(1.0),
        ),
      );
    }

    Future.delayed(const Duration(milliseconds: 3000), () {
      _chatController.initialMessageList.last.setStatus =
          MessageStatus.undelivered;
    });
    Future.delayed(const Duration(seconds: 1), () {
      _chatController.initialMessageList.last.setStatus = MessageStatus.read;
    });
  }

  void _onThemeIconTap() {
    setState(() {
      if (isDarkTheme) {
        theme = LightTheme();
        isDarkTheme = false;
      } else {
        theme = DarkTheme();
        isDarkTheme = true;
      }
    });
  }
}
