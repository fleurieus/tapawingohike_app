import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;

  AudioPlayerWidget({required this.audioUrl});

  @override
  _AudioPlayerWidgetState createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late AudioPlayer _audioPlayer;
  ConcatenatingAudioSource _audioSource = ConcatenatingAudioSource(children: []);

  @override
  void initState() {
    super.initState();
    _initAudioPlayer();
  }

  void _initAudioPlayer() async {
    _audioPlayer = AudioPlayer();

    // Load the audio source
    _audioSource.add(AudioSource.uri(Uri.parse(widget.audioUrl)));

    await _audioPlayer.setAudioSource(_audioSource);

    _audioPlayer.playbackEventStream.listen((event) {
      // Update the player state based on the event
      if (mounted) {
        setState(() {
          // Handle playback events here
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

@override
Widget build(BuildContext context) {
  return SafeArea(
    child: Row(
      children: [
        Expanded(
          flex: 1,
          child: IconButton(
            onPressed: () {
              if (_audioPlayer.playing) {
                _audioPlayer.pause();
              } else {
                _audioPlayer.play();
              }
            },
            icon: Icon(
              _audioPlayer.playing
                  ? Icons.pause
                  : Icons.play_arrow,
              color: Colors.white,
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: StreamBuilder<Duration?>(
            stream: _audioPlayer.positionStream, // Use the positionStream
            builder: (context, snapshot) {
              final position = snapshot.data ?? Duration.zero;

              return StreamBuilder<Duration?>(
                stream: _audioPlayer.durationStream, // Use the durationStream
                builder: (context, snapshot) {
                  final duration = snapshot.data ?? Duration.zero;

                  return Slider(
                    value: position.inSeconds.toDouble(),
                    min: 0.0,
                    max: duration.inSeconds.toDouble(),
                    onChanged: (double value) {
                      _audioPlayer.seek(Duration(seconds: value.toInt()));
                    },
                  );
                },
              );
            },
          ),

        )
      ],
    ),
  );
}

}
