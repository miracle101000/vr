import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:m3u8_downloader/m3u8_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vr_player/vr_player.dart';

class VideoPlayerPage extends StatefulWidget {
  const VideoPlayerPage({super.key});

  @override
  _VideoPlayerPageState createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage>
    with TickerProviderStateMixin {
  ReceivePort _port = ReceivePort();
  String? _downloadingUrl;
  String? _printData;

  // 未加密的url地址（喜羊羊与灰太狼之决战次时代）
  String url1 = "http://playertest.longtailvideo.com/adaptive/wowzaid3/playlist.m3u8";
  // 加密的url地址（火影忍者疾风传）
  String url2 = "https://v3.dious.cc/20201116/SVGYv7Lo/index.m3u8";
  late VrPlayerController _viewPlayerController;
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isShowingBar = false;
  bool _isPlaying = false;
  bool _isFullScreen = false;
  bool _isVideoFinished = false;
  bool _isLandscapeOrientation = false;
  bool _isVolumeSliderShown = false;
  bool _isVolumeEnabled = true;
  late double _playerWidth;
  late double _playerHeight;
  String? _duration;
  int? _intDuration;
  bool isVideoLoading = false;
  bool isVideoReady = false;
  String? _currentPosition;
  double _currentSliderValue = 0.1;
  double _seekPosition = 0;
  double x = 0;
  double y = 0;
  String? path;
  @override
  void initState() {
    super.initState();
    _animationController =
        AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _animation = Tween<double>(begin: 0, end: 1).animate(_animationController);
    _toggleShowingBar();
    initAsync();
  }

  void _toggleShowingBar() {
    switchVolumeSliderDisplay(show: false);
    _isShowingBar = !_isShowingBar;
    if (_isShowingBar) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    _playerWidth = MediaQuery.of(context).size.width;
    _playerHeight =
        _isFullScreen ? MediaQuery.of(context).size.height : _playerWidth / 2;
    _isLandscapeOrientation =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
        // appBar: AppBar(
        //   title: const Text('VR Player'),
        // ),
        body: GestureDetector(
      onTap: _toggleShowingBar,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: <Widget>[
          VrPlayer(
            x: 0,
            y: 0,
            onCreated: onViewPlayerCreated,
            width: _playerWidth,
            height: _playerHeight,
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _animation,
              child: ColoredBox(
                color: Colors.black,
                child: Row(
                  children: <Widget>[
                    IconButton(
                      icon: Icon(
                        _isVideoFinished
                            ? Icons.replay
                            : _isPlaying
                                ? Icons.pause
                                : Icons.play_arrow,
                        color: Colors.white,
                      ),
                      onPressed: playAndPause,
                    ),
                    Text(
                      _currentPosition?.toString() ?? '00:00',
                      style: const TextStyle(color: Colors.white),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: Colors.amberAccent,
                          inactiveTrackColor: Colors.grey,
                          trackHeight: 5,
                          thumbColor: Colors.white,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 8,
                          ),
                          overlayColor: Colors.purple.withAlpha(32),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 14,
                          ),
                        ),
                        child: Slider(
                          value: _seekPosition,
                          max: _intDuration?.toDouble() ?? 0,
                          onChangeEnd: (value) {
                            _viewPlayerController.seekTo(value.toInt());
                          },
                          onChanged: (value) {
                            onChangePosition(value.toInt());
                          },
                        ),
                      ),
                    ),
                    Text(
                      _duration?.toString() ?? '99:99',
                      style: const TextStyle(color: Colors.white),
                    ),
                    if (_isFullScreen || _isLandscapeOrientation)
                      IconButton(
                        icon: Icon(
                          _isVolumeEnabled
                              ? Icons.volume_up_rounded
                              : Icons.volume_off_rounded,
                          color: Colors.white,
                        ),
                        onPressed: () => switchVolumeSliderDisplay(show: true),
                      ),
                    IconButton(
                      icon: Icon(
                        _isFullScreen
                            ? Icons.fullscreen_exit
                            : Icons.fullscreen,
                        color: Colors.white,
                      ),
                      onPressed: fullScreenPressed,
                    ),
                    // if (_isFullScreen)
                    IconButton(
                      icon: const Icon(
                        Icons.card_giftcard,
                        color: Colors.white,
                      ),
                      onPressed: cardBoardPressed,
                    )
                    // else
                    //   Container(),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            height: 180,
            right: 4,
            top: MediaQuery.of(context).size.height / 4,
            child: _isVolumeSliderShown
                ? RotatedBox(
                    quarterTurns: 3,
                    child: Slider(
                      value: _currentSliderValue,
                      divisions: 10,
                      onChanged: onChangeVolumeSlider,
                    ),
                  )
                : const SizedBox(),
          ),
        ],
      ),
    ));
  }

  void cardBoardPressed() {
    _viewPlayerController.toggleVRMode();
  }

  Future<void> fullScreenPressed() async {
    await _viewPlayerController.fullScreen();
    setState(() {
      _isFullScreen = !_isFullScreen;
    });

    if (_isFullScreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeRight,
        DeviceOrientation.landscapeLeft,
      ]);
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: [],
      );
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeRight,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    }
  }

  Future<void> playAndPause() async {
    if (_isVideoFinished) {
      await _viewPlayerController.seekTo(0);
    }

    if (_isPlaying) {
      await _viewPlayerController.pause();
    } else {
      await _viewPlayerController.play();
    }

    setState(() {
      _isPlaying = !_isPlaying;
      _isVideoFinished = false;
    });
  }

  void onViewPlayerCreated(
    VrPlayerController controller,
    VrPlayerObserver observer,
  ) {
    _viewPlayerController = controller;
    observer
      ..onStateChange = onReceiveState
      ..onDurationChange = onReceiveDuration
      ..onPositionChange = onChangePosition
      ..onFinishedChange = onReceiveEnded;
    _viewPlayerController.loadVideo(
        videoUrl: "http://playertest.longtailvideo.com/adaptive/wowzaid3/playlist.m3u8",
        // videoPath:
            // '/storage/emulated/0/Android/data/com.example.vr/files/vPlayDownload/784cbe80d5a984ba6e420cd52ef80ff0.mp4'
            
            );
  }

  void onReceiveState(VrState state) {
    switch (state) {
      case VrState.loading:
        setState(() {
          isVideoLoading = true;
        });
        break;
      case VrState.ready:
        setState(() {
          isVideoLoading = false;
          isVideoReady = true;
        });
        break;
      case VrState.buffering:
      case VrState.idle:
        break;
    }
  }

  void onReceiveDuration(int millis) {
    setState(() {
      _intDuration = millis;
      _duration = millisecondsToDateTime(millis);
    });
  }

  void onChangePosition(int millis) {
    setState(() {
      _currentPosition = millisecondsToDateTime(millis);
      _seekPosition = millis.toDouble();
    });
  }

  // ignore: avoid_positional_boolean_parameters
  void onReceiveEnded(bool isFinished) {
    setState(() {
      _isVideoFinished = isFinished;
    });
  }

  void onChangeVolumeSlider(double value) {
    _viewPlayerController.setVolume(value);
    setState(() {
      _isVolumeEnabled = value != 0;
      _currentSliderValue = value;
    });
  }

  void switchVolumeSliderDisplay({required bool show}) {
    setState(() {
      _isVolumeSliderShown = show;
    });
  }

  String millisecondsToDateTime(int milliseconds) =>
      setDurationText(Duration(milliseconds: milliseconds));

  String setDurationText(Duration duration) {
    String twoDigits(int n) {
      if (n >= 10) return '$n';
      return '0$n';
    }

    final twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    final twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds';
  }

  void initAsync() async {
    String saveDir = await _findSavePath();

    M3u8Downloader.config(
        saveDir: saveDir, threadCount: 2, convertMp4: true, debugMode: true);
    // 注册监听器
    IsolateNameServer.registerPortWithName(
        _port.sendPort, 'downloader_send_port');
    _port.listen((dynamic data) {
      // Result of data

      setState(() {
        _printData = 'mm$data';
      });

      print(_printData);
    });

    _checkPermission().then((hasGranted) async {
      if (hasGranted) {
        // await M3u8Downloader.config(
        //   convertMp4: true,
        // );

        await M3u8Downloader.initialize(onSelect: () async {
          print('下载成功点击');
          return null;
        });
        setState(() {
          _downloadingUrl = url1;
        });
        M3u8Downloader.download(
            url: url1,
            name: "nameoffiledd",
            progressCallback: progressCallback,
            successCallback: successCallback,
            errorCallback: errorCallback);
      }
    });
  }

  Future<bool> _checkPermission() async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }
    return status.isGranted;
  }

  Future<String> _findSavePath() async {
    final directory = Platform.isAndroid
        ? await getExternalStorageDirectory()
        : await getApplicationDocumentsDirectory();
    String saveDir = '${directory!.path}/vPlayDownload';
    Directory root = Directory(saveDir);
    if (!root.existsSync()) {
      await root.create();
    }
    print(saveDir);
    return saveDir;
  }

  @pragma('vm:entry-point')
  static progressCallback(dynamic args) {
    final SendPort? send =
        IsolateNameServer.lookupPortByName('downloader_send_port');
    if (send != null) {
      args["status"] = 1;
      send.send(args);
    }
  }

  @pragma('vm:entry-point')
  static successCallback(dynamic args) {
    final SendPort? send =
        IsolateNameServer.lookupPortByName('downloader_send_port');
    if (send != null) {
      send.send({
        "status": 2,
        "url": args["url"],
        "filePath": args["filePath"],
        "dir": args["dir"]
      });
    }
  }

  @pragma('vm:entry-point')
  static errorCallback(dynamic args) {
    final SendPort? send =
        IsolateNameServer.lookupPortByName('downloader_send_port');
    if (send != null) {
      send.send({"status": 3, "url": args["url"]});
    }
  }
}
