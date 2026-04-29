import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';

import 'package:tapa_hike/services/socket.dart';
import 'package:tapa_hike/services/image_upload.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final List<Map<String, dynamic>> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  StreamSubscription? _messageSub;
  bool _loading = true;
  bool _uploading = false;
  File? _pendingImage;

  @override
  void initState() {
    super.initState();

    // Listen for incoming messages
    _messageSub = socketConnection.messageStream.listen((event) {
      if (event is List) {
        // History response
        setState(() {
          _messages.clear();
          _messages.addAll(List<Map<String, dynamic>>.from(event));
          _loading = false;
        });
        _scrollToBottom();
      } else if (event is Map) {
        // Single new message
        setState(() {
          _messages.add(Map<String, dynamic>.from(event));
        });
        _scrollToBottom();
      }
    });

    // Request message history
    socketConnection.sendJson({"endpoint": "getMessages"});
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty && _pendingImage == null) return;

    if (_pendingImage != null) {
      _uploadImageMessage(text);
    } else {
      socketConnection.sendJson({
        "endpoint": "sendMessage",
        "data": {"text": text},
      });
      _textController.clear();
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() {
        _pendingImage = File(picked.path);
      });
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text("Camera"),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text("Galerij"),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _clearPendingImage() {
    setState(() {
      _pendingImage = null;
    });
  }

  Future<void> _uploadImageMessage(String text) async {
    if (_pendingImage == null) return;
    final file = _pendingImage!;

    setState(() {
      _uploading = true;
    });

    try {
      await uploadMessageImage(file, text: text);
      _textController.clear();
      _clearPendingImage();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Upload mislukt: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Berichten"),
      ),
      body: Column(
        children: [
          // Message list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(
                        child: Text(
                          "Nog geen berichten",
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          return _MessageBubble(
                            message: _messages[index],
                            scheme: scheme,
                          );
                        },
                      ),
          ),

          // Image preview bar
          if (_pendingImage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                border: Border(
                  top: BorderSide(color: scheme.outlineVariant),
                ),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _pendingImage!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Afbeelding geselecteerd",
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _clearPendingImage,
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: "Verwijder afbeelding",
                  ),
                ],
              ),
            ),

          // Input bar
          Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border(
                top: BorderSide(color: scheme.outlineVariant),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: "Typ een bericht…",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: scheme.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        suffixIcon: IconButton(
                          onPressed:
                              _uploading ? null : _showImageSourceSheet,
                          icon: const Icon(Icons.camera_alt, size: 22),
                          tooltip: "Foto toevoegen",
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _uploading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton.filled(
                          onPressed: _sendMessage,
                          icon: const Icon(Icons.send),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final ColorScheme scheme;

  const _MessageBubble({required this.message, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final isOrg = message["isOrganisation"] == true;
    final from = message["from"] as String? ?? "";
    final text = message["text"] as String? ?? "";
    final timeStr = message["time"] as String? ?? "";
    final imageUrl = message["imageUrl"] as String?;

    // Parse time for display
    String formattedTime = "";
    try {
      final dt = DateTime.parse(timeStr).toLocal();
      formattedTime =
          "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (_) {}

    // Build the full image URL (relative URLs need server prefix)
    String? fullImageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      if (imageUrl.startsWith("http")) {
        fullImageUrl = imageUrl;
      } else {
        fullImageUrl = "http://$domain$imageUrl";
      }
    }

    // Organisation messages on the left, own messages on the right
    final alignment =
        isOrg ? CrossAxisAlignment.start : CrossAxisAlignment.end;
    final bubbleColor =
        isOrg ? scheme.primaryContainer : scheme.secondaryContainer;
    final textColor =
        isOrg ? scheme.onPrimaryContainer : scheme.onSecondaryContainer;
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isOrg ? 4 : 16),
      bottomRight: Radius.circular(isOrg ? 16 : 4),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          // Sender label
          Padding(
            padding: const EdgeInsets.only(bottom: 2, left: 4, right: 4),
            child: Text(
              from,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isOrg ? scheme.primary : scheme.secondary,
              ),
            ),
          ),
          // Bubble
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: borderRadius,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Image
                if (fullImageUrl != null)
                  GestureDetector(
                    onTap: () => _openImageViewer(context, fullImageUrl!),
                    child: ClipRRect(
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft:
                            text.isEmpty ? Radius.circular(isOrg ? 4 : 16) : Radius.zero,
                        bottomRight:
                            text.isEmpty ? Radius.circular(isOrg ? 16 : 4) : Radius.zero,
                      ),
                      child: Image.network(
                        fullImageUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            height: 150,
                            alignment: Alignment.center,
                            child: CircularProgressIndicator(
                              value: progress.expectedTotalBytes != null
                                  ? progress.cumulativeBytesLoaded /
                                      progress.expectedTotalBytes!
                                  : null,
                              strokeWidth: 2,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stack) => Container(
                          height: 100,
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image, size: 32),
                        ),
                      ),
                    ),
                  ),
                // Text + time
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (text.isNotEmpty)
                        Text(
                          text,
                          style: TextStyle(color: textColor, fontSize: 15),
                        ),
                      if (text.isNotEmpty) const SizedBox(height: 2),
                      Text(
                        formattedTime,
                        style: TextStyle(
                          fontSize: 10,
                          color: textColor.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openImageViewer(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenImage(imageUrl: imageUrl),
      ),
    );
  }
}

/// Full-screen image viewer with pinch-to-zoom using photo_view.
class _FullScreenImage extends StatelessWidget {
  final String imageUrl;

  const _FullScreenImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: PhotoView(
        imageProvider: NetworkImage(imageUrl),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 3,
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        loadingBuilder: (context, event) => Center(
          child: CircularProgressIndicator(
            value: event?.expectedTotalBytes != null
                ? event!.cumulativeBytesLoaded / event.expectedTotalBytes!
                : null,
          ),
        ),
        errorBuilder: (context, error, stack) => const Center(
          child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
        ),
      ),
    );
  }
}
