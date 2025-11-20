import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const VideoApp());
}

class VideoApp extends StatelessWidget {
  const VideoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '抖音视频播放器',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const VideoFeedScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class VideoFeedScreen extends StatefulWidget {
  const VideoFeedScreen({super.key});

  @override
  State<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends State<VideoFeedScreen> {
  final List<String> _videoUrls = [];
  final Map<int, VideoPlayerController> _controllers = {};
  late PageController _pageController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadInitialVideos();
  }

  Future<void> _loadInitialVideos() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });
    // 初始加载3个视频
    for (int i = 0; i < 3; i++) {
      await _fetchNewVideo();
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchNewVideo() async {
    try {
      final response = await http.get(Uri.parse('https://api.yujn.cn/api/zzxjj.php?type=json'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String? videoUrl = data['data'];
        if (videoUrl != null && videoUrl.isNotEmpty) {
          if (mounted) {
            setState(() {
              _videoUrls.add(videoUrl);
            });
            // 如果是前两个视频，立即初始化
            if (_videoUrls.length <= 2) {
              _initializeControllerAtIndex(_videoUrls.length - 1);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching video: $e');
    }
  }

  void _initializeControllerAtIndex(int index) {
    if (_videoUrls.length <= index || index < 0) return;
    if (_controllers.containsKey(index)) return;

    final controller = VideoPlayerController.networkUrl(Uri.parse(_videoUrls[index]));
    _controllers[index] = controller;

    controller.initialize().then((_) {
      if (mounted) {
        setState(() {});
        // 如果是当前页面，自动播放
        if (_pageController.hasClients && _pageController.page?.round() == index) {
          controller.play();
        }
      }
    }).catchError((e) {
      debugPrint("Error initializing video $index: $e");
      if (mounted) {
        _handleVideoError(index);
      }
    });
  }

  void _handleVideoError(int index) {
    // 移除错误的控制器
    _disposeControllerAtIndex(index);
    // 如果是当前展示的视频出错，自动跳到下一个
    if (_pageController.hasClients && _pageController.page?.round() == index) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _disposeControllerAtIndex(int index) {
    if (_controllers.containsKey(index)) {
      _controllers[index]?.dispose();
      _controllers.remove(index);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  void _onVideoFinished() {
    // 播放结束后，自动跳转到下一个视频
    if (_pageController.hasClients && _pageController.page!.round() < _videoUrls.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 视频播放器
          _videoUrls.isEmpty
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : PageView.builder(
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  itemCount: _videoUrls.length,
                  onPageChanged: (index) {
                    // 1. 预加载更多视频 URL
                    if (index >= _videoUrls.length - 2) {
                      _fetchNewVideo();
                    }
                    
                    // 2. 视频控制器管理 (预加载下一个，释放上上个)
                    _initializeControllerAtIndex(index + 1); // 预加载下一个
                    if (index > 0) _controllers[index]?.play(); // 播放当前
                    if (index + 1 < _videoUrls.length) _controllers[index + 1]?.pause(); // 暂停下一个
                    if (index > 0) _controllers[index - 1]?.pause(); // 暂停上一个
                    
                    _disposeControllerAtIndex(index - 2); // 释放之前的资源
                  },
                  itemBuilder: (context, index) {
                    if (!_controllers.containsKey(index)) {
                      _initializeControllerAtIndex(index);
                    }
                    return VideoPlayerItem(
                      key: ValueKey(_videoUrls[index]),
                      controller: _controllers[index]!,
                      onVideoFinished: _onVideoFinished,
                    );
                  },
                ),
          // 底部导航栏
          _buildBottomNavBar(),
        ],
      ),
    );
  }

  // 构建底部导航栏
  Widget _buildBottomNavBar() {
    return const Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: 30.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.home, color: Colors.white, size: 30),
                Text('主页', style: TextStyle(color: Colors.white)),
              ],
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person, color: Colors.white, size: 30),
                Text('我的', style: TextStyle(color: Colors.white)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// 单个视频播放器 Widget
class VideoPlayerItem extends StatefulWidget {
  final VideoPlayerController controller;
  final VoidCallback onVideoFinished;

  const VideoPlayerItem({
    required Key key,
    required this.controller,
    required this.onVideoFinished,
  }) : super(key: key);

  @override
  State<VideoPlayerItem> createState() => _VideoPlayerItemState();
}

class _VideoPlayerItemState extends State<VideoPlayerItem> {
  bool _isFastForwarding = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_videoListener);
    // 如果已经初始化完成，直接播放
    if (widget.controller.value.isInitialized) {
      widget.controller.play();
    }
  }

  @override
  void didUpdateWidget(VideoPlayerItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_videoListener);
      widget.controller.addListener(_videoListener);
      if (widget.controller.value.isInitialized) {
        widget.controller.play();
      }
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_videoListener);
    // 注意：控制器由父组件管理，这里不 dispose
    super.dispose();
  }

  void _videoListener() {
    if (widget.controller.value.position >= widget.controller.value.duration &&
        !widget.controller.value.isLooping &&
        widget.controller.value.duration != Duration.zero) {
      widget.onVideoFinished();
    }
    setState(() {}); // 更新 UI (进度条等)
  }

  void _togglePlay() {
    if (!widget.controller.value.isInitialized) return;
    setState(() {
      if (widget.controller.value.isPlaying) {
        widget.controller.pause();
      } else {
        widget.controller.play();
      }
    });
  }

  void _startFastForward(LongPressStartDetails details) {
    if (!widget.controller.value.isInitialized) return;
    final screenWidth = MediaQuery.of(context).size.width;
    final dx = details.globalPosition.dx;
    // 判断是否在屏幕两侧 (例如左边 20% 或右边 20%)
    if (dx < screenWidth * 0.2 || dx > screenWidth * 0.8) {
      setState(() {
        _isFastForwarding = true;
      });
      widget.controller.setPlaybackSpeed(2.0);
    }
  }

  void _stopFastForward(LongPressEndDetails details) {
    if (!widget.controller.value.isInitialized) return;
    if (_isFastForwarding) {
      setState(() {
        _isFastForwarding = false;
      });
      widget.controller.setPlaybackSpeed(1.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _togglePlay,
      onLongPressStart: _startFastForward,
      onLongPressEnd: _stopFastForward,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: widget.controller.value.isInitialized
                ? AspectRatio(
                    aspectRatio: widget.controller.value.aspectRatio,
                    child: VideoPlayer(widget.controller),
                  )
                : const CircularProgressIndicator(color: Colors.white),
          ),
          // 暂停时显示播放图标
          if (widget.controller.value.isInitialized && !widget.controller.value.isPlaying)
            const Icon(
              Icons.play_arrow,
              size: 60,
              color: Colors.white54,
            ),
          // 倍速播放提示
          if (_isFastForwarding)
            Positioned(
              top: 50,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('2x 倍速播放中', style: TextStyle(color: Colors.white)),
              ),
            ),
          // 进度条
          if (widget.controller.value.isInitialized)
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: VideoProgressIndicator(
                widget.controller,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: Colors.white,
                  bufferedColor: Colors.white24,
                  backgroundColor: Colors.grey,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
