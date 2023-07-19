import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;

  AudioPlayerWidget({required this.audioUrl});

  @override
  _AudioPlayerWidgetState createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late AudioPlayer _audioPlayer;
  AudioPlayerState _audioPlayerState = AudioPlayerState.STOPPED;
  Duration _duration = Duration();
  Duration _position = Duration();

  @override
  void initState() {
    super.initState();
    _initAudioPlayer();
  }

  void _initAudioPlayer() {
    _audioPlayer = AudioPlayer();
    _audioPlayer.onPlayerStateChanged.listen((AudioPlayerState state) {
      if (mounted) {
        setState(() {
          _audioPlayerState = state;
        });
      }
    });
    _audioPlayer.onDurationChanged.listen((Duration duration) {
      if (mounted) {
        setState(() {
          _duration = duration;
        });
      }
    });
    _audioPlayer.onAudioPositionChanged.listen((Duration position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.release();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: IconButton(
                onPressed: () {
                  if (_audioPlayerState == AudioPlayerState.PLAYING) {
                    _audioPlayer.pause();
                  } else {
                    _audioPlayer.play(widget.audioUrl);
                  }
                },
                icon: Icon(
                  _audioPlayerState == AudioPlayerState.PLAYING
                      ? Icons.pause
                      : Icons.play_arrow,
                  color: Colors.white,
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Slider(
                value: _position.inSeconds.toDouble(),
                min: 0.0,
                max: _duration.inSeconds.toDouble(),
                onChanged: (double value) {
                  if (mounted) {
                    setState(() {
                      _audioPlayer.seek(Duration(seconds: value.toInt()));
                    });
                  }
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
