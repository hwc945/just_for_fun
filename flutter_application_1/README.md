# Flutter 仿抖音视频播放器 (Learning Project)

这是一个基于 Flutter 开发的简易短视频播放应用，旨在作为学习 Flutter 和 Dart 语言的实践项目。本项目实现了一个类似抖音（TikTok）的垂直滚动视频播放器，从公开 API 获取随机视频资源。

## 🛠 技术栈与工具

*   **框架**: Flutter (Dart)
*   **核心依赖**:
    *   `video_player`: 视频播放核心能力。
    *   `http`: 处理网络请求。
*   **开发环境**: VS Code

## 📚 学习重点 (Key Concepts)

通过本项目，你可以深入理解以下 Flutter 和 Dart 的核心概念：

### 1. Dart 语言特性
*   **异步编程 (Async/Await)**: 
    *   在 `_fetchNewVideo` 中处理 HTTP 请求。
    *   在 `VideoPlayerController.initialize()` 中处理视频资源的异步加载。
*   **JSON 解析**: 使用 `dart:convert` 库解析 API 返回的数据结构。
*   **空安全 (Null Safety)**: 正确处理可能为空的网络数据和对象状态。

### 2. Flutter 核心组件与机制
*   **PageView.builder**: 
    *   实现高性能的垂直无限滚动列表。
    *   利用 `itemBuilder` 实现按需构建，节省内存。
*   **StatefulWidget 生命周期**: 
    *   `initState`: 初始化视频控制器、监听器。
    *   `dispose`: **至关重要**，用于释放视频控制器资源，防止内存泄漏。
*   **Stack & Positioned**: 
    *   实现视频层（底层）与 UI 交互层（进度条、倍速提示、暂停图标）的叠加布局。
*   **GestureDetector**: 
    *   处理复杂手势：单击暂停/播放，长按触发倍速播放。

## 💡 工具思想与设计模式

*   **组件化 (Componentization)**: 
    *   将单个视频的播放逻辑（加载、播放、暂停、销毁）完全封装在 `VideoPlayerItem` Widget 中。
    *   `VideoFeedScreen` 只负责列表数据的维护和翻页逻辑。这种**关注点分离**使得代码更易维护。
*   **懒加载与预加载 (Lazy Loading & Pre-fetching)**: 
    *   利用 `PageView` 的 `onPageChanged` 回调，在用户浏览当前视频时，提前触发 `_fetchNewVideo`，尝试减少用户等待时间。

## 🚀 优化建议与路线图

### ✅ 立刻可行的优化 (Immediate Next Steps)
1.  **视频预加载 (Pre-caching)**:
    *   **问题**: 目前滑到下一个视频时才开始初始化，会有短暂黑屏。
    *   **方案**: 维护一个 `Map<int, VideoPlayerController>`，在播放当前视频时，静默初始化下一个视频的控制器。
2.  **完善错误处理 UI**:
    *   **问题**: 网络错误或视频解码失败时体验不佳。
    *   **方案**: 添加“点击重试”按钮，或自动跳过错误的视频。
3.  **双击点赞动画**:
    *   **方案**: 使用 `AnimationController` 和 `Stack`，在点击位置展示爱心动画，增加交互趣味性。
4.  **沉浸式体验**:
    *   **方案**: 设置系统状态栏透明 (`SystemChrome.setSystemUIOverlayStyle`)，让视频真正全屏展示。

### 🔮 长期演进 (Long-term Vision)
1.  **状态管理升级 (State Management)**:
    *   随着功能增加（如用户信息、点赞列表），`setState` 会变得难以维护。
    *   **建议**: 引入 `Provider`、`Bloc` 或 `Riverpod` 来管理全局应用状态。
2.  **本地缓存与持久化**:
    *   **建议**: 使用 `flutter_cache_manager` 缓存视频文件，节省用户流量。使用 `sqflite` 或 `Isar` 保存用户的收藏列表。
3.  **真正的后端集成**:
    *   **建议**: 对接 Firebase 或自建 Go/Node.js 后端，实现用户注册、视频上传、评论互动等完整社交功能。
4.  **UI/UX 细节打磨**:
    *   添加视频封面的占位图（BlurHash），在视频加载前显示模糊背景，提升视觉连续性。

## 📦 如何运行

1.  确保已安装 Flutter SDK。
2.  克隆本项目到本地。
3.  在项目根目录运行 `flutter pub get` 安装依赖。
4.  连接 Android/iOS 设备或模拟器。
5.  运行 `flutter run`。

---
*Just for fun, keep coding!*
