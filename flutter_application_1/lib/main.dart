import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const VideoApp());
}

class VideoApp extends StatelessWidget {
  const VideoApp({super.key, this.repository});
  final VideoFeedRepository? repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '精选短视频',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: VideoFeedScreen(repository: repository),
    );
  }
}

// --- Data Models & Repository ---
@immutable
class VideoFeedEntry {
  const VideoFeedEntry({
    required this.id, required this.url, required this.likes,
    required this.isLiked, required this.isSaved,
  });
  final String id, url;
  final int likes;
  final bool isLiked, isSaved;

  VideoFeedEntry copyWith({int? likes, bool? isLiked, bool? isSaved}) {
    return VideoFeedEntry(
      id: id, url: url, likes: likes ?? this.likes,
      isLiked: isLiked ?? this.isLiked, isSaved: isSaved ?? this.isSaved,
    );
  }
}

abstract class VideoFeedRepository {
  Future<VideoFeedEntry?> fetchRandomVideo(Set<String> existingUrls);
  void dispose() {}
}

class NetworkVideoFeedRepository implements VideoFeedRepository {
  final http.Client _client = http.Client();
  final Random _random = Random();
  static const String _apiEndpoint = 'https://api.yujn.cn/api/zzxjj.php?type=json';

  @override
  Future<VideoFeedEntry?> fetchRandomVideo(Set<String> existingUrls) async {
    try {
      final response = await _client.get(Uri.parse(_apiEndpoint)).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final String? url = decoded['data'] ?? decoded['url'] ?? decoded['video'];
        if (url != null && url.startsWith('http') && !existingUrls.contains(url)) {
          return VideoFeedEntry(id: '${url.hashCode}', url: url, likes: 1000 + _random.nextInt(50000), isLiked: false, isSaved: false);
        }
      }
    } catch (_) {}
    return null;
  }
  @override
  void dispose() => _client.close();
}

// --- Screen ---
class VideoFeedScreen extends StatefulWidget {
  const VideoFeedScreen({super.key, this.repository});
  final VideoFeedRepository? repository;
  @override
  State<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends State<VideoFeedScreen> {
  final List<VideoFeedEntry> _items = [];
  final Map<int, VideoPlayerController> _controllers = {};
  late final PageController _pageController = PageController();
  late final VideoFeedRepository _repository = widget.repository ?? NetworkVideoFeedRepository();

  int _currentIndex = 0;
  bool _isMuted = false, _isFetching = false;
  double _volume = 1.0, _speed = 1.0;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    for (var c in _controllers.values) c.dispose();
    _pageController.dispose();
    _repository.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    while (_items.length < 3) await _fetchOne();
    if (mounted) {
      _prepareAround(0);
      _play(0);
    }
  }

  Future<void> _fetchOne() async {
    if (_isFetching) return;
    _isFetching = true;
    final item = await _repository.fetchRandomVideo(_items.map((e) => e.url).toSet());
    if (item != null && mounted) setState(() => _items.add(item));
    _isFetching = false;
  }

  Future<void> _play(int index) async {
    if (index < 0 || index >= _items.length) return;
    final controller = _controllers[index] ?? await _initController(index);
    if (controller == null) return;

    for (var i in _controllers.keys) if (i != index) _controllers[i]?.pause();
    await controller.setLooping(true); // 默认循环播放
    await controller.setPlaybackSpeed(_speed);
    await controller.play();
    WakelockPlus.enable();
  }

  Future<VideoPlayerController?> _initController(int index) async {
    if (_controllers.containsKey(index)) return _controllers[index];
    final c = VideoPlayerController.networkUrl(Uri.parse(_items[index].url));
    _controllers[index] = c;
    try {
      await c.initialize();
      await c.setVolume(_isMuted ? 0 : _volume);
      await c.setPlaybackSpeed(_speed);
      if (mounted) setState(() {});
      return c;
    } catch (_) {
      _controllers.remove(index)?.dispose();
      return null;
    }
  }

  void _prepareAround(int index) {
    for (int i in [index - 1, index, index + 1, index + 2]) {
      if (i >= 0 && i < _items.length) _initController(i);
    }
    _controllers.keys.where((i) => (i - index).abs() > 2).toList().forEach((i) => _controllers.remove(i)?.dispose());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _items.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: _items.length,
            onPageChanged: (i) {
              setState(() => _currentIndex = i);
              _prepareAround(i);
              _play(i);
              if (i >= _items.length - 2) _fetchOne();
            },
            itemBuilder: (context, index) => VideoItemView(
              entry: _items[index],
              controller: _controllers[index],
              speed: _speed,
              onSpeed: (s) {
                setState(() {
                  _speed = s;
                  for (var c in _controllers.values) c.setPlaybackSpeed(s);
                });
              },
              onVolume: (v) => setState(() { _volume = v; _controllers[index]?.setVolume(v); }),
              onTogglePlay: () {
                final c = _controllers[index];
                if (c == null) return;
                c.value.isPlaying ? c.pause() : c.play();
                setState(() {});
              },
              onLike: () => setState(() => _items[index] = _items[index].copyWith(isLiked: !_items[index].isLiked)),
            ),
          ),
    );
  }
}

class VideoItemView extends StatefulWidget {
  const VideoItemView({
    super.key, required this.entry, required this.controller,
    required this.speed, required this.onSpeed, required this.onVolume,
    required this.onTogglePlay, required this.onLike,
  });
  final VideoFeedEntry entry;
  final VideoPlayerController? controller;
  final double speed;
  final ValueChanged<double> onSpeed, onVolume;
  final VoidCallback onTogglePlay, onLike;

  @override
  State<VideoItemView> createState() => _VideoItemViewState();
}

class _VideoItemViewState extends State<VideoItemView> {
  String? _hud;
  Timer? _timer;

  void _showHud(String msg) {
    _timer?.cancel();
    setState(() => _hud = msg);
    _timer = Timer(const Duration(seconds: 1), () => setState(() => _hud = null));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Video 画面
        if (widget.controller?.value.isInitialized ?? false)
          Center(child: AspectRatio(aspectRatio: widget.controller!.value.aspectRatio, child: VideoPlayer(widget.controller!)))
        else
          const Center(child: CircularProgressIndicator()),

        // 交互层：拆分为三列，中间负责翻页，去除所有滑动调节
        Row(
          children: [
            // 左侧：仅处理点击
            Expanded(flex: 2, child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onTogglePlay,
            )),
            // 中间：留空区域，PageView 的垂直滑动会在这里生效
            Expanded(flex: 6, child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onTogglePlay,
            )),
            // 右侧：仅处理点击
            Expanded(flex: 2, child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onTogglePlay,
            )),
          ],
        ),

        // HUD 提示
        if (_hud != null) Center(child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)), child: Text(_hud!, style: const TextStyle(color: Colors.white)))),

        // 右侧按钮栏
        Positioned(
          right: 12, bottom: 100,
          child: Column(
            children: [
              IconButton(
                icon: Icon(widget.entry.isLiked ? Icons.favorite : Icons.favorite_border, color: widget.entry.isLiked ? Colors.red : Colors.white, size: 38),
                onPressed: widget.onLike,
              ),
              Text('${widget.entry.likes}', style: const TextStyle(fontSize: 12, color: Colors.white)),
              const SizedBox(height: 20),

              // 倍速按钮
              GestureDetector(
                onTap: () {
                  final nextSpeed = widget.speed >= 2.0 ? 1.0 : widget.speed + 0.5;
                  widget.onSpeed(nextSpeed);
                  _showHud('倍速 ${nextSpeed}x');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 1.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('${widget.speed}x', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 20),

              const Icon(Icons.share, size: 32, color: Colors.white),
            ],
          ),
        ),

        // 底部进度条
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: VideoProgressIndicator(widget.controller!, allowScrubbing: true, colors: const VideoProgressColors(playedColor: Colors.white, bufferedColor: Colors.white24)),
        ),
      ],
    );
  }
}
