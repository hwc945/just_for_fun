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
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching video: $e');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
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
                    // 预加载更多视频
                    if (index >= _videoUrls.length - 2) {
                      _fetchNewVideo();
                    }
                  },
                  itemBuilder: (context, index) {
                    return VideoPlayerItem(
                      key: ValueKey(_videoUrls[index]), // 使用 ValueKey
                      videoUrl: _videoUrls[index],
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
  final String videoUrl;
  final VoidCallback onVideoFinished;

  const VideoPlayerItem({
    required Key key,
    required this.videoUrl,
    required this.onVideoFinished,
  }) : super(key: key);

  @override
  State<VideoPlayerItem> createState() => _VideoPlayerItemState();
}

class _VideoPlayerItemState extends State<VideoPlayerItem> {
  late VideoPlayerController _controller;
  late Future<void> _initializeVideoPlayerFuture;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _initializeVideoPlayerFuture = _controller.initialize().then((_) {
      // 初始化成功后，开始播放
      _controller.play();
      setState(() {});
    });

    // 监听视频播放，结束后调用回调
    _controller.addListener(() {
      if (_controller.value.position >= _controller.value.duration && !_controller.value.isLooping) {
        widget.onVideoFinished();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FutureBuilder(
        future: _initializeVideoPlayerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.hasError) {
              return Center(child: Text('视频加载失败: ${snapshot.error}'));
            }
            return AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            );
          } else {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }
        },
      ),
    );
  }
}
