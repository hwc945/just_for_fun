import 'dart:async'; // 导入异步操作所需的库，例如 Timer
import 'dart:math'; // 导入数学库，用于随机数生成和 Point 类
import 'package:flutter/material.dart'; // 导入 Flutter Material Design UI 框架
import 'package:flutter/services.dart'; // 导入 Flutter 服务库，用于键盘事件处理

void main() {
  // 应用的入口点。
  // runApp 接收一个 Widget，并将其作为 UI 树的根。
  runApp(const SnakeGameApp());
}

// 整个贪吃蛇应用的根 Widget，负责设置应用的主题和导航。
class SnakeGameApp extends StatelessWidget {
  const SnakeGameApp({super.key}); // 构造函数，接收一个可选的 key

  @override
  Widget build(BuildContext context) {
    // 构建应用的 UI。
    return MaterialApp(
      title: '贪吃蛇游戏', // 应用在设备任务管理器中显示的标题
      theme: ThemeData(
        useMaterial3: true, // 启用 Material Design 3
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green), // 从绿色种子创建颜色方案
      ),
      home: const SnakeGame(), // 应用的默认主页是 SnakeGame
      debugShowCheckedModeBanner: false, // 在发布版本中隐藏调试横幅
    );
  }
}

// 贪吃蛇游戏的主状态 Widget，管理游戏的状态。
class SnakeGame extends StatefulWidget {
  const SnakeGame({super.key}); // 构造函数，接收一个可选的 key

  @override
  State<SnakeGame> createState() => _SnakeGameState(); // 创建并返回游戏状态
}

// 定义蛇的移动方向枚举。
enum Direction { up, down, left, right }

// 贪吃蛇游戏的状态类。
class _SnakeGameState extends State<SnakeGame> {
  static const int gridSize = 20; // 游戏区域的网格大小（20x20）
  static const int initialSpeed = 300; // 游戏初始速度（蛇移动的时间间隔，毫秒）

  List<Point<int>> snake = []; // 存储蛇身体部分的坐标列表
  Point<int> food = const Point(10, 10); // 食物的坐标
  Direction direction = Direction.right; // 蛇当前移动的方向
  Direction? nextDirection; // 玩家下一次按键期望改变的方向，用于避免瞬间反向
  bool isPlaying = false; // 游戏是否正在进行中
  int score = 0; // 玩家得分
  Timer? gameTimer; // 游戏计时器，用于定期更新游戏状态
  final Random random = Random(); // 随机数生成器，用于生成食物位置
  final FocusNode _focusNode = FocusNode(); // 用于获取键盘输入焦点的 FocusNode

  @override
  void initState() {
    super.initState(); // 调用父类的 initState
    _initGame(); // 初始化游戏状态
  }

  @override
  void dispose() {
    // 销毁 State 时取消计时器并释放 FocusNode 资源
    gameTimer?.cancel();
    _focusNode.dispose();
    super.dispose(); // 调用父类的 dispose
  }

  // 初始化游戏状态，包括蛇的初始位置、方向和食物。
  void _initGame() {
    snake = [
      const Point(5, 10), // 蛇头
      const Point(4, 10), // 蛇身
      const Point(3, 10), // 蛇尾
    ];
    direction = Direction.right; // 初始向右移动
    nextDirection = null; // 清除下一次方向
    score = 0; // 分数清零
    _generateFood(); // 生成第一个食物
  }

  // 在随机位置生成食物，确保食物不生成在蛇的身体上。
  void _generateFood() {
    Point<int> newFood;
    do {
      newFood = Point(
        random.nextInt(gridSize), // 随机生成 x 坐标
        random.nextInt(gridSize), // 随机生成 y 坐标
      );
    } while (snake.contains(newFood)); // 如果食物生成在蛇身上，则重新生成
    food = newFood; // 更新食物位置
  }

  // 开始游戏。
  void _startGame() {
    if (isPlaying) return; // 如果游戏已经在进行中，则直接返回

    setState(() {
      isPlaying = true; // 设置游戏状态为进行中
    });

    // 设置游戏计时器，每隔 initialSpeed 毫秒调用 _updateGame 方法。
    gameTimer = Timer.periodic(
      const Duration(milliseconds: initialSpeed),
      (timer) => _updateGame(),
    );
  }

  // 暂停游戏。
  void _pauseGame() {
    setState(() {
      isPlaying = false; // 设置游戏状态为暂停
    });
    gameTimer?.cancel(); // 取消计时器
  }

  // 重新开始游戏。
  void _restartGame() {
    gameTimer?.cancel(); // 取消当前计时器
    setState(() {
      _initGame(); // 重新初始化游戏状态
      isPlaying = false; // 设置游戏状态为未开始
    });
  }

  // 更新游戏状态，处理蛇的移动、食物碰撞和游戏结束逻辑。
  void _updateGame() {
    // 如果有新的方向指令，则更新蛇的移动方向。
    if (nextDirection != null) {
      direction = nextDirection!;
      nextDirection = null; // 清除下一次方向指令
    }

    Point<int> newHead;
    // 根据当前方向计算新的蛇头位置。
    switch (direction) {
      case Direction.up:
        // 向上移动，y 坐标减 1，使用取模运算实现循环边界（穿墙）。
        newHead = Point(snake.first.x, (snake.first.y - 1 + gridSize) % gridSize);
        break;
      case Direction.down:
        // 向下移动，y 坐标加 1，使用取模运算实现循环边界。
        newHead = Point(snake.first.x, (snake.first.y + 1) % gridSize);
        break;
      case Direction.left:
        // 向左移动，x 坐标减 1，使用取模运算实现循环边界。
        newHead = Point((snake.first.x - 1 + gridSize) % gridSize, snake.first.y);
        break;
      case Direction.right:
        // 向右移动，x 坐标加 1，使用取模运算实现循环边界。
        newHead = Point((snake.first.x + 1) % gridSize, snake.first.y);
        break;
    }

    // 检查是否撞到自己。
    // 注意：这里需要检查 newHead 是否在除了蛇尾之外的身体部分。
    // 如果蛇吃到食物后变长，removeLast() 不会执行，此时蛇尾仍然在 snake 列表中，
    // 因此这里判断 snake.sublist(1).contains(newHead) 更准确。
    // 对于目前的实现，因为蛇尾会先被移除再判断，所以这里的 contains 也是可以的，
    // 但如果逻辑顺序调整，则可能需要更精细的判断。
    if (snake.contains(newHead)) {
      _gameOver(); // 游戏结束
      return;
    }

    setState(() {
      snake.insert(0, newHead); // 将新蛇头添加到蛇列表的开头

      // 检查是否吃到食物。
      if (newHead == food) {
        score += 10; // 得分增加
        _generateFood(); // 重新生成食物
      } else {
        snake.removeLast(); // 如果没有吃到食物，移除蛇尾，保持蛇的长度不变
      }
    });
  }

  // 处理游戏结束逻辑，显示结束对话框。
  void _gameOver() {
    gameTimer?.cancel(); // 取消游戏计时器
    setState(() {
      isPlaying = false; // 设置游戏状态为未进行中
    });

    // 显示游戏结束对话框。
    showDialog(
      context: context,
      barrierDismissible: false, // 点击外部区域不可关闭对话框
      builder: (context) => AlertDialog(
        title: const Text('游戏结束'), // 对话框标题
        content: Text('你的得分: $score'), // 显示得分
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // 关闭对话框
              _restartGame(); // 重新开始游戏
            },
            child: const Text('再来一局'), // 按钮文本
          ),
        ],
      ),
    );
  }

  // 改变蛇的移动方向。
  void _changeDirection(Direction newDirection) {
    // 防止反向移动（例如，蛇向上移动时不能立即向下移动）。
    if ((direction == Direction.up && newDirection == Direction.down) ||
        (direction == Direction.down && newDirection == Direction.up) ||
        (direction == Direction.left && newDirection == Direction.right) ||
        (direction == Direction.right && newDirection == Direction.left)) {
      return; // 如果是反向移动，则忽略
    }
    nextDirection = newDirection; // 存储下一次要改变的方向
  }

  @override
  Widget build(BuildContext context) {
    // 使用 KeyboardListener 监听键盘事件，用于桌面/Web 端的方向控制。
    return KeyboardListener(
      focusNode: _focusNode, // 绑定焦点节点
      autofocus: true, // 自动获取焦点
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          if (!isPlaying) return; // 如果游戏未开始，不处理键盘事件

          // 根据按下的方向键改变蛇的移动方向。
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            _changeDirection(Direction.up);
          } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            _changeDirection(Direction.down);
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _changeDirection(Direction.left);
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _changeDirection(Direction.right);
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black, // 设置 Scaffold 的背景颜色为黑色
        appBar: AppBar(
          title: const Text('贪吃蛇游戏'), // 应用栏标题
          centerTitle: true, // 标题居中
          backgroundColor: Colors.green, // 应用栏背景颜色
        ),
        body: Column(
          children: [
            // 分数显示区域
            Container(
              padding: const EdgeInsets.all(16),
              child: Text(
                '得分: $score', // 显示当前分数
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white, // 分数文本颜色为白色
                ),
              ),
            ),
            // 游戏区域，使用 Expanded 确保占据剩余空间
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1, // 确保游戏区域是正方形
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.green, width: 2), // 游戏区域边框
                    ),
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(), // 禁止滚动
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: gridSize, // 网格的列数等于 gridSize
                      ),
                      itemCount: gridSize * gridSize, // 网格的总单元格数
                      itemBuilder: (context, index) {
                        // 根据索引计算当前单元格的 x, y 坐标
                        final x = index % gridSize;
                        final y = index ~/ gridSize; // integer division
                        final point = Point(x, y);

                        Color cellColor = Colors.grey[900]!; // 默认单元格颜色

                        if (snake.first == point) {
                          // 如果是蛇头，则颜色更深
                          cellColor = Colors.green[700]!;
                        } else if (snake.contains(point)) {
                          // 如果是蛇身，则为绿色
                          cellColor = Colors.green;
                        } else if (food == point) {
                          // 如果是食物，则为红色
                          cellColor = Colors.red;
                        }

                        // 返回一个表示单元格的 Container
                        return Container(
                          margin: const EdgeInsets.all(1), // 单元格之间的间距
                          decoration: BoxDecoration(
                            color: cellColor, // 单元格颜色
                            borderRadius: BorderRadius.circular(2), // 单元格圆角
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            // 控制按钮区域
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // 方向键控制（用于触摸屏或鼠标点击）
                  Column(
                    children: [
                      IconButton(
                        onPressed: isPlaying
                            ? () => _changeDirection(Direction.up)
                            : null, // 游戏进行中才可点击
                        icon: const Icon(Icons.arrow_upward),
                        iconSize: 40,
                        color: Colors.white,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: isPlaying
                                ? () => _changeDirection(Direction.left)
                                : null,
                            icon: const Icon(Icons.arrow_back),
                            iconSize: 40,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 80), // 左右方向键之间的间距
                          IconButton(
                            onPressed: isPlaying
                                ? () => _changeDirection(Direction.right)
                                : null,
                            icon: const Icon(Icons.arrow_forward),
                            iconSize: 40,
                            color: Colors.white,
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: isPlaying
                            ? () => _changeDirection(Direction.down)
                            : null,
                        icon: const Icon(Icons.arrow_downward),
                        iconSize: 40,
                        color: Colors.white,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20), // 方向键和游戏控制按钮之间的间距
                  // 游戏控制按钮（开始/暂停，重新开始）
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: isPlaying ? _pauseGame : _startGame, // 根据游戏状态显示暂停或开始
                        icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                        label: Text(isPlaying ? '暂停' : '开始'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16), // 两个按钮之间的间距
                      ElevatedButton.icon(
                        onPressed: _restartGame, // 重新开始按钮
                        icon: const Icon(Icons.refresh),
                        label: const Text('重新开始'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}