import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;

  const AudioPlayerWidget({super.key, required this.audioUrl});

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late final AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
    _initAudioPlayer();
  }

  Future<void> _initAudioPlayer() async {
    _audioPlayer = AudioPlayer();
    try {
      await _audioPlayer.setAudioSource(
        AudioSource.uri(Uri.parse(widget.audioUrl)),
      );
    } catch (_) {
      // Je kunt hier desgewenst een snackbar of log opnemen
    }

    // Eventueel state updates luisteren (optioneel)
    _audioPlayer.playbackEventStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Donkere panelkleur forceren (ook in licht thema), maar wel thematisch:
    // In dark mode: gebruik een hoge surface container.
    // In light mode: meng een zwarte overlay over de surface voor voldoende contrast.
    final bool isDark = theme.brightness == Brightness.dark;
    final Color panelColor = isDark
        ? scheme.surfaceContainerHighest
        : Color.alphaBlend(Colors.black.withOpacity(0.72), scheme.surface);

    // Tekstkleur op het paneel (wit in light mode vanwege donkere panelkleur)
    final Color onPanelColor = isDark ? scheme.onSurface : Colors.white;

    return SafeArea(
      top: false,
      bottom: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: panelColor,
          boxShadow: kElevationToShadow[1],
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () async {
                if (_audioPlayer.playing) {
                  await _audioPlayer.pause();
                } else {
                  await _audioPlayer.play();
                }
                if (mounted) setState(() {});
              },
              icon: Icon(_audioPlayer.playing ? Icons.pause : Icons.play_arrow),
              color: onPanelColor,
            ),
            Expanded(
              child: StreamBuilder<Duration?>(
                stream: _audioPlayer.durationStream,
                builder: (context, durationSnap) {
                  final duration = durationSnap.data ?? Duration.zero;

                  return StreamBuilder<Duration>(
                    stream: _audioPlayer.positionStream,
                    builder: (context, positionSnap) {
                      final position = positionSnap.data ?? Duration.zero;

                      final double max =
                          duration.inMilliseconds > 0 ? duration.inMilliseconds.toDouble() : 1.0;
                      final double value = position.inMilliseconds
                          .clamp(0, duration.inMilliseconds)
                          .toDouble();

                      return SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: onPanelColor,
                            inactiveTrackColor: onPanelColor.withValues(alpha: 0.35),
                            thumbColor: onPanelColor,
                            overlayColor: onPanelColor.withValues(alpha: 0.15),
                          ),
                        child: Slider(
                          value: value,
                          min: 0.0,
                          max: max,
                          onChanged: duration == Duration.zero
                              ? null
                              : (double v) {
                                  _audioPlayer.seek(Duration(milliseconds: v.toInt()));
                                },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
