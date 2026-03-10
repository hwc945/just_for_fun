# Flutter 仿抖音视频播放器 (Learning Project)

这是一个基于 Flutter 开发的简易短视频播放应用，旨在作为学习 Flutter 和 Dart 语言的实践项目。本项目实现了一个类似抖音（TikTok）的垂直滚动视频播放器，从公开 API 获取随机视频资源。

## 🛠 技术栈与工具

*   **框架**: Flutter (Dart)
*   **核心依赖**:
    *   `video_player`: 视频播放核心能力。
    *   `http`: 处理网络请求。
    *   `wakelock_plus`: 保持屏幕常亮，防止播放时自动息屏。
*   **开发环境**: VS Code

## 📚 学习重点 (Key Concepts)

通过本项目，你可以深入理解以下 Flutter 和 Dart 的核心概念：

### 1. Dart 语言特性
*   **异步编程 (Async/Await)**: 
    *   在 `_fetchNewVideo` 中处理 HTTP 请求。
    *   在 `VideoPlayerController.initialize()` 中处理视频资源的异步加载。
*   **JSON 解析**: 使用 `dart:convert` 库解析 API 返回的数据结构。
*   **集合操作**: 使用 `Map<int, VideoPlayerController>` 精确管理视频控制器的生命周期。

### 2. Flutter 核心组件与机制
*   **PageView.builder**: 
    *   实现高性能的垂直无限滚动列表。
    *   利用 `itemBuilder` 实现按需构建，节省内存。
*   **StatefulWidget 生命周期**: 
    *   `initState`: 初始化视频控制器、监听器。
    *   `dispose`: **至关重要**，用于释放视频控制器资源和 Wakelock，防止内存泄漏。
    *   `didUpdateWidget`: 处理组件复用时的状态更新。
*   **交互与手势**: 
    *   `GestureDetector`: 处理单击暂停/播放，长按二倍速播放。
    *   `VideoProgressIndicator`: 可拖拽的视频进度条。
*   **屏幕常亮**: 使用 `wakelock_plus` 在视频播放期间保持屏幕唤醒状态。

## 💡 工具思想与设计模式

*   **预加载策略 (Pre-caching Strategy)**: 
    *   维护一个控制器 Map，在播放当前视频(`index`)时，自动初始化下一个视频(`index + 1`)。
    *   自动销毁不再需要的视频资源(`index - 2`)，在流畅体验与内存占用之间取得平衡。
*   **容错处理 (Error Handling)**:
    *   捕获视频初始化错误，自动跳过无法播放的视频，保证用户体验的连续性。
*   **组件化 (Componentization)**: 
    *   `VideoPlayerItem` 专注于单个视频的 UI 呈现和交互逻辑。
    *   `VideoFeedScreen` 专注于数据流、翻页逻辑和全局资源管理。

## 🚀 优化建议与路线图

详细的项目规划、缺点分析及未来方向请参考文档：[项目规划.md](./项目规划.md)


## 📦 如何运行

1. 确保已安装 Flutter SDK。
2. 克隆本项目到本地。
3. 在项目根目录运行 `flutter pub get` 安装依赖。
4. 连接 Android/iOS 设备或模拟器。
5. 运行 `flutter run`。

---

*Just for fun, keep coding!*

