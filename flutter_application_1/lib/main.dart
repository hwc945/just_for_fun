import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'package:wakelock_plus/wakelock_plus.dart';

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
  int _currentIndex = 0;
  int _currentTabIndex = 0; // 当前选中的底部 Tab 索引

  // 1: 随机视频 (主页), 2: 巴旦木公主 (我的)
  int _currentVideoSource = 1; 

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadInitialVideos();
  }

  void _wakelockListener() {
    final controller = _controllers[_currentIndex]; 
    if (controller != null && controller.value.isPlaying) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  void _attachWakelockListener(int index) {
    final controller = _controllers[index];
    if (controller != null) {
      controller.addListener(_wakelockListener);
      // 立即检查一次状态
      _wakelockListener();
    }
  }

  void _detachWakelockListener(int index) {
    final controller = _controllers[index];
    if (controller != null) {
      controller.removeListener(_wakelockListener);
    }
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
      if (_currentVideoSource == 2) {
        // 巴旦木公主博主视频的占位
        // 实际开发中需要对应的后端 API 或者爬虫接口来获取对应主页的所有视频
        // 目前返回一些占位视频 URL 或者依然获取随机视频进行演示
        // 由于没有真实 API，此处可以提示用户，或者继续请求测试视频
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('正在获取巴旦木公主的视频，此处使用测试接口占位...')),
          );
        }
      }

      final response = await http.get(Uri.parse('https://www.douyin.com/user/MS4wLjABAAAADw1dDJd4zddv0m8KWQB7ztFV0Nt8QzIK7dpFvbsrXss?from_tab_name=main&modal_id=7457451823201291578'));
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
          // 确保监听器已附加（如果是当前页）
          if (index == _currentIndex) {
             _attachWakelockListener(index);
          }
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
      // 如果正在监听这个控制器，先移除监听
      if (index == _currentIndex) {
        _detachWakelockListener(index);
      }
      _controllers[index]?.dispose();
      _controllers.remove(index);
    }
  }

  @override
  void dispose() {
    _detachWakelockListener(_currentIndex);
    WakelockPlus.disable();
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
          // 页面内容
          if (_currentTabIndex == 0)
            _buildVideoFeed()
          else
            _buildProfileScreen(),
          
          // 底部导航栏
          _buildBottomNavBar(),
        ],
      ),
    );
  }

  Widget _buildVideoFeed() {
    return _videoUrls.isEmpty
        ? const Center(child: CircularProgressIndicator(color: Colors.white))
        : PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: _videoUrls.length,
            onPageChanged: (index) {
              // 切换监听器
              _detachWakelockListener(_currentIndex);
              _currentIndex = index;
              _attachWakelockListener(_currentIndex);

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
          );
  }

  void _switchVideoSource(int sourceId) {
    setState(() {
      _currentTabIndex = 0; // 切换回主页播放
      _currentVideoSource = sourceId;
      _videoUrls.clear();
      _controllers.forEach((_, controller) => controller.dispose());
      _controllers.clear();
      _isLoading = false;
      _currentIndex = 0;
      // 重新实例化控制器避免越界
      _pageController.dispose();
      _pageController = PageController();
    });
    _loadInitialVideos();
  }

  Widget _buildProfileScreen() {
    return Container(
      color: Colors.black,
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircleAvatar(
            radius: 50,
            backgroundImage: NetworkImage('https://p11.douyinpic.com/aweme/1080x1080/aweme-avatar/tos-cn-avt-0015_939a2b53b94b0d01d14690f05f778f9f.jpeg?from=116350172'),
          ),
          const SizedBox(height: 20),
          const Text(
            '我的主页',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pinkAccent,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已切换到"巴旦木公主"视频列表')),
              );
              _switchVideoSource(2);
            },
            child: const Text(
              '看巴旦木公主',
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
          )
        ],
      ),
    );
  }

  // 构建底部导航栏
  Widget _buildBottomNavBar() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: const EdgeInsets.only(bottom: 20.0, top: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withOpacity(0.8), Colors.transparent],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  _currentTabIndex = 0;
                });
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.home, color: _currentTabIndex == 0 ? Colors.white : Colors.white54, size: 30),
                  Text('主页', style: TextStyle(color: _currentTabIndex == 0 ? Colors.white : Colors.white54)),
                ],
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _currentTabIndex = 1;
                });
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person, color: _currentTabIndex == 1 ? Colors.white : Colors.white54, size: 30),
                  Text('我的', style: TextStyle(color: _currentTabIndex == 1 ? Colors.white : Colors.white54)),
                ],
              ),
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
  bool _hasTriggeredFinish = false;

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
      _hasTriggeredFinish = false; // 重置标志位
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
    final value = widget.controller.value;
    if (value.position >= value.duration &&
        !value.isLooping &&
        value.duration != Duration.zero) {
      if (!_hasTriggeredFinish) {
        _hasTriggeredFinish = true;
        widget.onVideoFinished();
      }
    } else {
      // 如果未结束，重置标志位
      if (value.position < value.duration && _hasTriggeredFinish) {
        _hasTriggeredFinish = false;
      }
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
