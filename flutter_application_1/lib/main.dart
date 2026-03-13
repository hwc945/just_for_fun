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
    final baseScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF22C55E),
      brightness: Brightness.dark,
    );

    return MaterialApp(
      title: '精选短视频',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF05070B),
        colorScheme: baseScheme.copyWith(
          surface: const Color(0xFF10141C),
          primary: const Color(0xFF8AF2B8),
          secondary: const Color(0xFFFFA85A),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
      ),
      home: VideoFeedScreen(repository: repository),
    );
  }
}

abstract class VideoFeedRepository {
  Future<VideoFeedEntry?> fetchRandomVideo(Set<String> existingUrls);

  void dispose() {}
}

class NetworkVideoFeedRepository implements VideoFeedRepository {
  NetworkVideoFeedRepository({
    http.Client? client,
    Random? random,
  })  : _client = client ?? http.Client(),
        _random = random ?? Random();

  static const String _apiEndpoint =
      'https://api.yujn.cn/api/zzxjj.php?type=json';

  static const List<String> _fallbackUrls = [
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4',
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4',
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4',
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4',
  ];

  static const List<String> _titles = [
    '城市漫游的节奏切片',
    '雨夜光影实验',
    '街头速度观察',
    '自然纹理采样',
    '清晨通勤记录',
    '假日旅拍片段',
    '镜头里的轻松一刻',
    '生活感转场练习',
  ];

  static const List<String> _creators = [
    'Aster Motion',
    'North Studio',
    'Daily Lens',
    'Mono Film',
    'Cloud Frame',
    'Weekender',
    'Fresh Cut',
    'Quiet Pixel',
  ];

  static const List<String> _descriptions = [
    '用更完整的信息布局和更顺手的交互，把随机拉取的视频流包装成一个更接近成品的播放器体验。',
    '保留沉浸感的同时补齐评论、收藏、倍速、重试和状态反馈，让播放器不再只有“能播”这一件事。',
    '当前还是半成品，但已经具备继续迭代的骨架：数据兜底、控制器预加载、交互提示和容错路径都在了。',
    '把短视频 feed 的关键细节先做扎实，后续再接后端推荐、用户系统和真实互动数据时成本会低很多。',
  ];

  static const List<List<String>> _tagGroups = [
    ['精选', '氛围感', '高完成度'],
    ['练习片段', '沉浸式', '流畅切换'],
    ['旅行', '街拍', '轻剧情'],
    ['实验感', '快节奏', '推荐'],
  ];

  static const List<String> _badges = [
    '编辑精选',
    '今日推荐',
    '可继续迭代',
    '备用片源',
  ];

  static const List<Color> _accents = [
    Color(0xFF3B82F6),
    Color(0xFF06B6D4),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFFF472B6),
  ];

  final http.Client _client;
  final Random _random;

  @override
  Future<VideoFeedEntry?> fetchRandomVideo(Set<String> existingUrls) async {
    for (int attempt = 0; attempt < 3; attempt++) {
      final apiUrl = await _fetchFromApi(existingUrls);
      if (apiUrl != null) {
        return _buildEntry(apiUrl, sourceLabel: '实时接口');
      }
    }

    for (final fallbackUrl in List<String>.of(_fallbackUrls)..shuffle(_random)) {
      if (!existingUrls.contains(fallbackUrl)) {
        return _buildEntry(fallbackUrl, sourceLabel: '备用片源');
      }
    }
    return null;
  }

  Future<String?> _fetchFromApi(Set<String> existingUrls) async {
    try {
      final response = await _client
          .get(Uri.parse(_apiEndpoint))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        return null;
      }

      final body = utf8.decode(response.bodyBytes, allowMalformed: true);
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final dynamic rawData = decoded['data'] ?? decoded['url'] ?? decoded['video'];
      final url = rawData is String ? rawData.trim() : null;
      if (url == null || url.isEmpty || !url.startsWith('http')) {
        return null;
      }
      if (existingUrls.contains(url)) {
        return null;
      }
      return url;
    } catch (_) {
      return null;
    }
  }

  VideoFeedEntry _buildEntry(
    String url, {
    required String sourceLabel,
  }) {
    final seed = url.hashCode.abs();
    final likes = 1500 + seed % 42000;
    final comments = 48 + seed % 3600;
    final shares = 8 + seed % 900;
    final tags = _tagGroups[seed % _tagGroups.length];

    return VideoFeedEntry(
      id: '$seed',
      url: url,
      title: _titles[seed % _titles.length],
      creator: _creators[(seed ~/ 3) % _creators.length],
      description: _descriptions[(seed ~/ 7) % _descriptions.length],
      tags: tags,
      likes: likes,
      comments: comments,
      shares: shares,
      isLiked: false,
      isSaved: false,
      accent: _accents[seed % _accents.length],
      badge: _badges[(seed ~/ 5) % _badges.length],
      sourceLabel: sourceLabel,
    );
  }

  @override
  void dispose() {
    _client.close();
  }
}

@immutable
class VideoFeedEntry {
  const VideoFeedEntry({
    required this.id,
    required this.url,
    required this.title,
    required this.creator,
    required this.description,
    required this.tags,
    required this.likes,
    required this.comments,
    required this.shares,
    required this.isLiked,
    required this.isSaved,
    required this.accent,
    required this.badge,
    required this.sourceLabel,
  });

  final String id;
  final String url;
  final String title;
  final String creator;
  final String description;
  final List<String> tags;
  final int likes;
  final int comments;
  final int shares;
  final bool isLiked;
  final bool isSaved;
  final Color accent;
  final String badge;
  final String sourceLabel;

  VideoFeedEntry copyWith({
    int? likes,
    int? comments,
    int? shares,
    bool? isLiked,
    bool? isSaved,
  }) {
    return VideoFeedEntry(
      id: id,
      url: url,
      title: title,
      creator: creator,
      description: description,
      tags: tags,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      shares: shares ?? this.shares,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
      accent: accent,
      badge: badge,
      sourceLabel: sourceLabel,
    );
  }
}

class VideoFeedScreen extends StatefulWidget {
  const VideoFeedScreen({super.key, this.repository});

  final VideoFeedRepository? repository;

  @override
  State<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends State<VideoFeedScreen> {
  final List<VideoFeedEntry> _items = [];
  final Map<int, VideoPlayerController> _controllers = {};
  final Set<int> _initializingIndices = <int>{};
  final Map<int, String> _controllerErrors = <int, String>{};

  late final PageController _pageController;
  late final VideoFeedRepository _repository;
  late final bool _ownsRepository;

  VideoPlayerController? _activeController;
  bool _isInitialLoading = false;
  bool _isFetchingMore = false;
  String? _feedError;
  int _currentIndex = 0;
  bool _isMuted = false;
  bool _isLooping = false;
  double _playbackSpeed = 1.0;
  double _volumeLevel = 1.0;
  double _simulatedBrightness = 1.0;
  bool _showGestureHint = true;
  Timer? _gestureHintTimer;

  @override
  void initState() {
    super.initState();
    _ownsRepository = widget.repository == null;
    _repository = widget.repository ?? NetworkVideoFeedRepository();
    _pageController = PageController();
    _gestureHintTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) {
        setState(() {
          _showGestureHint = false;
        });
      }
    });
    _loadInitialVideos();
  }

  @override
  void dispose() {
    _gestureHintTimer?.cancel();
    _detachActiveControllerListener();
    unawaited(WakelockPlus.disable());
    _pageController.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    if (_ownsRepository) {
      _repository.dispose();
    }
    super.dispose();
  }

  Future<void> _loadInitialVideos({bool refresh = false}) async {
    if (_isInitialLoading && !refresh) {
      return;
    }

    if (refresh) {
      _resetFeedState();
    }

    setState(() {
      _isInitialLoading = true;
      _feedError = null;
    });

    int attempts = 0;
    while (_items.length < 4 && attempts < 10) {
      await _appendOneVideo();
      attempts++;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isInitialLoading = false;
      if (_items.isEmpty) {
        _feedError = '暂时没有拿到可播放的视频，请稍后重试。';
      }
    });

    if (_items.isNotEmpty) {
      _prepareControllersAround(_currentIndex);
      unawaited(_playController(_currentIndex));
      unawaited(_fetchMoreVideos(targetCount: 2));
    }
  }

  void _resetFeedState() {
    _detachActiveControllerListener();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _initializingIndices.clear();
    _controllerErrors.clear();
    _items.clear();
    _currentIndex = 0;
    _showGestureHint = true;
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
  }

  Future<bool> _appendOneVideo() async {
    final existingUrls = _items.map((item) => item.url).toSet();
    final item = await _repository.fetchRandomVideo(existingUrls);
    if (item == null || !mounted) {
      return false;
    }

    setState(() {
      _items.add(item);
    });
    return true;
  }

  Future<void> _fetchMoreVideos({int targetCount = 2}) async {
    if (_isFetchingMore) {
      return;
    }

    setState(() {
      _isFetchingMore = true;
    });

    int added = 0;
    int attempts = 0;
    while (added < targetCount && attempts < targetCount * 4) {
      final success = await _appendOneVideo();
      if (success) {
        added++;
      }
      attempts++;
    }

    if (mounted) {
      setState(() {
        _isFetchingMore = false;
      });
    }
  }

  Future<void> _initializeControllerAtIndex(int index) async {
    if (index < 0 || index >= _items.length) {
      return;
    }
    if (_controllers.containsKey(index) || _initializingIndices.contains(index)) {
      return;
    }

    _controllerErrors.remove(index);
    _initializingIndices.add(index);

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(_items[index].url),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
    );

    _controllers[index] = controller;
    await _applyPlaybackSettings(controller);

    try {
      await controller.initialize();
      if (_controllers[index] != controller) {
        await controller.dispose();
        return;
      }

      await _applyPlaybackSettings(controller);

      if (mounted) {
        setState(() {});
      }

      if (index == _currentIndex) {
        _attachActiveControllerListener(index);
        await _playController(index);
      } else {
        await controller.pause();
      }
    } catch (error) {
      _controllerErrors[index] = '视频加载失败，已保留重试入口。';
      final failedController = _controllers.remove(index);
      await failedController?.dispose();
      if (mounted) {
        setState(() {});
      }
    } finally {
      _initializingIndices.remove(index);
    }
  }

  Future<void> _applyPlaybackSettings(VideoPlayerController controller) async {
    await controller.setLooping(_isLooping);
    await controller.setPlaybackSpeed(_playbackSpeed);
    await controller.setVolume(_isMuted ? 0 : _volumeLevel);
  }

  Future<void> _playController(int index) async {
    if (index < 0 || index >= _items.length) {
      return;
    }

    if (!_controllers.containsKey(index)) {
      await _initializeControllerAtIndex(index);
    }

    final controller = _controllers[index];
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    _pauseAllExcept(index);

    final value = controller.value;
    if (value.duration != Duration.zero &&
        value.position >= value.duration - const Duration(milliseconds: 300)) {
      await controller.seekTo(Duration.zero);
    }

    await controller.play();
    _attachActiveControllerListener(index);
    _syncWakelock();
  }

  Future<void> _togglePlayPause(int index) async {
    final controller = _controllers[index];
    if (controller == null || !controller.value.isInitialized) {
      await _initializeControllerAtIndex(index);
      return;
    }

    if (controller.value.isPlaying) {
      await controller.pause();
      _syncWakelock();
      return;
    }

    await _playController(index);
  }

  void _pauseAllExcept(int activeIndex) {
    for (final entry in _controllers.entries) {
      if (entry.key != activeIndex && entry.value.value.isInitialized) {
        entry.value.pause();
      }
    }
  }

  void _prepareControllersAround(int index) {
    const preloadRange = <int>[-1, 0, 1, 2];
    final keepAlive = <int>{};

    for (final offset in preloadRange) {
      final candidate = index + offset;
      if (candidate < 0 || candidate >= _items.length) {
        continue;
      }
      keepAlive.add(candidate);
      unawaited(_initializeControllerAtIndex(candidate));
    }

    final staleIndices = _controllers.keys
        .where((controllerIndex) => !keepAlive.contains(controllerIndex))
        .toList();
    for (final staleIndex in staleIndices) {
      _disposeControllerAtIndex(staleIndex);
    }
  }

  void _disposeControllerAtIndex(int index) {
    if (_controllers[index] == _activeController) {
      _detachActiveControllerListener();
    }
    final controller = _controllers.remove(index);
    controller?.dispose();
  }

  void _attachActiveControllerListener(int index) {
    final nextActiveController = _controllers[index];
    if (identical(_activeController, nextActiveController)) {
      return;
    }

    _activeController?.removeListener(_handleActiveControllerStateChanged);
    _activeController = nextActiveController;
    _activeController?.addListener(_handleActiveControllerStateChanged);
    _syncWakelock();
  }

  void _detachActiveControllerListener() {
    _activeController?.removeListener(_handleActiveControllerStateChanged);
    _activeController = null;
  }

  void _handleActiveControllerStateChanged() {
    _syncWakelock();
  }

  void _syncWakelock() {
    final shouldKeepAwake = _controllers[_currentIndex]?.value.isPlaying ?? false;
    if (shouldKeepAwake) {
      unawaited(WakelockPlus.enable());
    } else {
      unawaited(WakelockPlus.disable());
    }
  }

  void _handlePageChanged(int index) {
    _currentIndex = index;
    if (_currentIndex > 0 && _showGestureHint) {
      setState(() {
        _showGestureHint = false;
      });
    } else {
      setState(() {});
    }

    _attachActiveControllerListener(index);
    _prepareControllersAround(index);
    unawaited(_playController(index));

    if (index >= _items.length - 2) {
      unawaited(_fetchMoreVideos(targetCount: 3));
    }
  }

  void _updateCurrentEntry(VideoFeedEntry updated) {
    if (_currentIndex < 0 || _currentIndex >= _items.length) {
      return;
    }

    setState(() {
      _items[_currentIndex] = updated;
    });
  }

  void _toggleLike(int index) {
    final current = _items[index];
    final shouldLike = !current.isLiked;
    setState(() {
      _items[index] = current.copyWith(
        isLiked: shouldLike,
        likes: shouldLike ? current.likes + 1 : max(0, current.likes - 1),
      );
    });
  }

  void _toggleSaved(int index) {
    final current = _items[index];
    setState(() {
      _items[index] = current.copyWith(isSaved: !current.isSaved);
    });
  }

  Future<void> _retryVideo(int index) async {
    _controllerErrors.remove(index);
    _disposeControllerAtIndex(index);
    if (mounted) {
      setState(() {});
    }
    await _initializeControllerAtIndex(index);
    if (index == _currentIndex) {
      await _playController(index);
    }
  }

  Future<void> _toggleMute() async {
    setState(() {
      _isMuted = !_isMuted;
    });

    for (final controller in _controllers.values) {
      await controller.setVolume(_isMuted ? 0 : _volumeLevel);
    }
  }

  Future<void> _toggleLoop() async {
    setState(() {
      _isLooping = !_isLooping;
    });

    for (final controller in _controllers.values) {
      await controller.setLooping(_isLooping);
    }
  }

  Future<void> _setPlaybackSpeed(double speed) async {
    setState(() {
      _playbackSpeed = speed;
    });

    for (final controller in _controllers.values) {
      await controller.setPlaybackSpeed(speed);
    }
  }

  Future<void> _setVolumeLevel(double value) async {
    final next = value.clamp(0.0, 1.0).toDouble();
    setState(() {
      _volumeLevel = next;
      if (_volumeLevel > 0 && _isMuted) {
        _isMuted = false;
      }
    });

    for (final controller in _controllers.values) {
      await controller.setVolume(_isMuted ? 0 : _volumeLevel);
    }
  }

  void _setBrightness(double value) {
    setState(() {
      _simulatedBrightness = value.clamp(0.35, 1.0).toDouble();
    });
  }

  void _showComments(VideoFeedEntry entry) {
    final comments = List<String>.generate(
      8,
      (index) => '这条视频的节奏和 UI 细节已经比最初版本完整很多，第 ${index + 1} 条评论。',
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0E1219),
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.comments} 条评论',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '当前是静态评论面板，后续接入真实评论接口即可复用这层 UI。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: comments.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: Colors.white12, height: 20),
                    itemBuilder: (context, index) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: entry.accent.withOpacity(0.35),
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'viewer_${index + 11}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  comments[index],
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _shareCurrent() {
    final entry = _items[_currentIndex];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('分享能力待接入，已预留动作入口：${entry.title}'),
      ),
    );
  }

  Future<void> _openSpeedPicker() async {
    const speeds = <double>[0.75, 1.0, 1.25, 1.5, 2.0];
    final selected = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: const Color(0xFF0E1219),
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: speeds
                .map(
                  (speed) => ListTile(
                    leading: Icon(
                      speed == _playbackSpeed
                          ? Icons.check_circle_rounded
                          : Icons.speed_rounded,
                      color: speed == _playbackSpeed
                          ? Theme.of(context).colorScheme.primary
                          : Colors.white70,
                    ),
                    title: Text('${speed.toStringAsFixed(speed == 1 ? 0 : 2)}x'),
                    onTap: () => Navigator.of(context).pop(speed),
                  ),
                )
                .toList(),
          ),
        );
      },
    );

    if (selected != null) {
      await _setPlaybackSpeed(selected);
    }
  }

  void _handleVideoFinished() {
    if (!_pageController.hasClients) {
      return;
    }

    if (_currentIndex < _items.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    final controller = _controllers[_currentIndex];
    controller?.pause();
    _syncWakelock();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          if (_items.isEmpty)
            _buildInitialState()
          else
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: _items.length,
              onPageChanged: _handlePageChanged,
              itemBuilder: (context, index) {
                if (!_controllers.containsKey(index) &&
                    !_controllerErrors.containsKey(index)) {
                  unawaited(_initializeControllerAtIndex(index));
                }

                return VideoPlayerFeedItem(
                  key: ValueKey(_items[index].id),
                  entry: _items[index],
                  controller: _controllers[index],
                  errorMessage: _controllerErrors[index],
                  isActive: index == _currentIndex,
                  isMuted: _isMuted,
                  isLooping: _isLooping,
                  brightness: _simulatedBrightness,
                  volumeLevel: _volumeLevel,
                  playbackSpeed: _playbackSpeed,
                  showGestureHint:
                      _showGestureHint && index == _currentIndex && index == 0,
                  onVideoFinished: _handleVideoFinished,
                  onTogglePlay: () => _togglePlayPause(index),
                  onRetry: () => _retryVideo(index),
                  onLike: () => _toggleLike(index),
                  onToggleSaved: () => _toggleSaved(index),
                  onOpenComments: () => _showComments(_items[index]),
                  onShare: _shareCurrent,
                  onToggleMute: _toggleMute,
                  onToggleLoop: _toggleLoop,
                  onOpenSpeedPicker: _openSpeedPicker,
                  onBrightnessChanged: _setBrightness,
                  onVolumeChanged: _setVolumeLevel,
                );
              },
            ),
          _buildTopOverlay(),
        ],
      ),
    );
  }

  Widget _buildInitialState() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0B1220),
            Color(0xFF05070B),
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  shape: BoxShape.circle,
                ),
                child: _isInitialLoading
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(strokeWidth: 3),
                      )
                    : const Icon(
                        Icons.ondemand_video_rounded,
                        size: 38,
                        color: Colors.white70,
                      ),
              ),
              const SizedBox(height: 20),
              Text(
                _isInitialLoading ? '正在组装更完整的播放器体验' : '播放器暂时没有拿到内容',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                _feedError ??
                    '这个版本会优先从在线接口取视频，失败时自动切换到备用片源，保证 UI 和播放流不至于直接瘫掉。',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                      height: 1.55,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _isInitialLoading ? null : () => _loadInitialVideos(refresh: true),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('重新加载'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopOverlay() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
        child: Row(
          children: [
            const _GlassPill(
              icon: Icons.play_circle_fill_rounded,
              label: '精选短视频',
            ),
            const SizedBox(width: 8),
            _GlassPill(
              icon: _isFetchingMore ? Icons.cloud_download_rounded : Icons.bolt_rounded,
              label: _items.isEmpty ? '准备中' : '${_currentIndex + 1}/${_items.length}',
            ),
            const Spacer(),
            _OverlayIconButton(
              onPressed: _openSpeedPicker,
              child: Text(
                '${_playbackSpeed.toStringAsFixed(_playbackSpeed == 1 ? 0 : 2)}x',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _OverlayIconButton(
              onPressed: _toggleMute,
              child: Icon(
                _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            _OverlayIconButton(
              onPressed: () => _loadInitialVideos(refresh: true),
              child: const Icon(Icons.refresh_rounded, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class VideoPlayerFeedItem extends StatefulWidget {
  const VideoPlayerFeedItem({
    super.key,
    required this.entry,
    required this.controller,
    required this.errorMessage,
    required this.isActive,
    required this.isMuted,
    required this.isLooping,
    required this.brightness,
    required this.volumeLevel,
    required this.playbackSpeed,
    required this.showGestureHint,
    required this.onVideoFinished,
    required this.onTogglePlay,
    required this.onRetry,
    required this.onLike,
    required this.onToggleSaved,
    required this.onOpenComments,
    required this.onShare,
    required this.onToggleMute,
    required this.onToggleLoop,
    required this.onOpenSpeedPicker,
    required this.onBrightnessChanged,
    required this.onVolumeChanged,
  });

  final VideoFeedEntry entry;
  final VideoPlayerController? controller;
  final String? errorMessage;
  final bool isActive;
  final bool isMuted;
  final bool isLooping;
  final double brightness;
  final double volumeLevel;
  final double playbackSpeed;
  final bool showGestureHint;
  final VoidCallback onVideoFinished;
  final Future<void> Function() onTogglePlay;
  final Future<void> Function() onRetry;
  final VoidCallback onLike;
  final VoidCallback onToggleSaved;
  final VoidCallback onOpenComments;
  final VoidCallback onShare;
  final Future<void> Function() onToggleMute;
  final Future<void> Function() onToggleLoop;
  final Future<void> Function() onOpenSpeedPicker;
  final ValueChanged<double> onBrightnessChanged;
  final ValueChanged<double> onVolumeChanged;

  @override
  State<VideoPlayerFeedItem> createState() => _VideoPlayerFeedItemState();
}

class _VideoPlayerFeedItemState extends State<VideoPlayerFeedItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _heartController;
  late final Animation<double> _heartScale;
  late final Animation<double> _heartOpacity;

  Timer? _controlsTimer;
  Timer? _hudTimer;
  bool _controlsVisible = true;
  bool _hasTriggeredFinish = false;
  bool _isHoldingForSpeed = false;
  String? _hudLabel;
  Offset _heartOffset = Offset.zero;
  _EdgeAdjustMode? _edgeAdjustMode;
  int? _trackingPointer;
  double? _dragStartY;
  double? _startAdjustValue;

  VideoPlayerController? get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _heartScale = Tween<double>(begin: 0.45, end: 1.1).animate(
      CurvedAnimation(parent: _heartController, curve: Curves.easeOutBack),
    );
    _heartOpacity = Tween<double>(begin: 0.95, end: 0).animate(
      CurvedAnimation(parent: _heartController, curve: Curves.easeOut),
    );

    _attachControllerListener(_controller);
    if (widget.isActive) {
      _scheduleControlsAutoHide();
    }
  }

  @override
  void didUpdateWidget(VideoPlayerFeedItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _detachControllerListener(oldWidget.controller);
      _attachControllerListener(widget.controller);
      _hasTriggeredFinish = false;
    }

    if (widget.isActive && !oldWidget.isActive) {
      _controlsVisible = true;
      _scheduleControlsAutoHide();
    }

    if (!widget.isActive && oldWidget.isActive) {
      _controlsTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _hudTimer?.cancel();
    _detachControllerListener(_controller);
    _heartController.dispose();
    super.dispose();
  }

  void _attachControllerListener(VideoPlayerController? controller) {
    controller?.addListener(_handleVideoValueChanged);
  }

  void _detachControllerListener(VideoPlayerController? controller) {
    controller?.removeListener(_handleVideoValueChanged);
  }

  void _handleVideoValueChanged() {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    final value = controller.value;
    final isFinished = value.isInitialized &&
        value.duration != Duration.zero &&
        value.position >= value.duration - const Duration(milliseconds: 200) &&
        !value.isLooping;

    if (widget.isActive && isFinished && !_hasTriggeredFinish) {
      _hasTriggeredFinish = true;
      widget.onVideoFinished();
    } else if (!isFinished && _hasTriggeredFinish) {
      _hasTriggeredFinish = false;
    }

    if (widget.isActive && value.isPlaying) {
      _scheduleControlsAutoHide();
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _scheduleControlsAutoHide() {
    _controlsTimer?.cancel();
    final value = _controller?.value;
    if (!widget.isActive || value == null || !value.isInitialized || !value.isPlaying) {
      return;
    }

    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _controlsVisible = false;
        });
      }
    });
  }

  void _showControlsTemporarily() {
    setState(() {
      _controlsVisible = true;
    });
    _scheduleControlsAutoHide();
  }

  void _showHud(String text) {
    _hudTimer?.cancel();
    setState(() {
      _hudLabel = text;
    });
    _hudTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _hudLabel = null;
        });
      }
    });
  }

  Future<void> _handlePlayTap() async {
    await widget.onTogglePlay();
    _showControlsTemporarily();
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _heartOffset = details.localPosition;
  }

  void _handleDoubleTap() {
    if (!widget.entry.isLiked) {
      widget.onLike();
    }
    _heartController.forward(from: 0);
    _showHud('已点赞');
    _showControlsTemporarily();
  }

  Future<void> _handleLongPressStart(LongPressStartDetails details) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    _isHoldingForSpeed = true;
    await controller.setPlaybackSpeed(max(2.0, widget.playbackSpeed));
    _showHud('长按 2.0x 加速');
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _handleLongPressEnd(LongPressEndDetails details) async {
    final controller = _controller;
    if (!_isHoldingForSpeed || controller == null || !controller.value.isInitialized) {
      return;
    }
    _isHoldingForSpeed = false;
    await controller.setPlaybackSpeed(widget.playbackSpeed);
    _showHud('${widget.playbackSpeed.toStringAsFixed(widget.playbackSpeed == 1 ? 0 : 2)}x');
    if (mounted) {
      setState(() {});
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    final size = context.size;
    if (size == null) {
      return;
    }

    final edgeWidth = max(56.0, size.width * 0.18);
    final dx = event.localPosition.dx;
    if (dx <= edgeWidth) {
      _edgeAdjustMode = _EdgeAdjustMode.brightness;
      _trackingPointer = event.pointer;
      _dragStartY = event.localPosition.dy;
      _startAdjustValue = widget.brightness;
    } else if (dx >= size.width - edgeWidth) {
      _edgeAdjustMode = _EdgeAdjustMode.volume;
      _trackingPointer = event.pointer;
      _dragStartY = event.localPosition.dy;
      _startAdjustValue = widget.volumeLevel;
    } else {
      _edgeAdjustMode = null;
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    final size = context.size;
    if (size == null ||
        event.pointer != _trackingPointer ||
        _edgeAdjustMode == null ||
        _dragStartY == null ||
        _startAdjustValue == null) {
      return;
    }

    final delta = (_dragStartY! - event.localPosition.dy) / (size.height * 0.55);
    final nextValue = (_startAdjustValue! + delta).clamp(0.0, 1.0).toDouble();

    if (_edgeAdjustMode == _EdgeAdjustMode.brightness) {
      final brightness = max(0.35, nextValue);
      widget.onBrightnessChanged(brightness);
      _showHud('亮度 ${(brightness * 100).round()}%');
    } else {
      widget.onVolumeChanged(nextValue);
      _showHud('音量 ${(nextValue * 100).round()}%');
    }
    _showControlsTemporarily();
  }

  void _handlePointerUp(PointerEvent event) {
    if (event.pointer == _trackingPointer) {
      _edgeAdjustMode = null;
      _trackingPointer = null;
      _dragStartY = null;
      _startAdjustValue = null;
    }
  }

  bool get _isVideoReady =>
      _controller != null && _controller!.value.isInitialized;

  bool get _isPlaying => _controller?.value.isPlaying ?? false;

  bool get _isBuffering => _controller?.value.isBuffering ?? false;

  bool get _isCompleted {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return false;
    }
    final value = controller.value;
    return value.duration != Duration.zero &&
        value.position >= value.duration - const Duration(milliseconds: 200) &&
        !value.isPlaying;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerUp,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handlePlayTap,
        onDoubleTapDown: _handleDoubleTapDown,
        onDoubleTap: _handleDoubleTap,
        onLongPressStart: _handleLongPressStart,
        onLongPressEnd: _handleLongPressEnd,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildBackdrop(),
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color:
                      Colors.black.withOpacity((1 - widget.brightness) * 0.55),
                ),
              ),
            ),
            _buildGradients(),
            _buildStatusHud(),
            _buildCenterState(),
            _buildBottomContent(context),
            _buildActionRail(context),
            _buildDoubleTapHeart(),
            if (widget.showGestureHint) _buildGestureHint(),
          ],
        ),
      ),
    );
  }

  Widget _buildBackdrop() {
    final controller = _controller;
    if (widget.errorMessage != null) {
      return _buildPlaceholder(
        icon: Icons.wifi_tethering_error_rounded,
        title: '当前视频加载失败',
        subtitle: widget.errorMessage!,
        action: FilledButton.icon(
          onPressed: widget.onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('重新尝试'),
        ),
      );
    }

    if (controller == null || !controller.value.isInitialized) {
      return _buildPlaceholder(
        icon: Icons.movie_creation_outlined,
        title: '正在准备片源',
        subtitle: '已预留备用源、错误重试和控制器预加载，避免页面只剩一块黑屏。',
        action: null,
      );
    }

    final videoSize = controller.value.size;
    if (videoSize.width <= 0 || videoSize.height <= 0) {
      return const SizedBox.expand(
        child: ColoredBox(color: Colors.black),
      );
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: videoSize.width,
          height: videoSize.height,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }

  Widget _buildPlaceholder({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget? action,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            widget.entry.accent.withOpacity(0.75),
            const Color(0xFF081019),
            const Color(0xFF05070B),
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 46, color: Colors.white70),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white70,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              if (action != null) ...[
                const SizedBox(height: 18),
                action,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGradients() {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 180,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.65),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 320,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.26),
                    Colors.black.withOpacity(0.82),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterState() {
    if (widget.errorMessage != null) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: Center(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: (!_isPlaying || _controlsVisible || _isBuffering) ? 1 : 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isBuffering)
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.44),
                    shape: BoxShape.circle,
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                )
              else if (_isVideoReady)
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.36),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Icon(
                    _isCompleted
                        ? Icons.replay_rounded
                        : (_isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded),
                    size: 38,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomContent(BuildContext context) {
    return Positioned(
      left: 16,
      right: 92,
      bottom: 24,
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _GlassPill(
                  icon: Icons.auto_awesome_rounded,
                  label: widget.entry.badge,
                ),
                const SizedBox(width: 8),
                _GlassPill(
                  icon: Icons.cloud_done_rounded,
                  label: widget.entry.sourceLabel,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              widget.entry.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '@${widget.entry.creator}',
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.entry.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.entry.tags
                  .map(
                    (tag) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        '#$tag',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 18),
            _buildControlsCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsCard(BuildContext context) {
    final controller = _controller;
    final position = controller?.value.position ?? Duration.zero;
    final duration = controller?.value.duration ?? Duration.zero;
    final progress = duration.inMilliseconds == 0
        ? 0.0
        : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: _controlsVisible || !_isPlaying ? 1 : 0.85,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.34),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  _formatDuration(position),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2.6,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 5),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 14),
                    ),
                    child: Slider(
                      value: progress,
                      onChanged: !_isVideoReady
                          ? null
                          : (value) {
                              final target = Duration(
                                milliseconds:
                                    (duration.inMilliseconds * value).round(),
                              );
                              unawaited(controller?.seekTo(target));
                              _showControlsTemporarily();
                            },
                    ),
                  ),
                ),
                Text(
                  _formatDuration(duration),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _MiniControlChip(
                    icon: _isCompleted
                        ? Icons.replay_rounded
                        : (_isPlaying
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_fill_rounded),
                    label: _isCompleted ? '重播' : (_isPlaying ? '暂停' : '播放'),
                    onTap: _handlePlayTap,
                  ),
                  _MiniControlChip(
                    icon: widget.isLooping
                        ? Icons.repeat_one_rounded
                        : Icons.repeat_rounded,
                    label: widget.isLooping ? '单条循环' : '自动切换',
                    onTap: widget.onToggleLoop,
                  ),
                  _MiniControlChip(
                    icon: Icons.speed_rounded,
                    label:
                        '${widget.playbackSpeed.toStringAsFixed(widget.playbackSpeed == 1 ? 0 : 2)}x',
                    onTap: widget.onOpenSpeedPicker,
                  ),
                  _MiniControlChip(
                    icon: widget.isMuted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    label: '${(widget.volumeLevel * 100).round()}%',
                    onTap: widget.onToggleMute,
                  ),
                  _MiniControlChip(
                    icon: Icons.brightness_6_rounded,
                    label: '${(widget.brightness * 100).round()}%',
                    onTap: () => _showHud('左侧上下滑调亮度'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionRail(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 120,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ActionCounterButton(
              icon: widget.entry.isLiked
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              label: _formatCount(widget.entry.likes),
              activeColor: const Color(0xFFFF5D73),
              isActive: widget.entry.isLiked,
              onTap: widget.onLike,
            ),
            const SizedBox(height: 14),
            _ActionCounterButton(
              icon: Icons.mode_comment_outlined,
              label: _formatCount(widget.entry.comments),
              onTap: widget.onOpenComments,
            ),
            const SizedBox(height: 14),
            _ActionCounterButton(
              icon: widget.entry.isSaved
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              label: widget.entry.isSaved ? '已存' : '收藏',
              isActive: widget.entry.isSaved,
              activeColor: Theme.of(context).colorScheme.primary,
              onTap: widget.onToggleSaved,
            ),
            const SizedBox(height: 14),
            _ActionCounterButton(
              icon: Icons.share_rounded,
              label: _formatCount(widget.entry.shares),
              onTap: widget.onShare,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHud() {
    if (_hudLabel == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: MediaQuery.of(context).padding.top + 70,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: _hudLabel == null ? 0 : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.64),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white12),
            ),
            child: Text(
              _hudLabel!,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDoubleTapHeart() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _heartController,
        builder: (context, child) {
          if (_heartController.value == 0) {
            return const SizedBox.shrink();
          }

          return Positioned(
            left: _heartOffset.dx - 36,
            top: _heartOffset.dy - 36,
            child: Opacity(
              opacity: _heartOpacity.value,
              child: Transform.scale(
                scale: _heartScale.value,
                child: const Icon(
                  Icons.favorite_rounded,
                  size: 72,
                  color: Color(0xFFFF5D73),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGestureHint() {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 330,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.46),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white12),
          ),
          child: const Row(
            children: [
              Icon(Icons.tips_and_updates_rounded, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '双击点赞，长按 2x，加速；左边上下滑调亮度，右边上下滑调音量。',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _formatCount(int value) {
    if (value >= 10000) {
      return '${(value / 10000).toStringAsFixed(value >= 100000 ? 0 : 1)}w';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return '$value';
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.28),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverlayIconButton extends StatelessWidget {
  const _OverlayIconButton({
    required this.onPressed,
    required this.child,
  });

  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.3),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _MiniControlChip extends StatelessWidget {
  const _MiniControlChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCounterButton extends StatelessWidget {
  const _ActionCounterButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.activeColor = Colors.white,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = isActive ? activeColor : Colors.white;

    return Column(
      children: [
        Material(
          color: Colors.black.withOpacity(0.34),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 54,
              height: 54,
              child: Center(
                child: Icon(icon, color: foregroundColor, size: 28),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: foregroundColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

enum _EdgeAdjustMode {
  brightness,
  volume,
}
