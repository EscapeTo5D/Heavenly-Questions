import 'dart:collection';
import 'package:flutter/material.dart';
import 'dart:async';
import '../constants/theme.dart';
import '../models/nasa_apod.dart';
import '../services/nasa_service.dart';
import '../services/local_storage_service.dart';

// 全局缓存，确保即使widget被销毁也能保持图片数据
final Map<String, NasaApod> _globalCachedApods = HashMap<String, NasaApod>();
// 全局标志，标记是否已经初始化过
bool _globalInitialized = false;
// 全局保存的图片列表
List<NasaApod> _globalApodList = [];
// 全局记录的当前日期
DateTime _globalCurrentDate = DateTime.now();
// 全局保存滚动位置
double _globalScrollPosition = 0.0;

class NasaScreen extends StatefulWidget {
  const NasaScreen({super.key});

  @override
  State<NasaScreen> createState() => _NasaScreenState();
}

class _NasaScreenState extends State<NasaScreen>
    with AutomaticKeepAliveClientMixin {
  final NasaService _nasaService = NasaService();
  final LocalStorageService _storageService = LocalStorageService();
  late ScrollController _scrollController;

  // 使用getter获取缓存，确保同步
  Map<String, NasaApod> get _cachedApods => _globalCachedApods;

  List<NasaApod> _apodList = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;
  DateTime _currentDate = DateTime.now();
  bool _hasMore = true;
  bool _isMounted = true;

  // 标志位，用于跟踪初始加载是否已完成
  bool _initialLoadComplete = false;

  // 标记是否已恢复过滚动位置
  bool _hasRestoredScrollPosition = false;

  // 最大重试次数
  static const int _maxRetries = 3;

  // API限流控制
  static const Duration _initialBackoff = Duration(seconds: 1);
  static const int _maxBackoffSeconds = 30;

  // 用于跟踪失败的日期，以便重试
  final Map<String, int> _failedDates = HashMap<String, int>();

  // 上次请求时间
  DateTime _lastRequestTime =
      DateTime.now().subtract(const Duration(seconds: 5));

  @override
  void initState() {
    super.initState();

    // 初始化时先尝试从本地存储加载数据
    _initFromLocalStorage();
  }

  Future<void> _initFromLocalStorage() async {
    setState(() {
      _isLoading = true;
    });

    // 从本地存储加载初始化标志
    final isInitialized = await _storageService.getInitialized();

    if (isInitialized) {
      try {
        // 加载保存的滚动位置
        final savedScrollPosition =
            await _storageService.getSavedScrollPosition();
        _globalScrollPosition = savedScrollPosition;

        // 加载保存的当前日期
        final savedCurrentDate = await _storageService.getSavedCurrentDate();
        if (savedCurrentDate != null) {
          _currentDate = savedCurrentDate;
          _globalCurrentDate = savedCurrentDate;
        }

        // 加载保存的APOD列表
        final savedApods = await _storageService.getAllApods();
        if (savedApods.isNotEmpty) {
          // 更新全局和内存缓存
          _apodList = savedApods;
          _globalApodList = List.from(savedApods);

          // 更新缓存Map
          for (final apod in savedApods) {
            _globalCachedApods[apod.date] = apod;
          }

          _initialLoadComplete = true;
          _globalInitialized = true;

          // 初始化ScrollController并恢复位置
          _scrollController = ScrollController(
            initialScrollOffset: _globalScrollPosition,
          );

          _scrollController.addListener(_onScroll);

          setState(() {
            _isLoading = false;
          });

          // 确保在UI构建后恢复滚动位置
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_hasRestoredScrollPosition && _scrollController.hasClients) {
              _scrollController.jumpTo(_globalScrollPosition);
              _hasRestoredScrollPosition = true;
            }
          });

          return;
        }
      } catch (e) {
        print('从本地存储加载数据时出错: $e');
      }
    }

    // 如果没有保存的数据或加载失败，则执行常规初始化
    _scrollController = ScrollController(
      initialScrollOffset: _globalScrollPosition,
    );

    _scrollController.addListener(_onScroll);

    await _loadApodList();
  }

  @override
  void dispose() {
    // 将数据保存到全局缓存
    _globalApodList = List.from(_apodList);
    _globalCurrentDate = _currentDate;
    _globalInitialized = true;

    // 保存当前滚动位置
    if (_scrollController.hasClients) {
      _globalScrollPosition = _scrollController.offset;
      _storageService.saveScrollPosition(_globalScrollPosition);
    }

    // 保存当前日期
    _storageService.saveCurrentDate(_currentDate);

    // 设置初始化标志
    _storageService.setInitialized(true);

    _isMounted = false;
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _nasaService.dispose(); // 释放HTTP客户端资源
    super.dispose();
  }

  // 实现AutomaticKeepAliveClientMixin所需的方法
  @override
  bool get wantKeepAlive => true;

  // 监听滚动事件
  void _onScroll() {
    if (!mounted) return;

    // 保存当前滚动位置
    if (_scrollController.hasClients) {
      _globalScrollPosition = _scrollController.offset;
      // 节流保存：只在停止滚动时保存位置
      _debounceScrollPositionSave();
    }

    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMoreApod();
    }
  }

  // 滚动位置保存节流器
  Timer? _scrollSaveTimer;
  void _debounceScrollPositionSave() {
    if (_scrollSaveTimer?.isActive ?? false) {
      _scrollSaveTimer?.cancel();
    }
    _scrollSaveTimer = Timer(const Duration(seconds: 1), () {
      _storageService.saveScrollPosition(_globalScrollPosition);
    });
  }

  // 加载多天的NASA每日一图
  Future<void> _loadApodList() async {
    if (!mounted) return;

    setState(() {
      // 只有在第一次加载或强制刷新时才显示加载状态
      if (!_initialLoadComplete) {
        _isLoading = true;
        _apodList = [];
        _currentDate = DateTime.now();
        _failedDates.clear(); // 清空失败记录
      }
      _errorMessage = null;
    });

    try {
      await _loadMoreApod();

      if (mounted) {
        setState(() {
          _initialLoadComplete = true;
          _isLoading = false; // 确保加载完成后状态正确

          // 更新全局缓存
          _globalApodList = List.from(_apodList);
          _globalCurrentDate = _currentDate;
          _globalInitialized = true;
        });

        // 保存到本地存储
        await _storageService.saveApods(_apodList);
        await _storageService.saveCurrentDate(_currentDate);
        await _storageService.setInitialized(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // 获取格式化日期字符串
  String _getFormattedDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // 带有超时和重试功能的图片获取方法
  Future<NasaApod?> _fetchApodWithRetry(DateTime date) async {
    final String formattedDate = _getFormattedDate(date);

    // 首先检查本地存储
    final cachedApod = await _storageService.getApodByDate(formattedDate);
    if (cachedApod != null) {
      // 添加到内存缓存
      _globalCachedApods[formattedDate] = cachedApod;
      return cachedApod;
    }

    // 检查重试次数是否已达上限
    final int retryCount = _failedDates[formattedDate] ?? 0;
    if (retryCount >= _maxRetries) {
      print('已达重试上限，跳过日期: $formattedDate');
      return null;
    }

    try {
      // 添加API速率限制控制
      final now = DateTime.now();
      final timeSinceLastRequest = now.difference(_lastRequestTime);
      if (timeSinceLastRequest < const Duration(milliseconds: 1000)) {
        // 确保请求间隔至少1秒
        final waitTime =
            const Duration(milliseconds: 1000) - timeSinceLastRequest;
        await Future.delayed(waitTime);
      }

      _lastRequestTime = DateTime.now();

      // 使用8秒超时获取数据
      final apod = await _nasaService
          .getAstronomyPictureByDate(date)
          .timeout(const Duration(seconds: 8));

      // 获取成功则从失败记录中移除
      if (_failedDates.containsKey(formattedDate)) {
        _failedDates.remove(formattedDate);
      }

      // 保存到全局缓存
      _globalCachedApods[formattedDate] = apod;

      // 保存到本地存储
      await _storageService.saveApod(apod);

      return apod;
    } catch (e) {
      // 更新失败计数
      _failedDates[formattedDate] = retryCount + 1;

      // 检查是否为429错误（请求过多）
      final bool isRateLimitError = e.toString().contains('429');

      // 计算指数退避等待时间
      Duration backoffTime = _initialBackoff;
      if (isRateLimitError) {
        // 对于429错误使用指数退避
        final int backoffSeconds =
            _initialBackoff.inSeconds * (1 << retryCount);
        backoffTime = Duration(
            seconds: backoffSeconds > _maxBackoffSeconds
                ? _maxBackoffSeconds
                : backoffSeconds);
        print('API限流(429)，等待 ${backoffTime.inSeconds} 秒后重试');
        await Future.delayed(backoffTime);
      }

      print('获取日期 $formattedDate 的图片失败, 已重试 ${retryCount + 1} 次: $e');
      return null;
    }
  }

  // 并行加载更多NASA每日一图
  Future<void> _loadMoreApod() async {
    if (_isLoadingMore || !_hasMore || !mounted) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final List<Future<NasaApod?>> futures = [];
      final List<DateTime> dates = [];
      DateTime date = _currentDate;

      // 减少并行请求数，从10个减少到6个，避免触发API限流
      for (int i = 0; i < 6; i++) {
        final String formattedDate = _getFormattedDate(date);

        // 检查缓存中是否已有此日期的数据
        if (_cachedApods.containsKey(formattedDate)) {
          dates.add(date);
          futures.add(Future.value(_cachedApods[formattedDate]));
        } else {
          dates.add(date);
          futures.add(_fetchApodWithRetry(date));
        }

        date = date.subtract(const Duration(days: 1));

        if (date.isBefore(DateTime(1995, 6, 16))) {
          _hasMore = false;
          break;
        }
      }

      // 顺序执行请求而不是并行，以避免触发API限流
      final List<NasaApod?> results = [];
      for (int i = 0; i < futures.length; i++) {
        try {
          final result = await futures[i];
          results.add(result);
        } catch (e) {
          results.add(null);
        }

        // 每个请求之间等待一秒
        if (i < futures.length - 1) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }

      if (!_isMounted) return;

      // 处理结果
      final List<NasaApod> newApodList = [];

      for (int i = 0; i < results.length; i++) {
        if (results[i] != null) {
          // 过滤掉视频类型
          if (results[i]!.mediaType != 'video') {
            newApodList.add(results[i]!);
            final String formattedDate = _getFormattedDate(dates[i]);
            _cachedApods[formattedDate] = results[i]!;
          }
        }
      }

      // 对新获取的图片按日期排序（降序，最新日期优先）
      newApodList.sort((a, b) => b.date.compareTo(a.date));

      // 更新日期指针
      if (dates.isNotEmpty) {
        _currentDate = dates.last.subtract(const Duration(days: 1));
      }

      if (mounted) {
        setState(() {
          // 确保列表按日期排序
          _apodList.addAll(newApodList);
          _apodList.sort((a, b) => b.date.compareTo(a.date));
          _isLoading = false;
          _isLoadingMore = false;
        });
      }

      // 重试获取那些失败但未达到重试上限的日期
      _retryFailedDates();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  // 重试获取失败的日期
  Future<void> _retryFailedDates() async {
    if (!mounted || _failedDates.isEmpty) return;

    // 获取所有需要重试且未达到重试上限的日期
    final List<String> datesToRetry = _failedDates.entries
        .where((entry) => entry.value < _maxRetries)
        .map((entry) => entry.key)
        .toList();

    if (datesToRetry.isEmpty) return;

    print('重试加载 ${datesToRetry.length} 个日期的图片');

    // 延迟2秒后开始重试，避免连续请求
    await Future.delayed(const Duration(seconds: 2));

    for (final dateStr in datesToRetry) {
      if (!mounted) return;

      try {
        final date = DateTime.parse(dateStr);
        final apod = await _fetchApodWithRetry(date);

        if (apod != null && apod.mediaType != 'video') {
          if (mounted) {
            setState(() {
              // 添加到缓存和列表
              _globalCachedApods[dateStr] = apod;

              // 检查是否已存在相同日期的项
              final existingIndex =
                  _apodList.indexWhere((item) => item.date == dateStr);
              if (existingIndex >= 0) {
                _apodList[existingIndex] = apod;
              } else {
                _apodList.add(apod);
                // 重新排序
                _apodList.sort((a, b) => b.date.compareTo(a.date));
              }

              // 更新全局列表
              _globalApodList = List.from(_apodList);
            });
          }
        }
      } catch (e) {
        print('重试加载日期 $dateStr 失败: $e');
      }

      // 每次重试之间延迟时间更长，避免API限流
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  // 重置当前日期并刷新数据
  Future<void> _refreshData() async {
    if (!mounted) return;

    setState(() {
      _hasMore = true;
      _failedDates.clear();
      _apodList = [];
      _currentDate = DateTime.now();
      _initialLoadComplete = false; // 重置初始加载标志
      _isLoading = true;

      // 重置全局缓存
      _globalApodList = [];
      _globalCurrentDate = DateTime.now();
      _globalScrollPosition = 0.0; // 重置滚动位置

      // 确保滚动到顶部
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });

    // 保存重置后的状态
    await _storageService.saveScrollPosition(0.0);
    await _storageService.saveCurrentDate(_currentDate);

    await _loadApodList();
  }

  // 清除所有缓存
  Future<void> _clearCache() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    await _storageService.clearAllCache();

    setState(() {
      _hasMore = true;
      _failedDates.clear();
      _apodList = [];
      _currentDate = DateTime.now();
      _initialLoadComplete = false;
      _globalApodList = [];
      _globalCachedApods.clear();
      _globalCurrentDate = DateTime.now();
      _globalScrollPosition = 0.0;
      _globalInitialized = false;

      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });

    await _loadApodList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: AppTheme.darkBlue,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: GestureDetector(
          onDoubleTap: _scrollToTop, // 双击AppBar返回顶部
          child: AppBar(
            backgroundColor: AppTheme.darkBlue,
            title: const Text(
              'NASA每日一图',
              style: TextStyle(color: AppTheme.white),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.calendar_today, color: AppTheme.white),
                onPressed: _showDatePicker,
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: AppTheme.white),
                onPressed: _refreshData,
              ),
              // 添加清除缓存按钮
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppTheme.white),
                onPressed: _clearCache,
                tooltip: '清除缓存',
              ),
            ],
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // 如果有数据，无论是否加载中都显示列表
    if (_apodList.isNotEmpty) {
      return _buildApodListView();
    }

    // 无数据且加载中
    if (_isLoading) {
      return const Center(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppTheme.purple),
          SizedBox(height: 16),
          Text(
            '正在加载NASA图片...',
            style: TextStyle(color: AppTheme.white),
          ),
        ],
      ));
    }

    // 有错误且无数据
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppTheme.purple, size: 60),
            const SizedBox(height: 16),
            const Text(
              '加载失败',
              style: TextStyle(color: AppTheme.white, fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: const TextStyle(color: AppTheme.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadApodList,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.purple,
              ),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    // 无数据无错误无加载中（可能是初始状态或加载失败）
    return const Center(
        child: Text('无数据', style: TextStyle(color: AppTheme.white)));
  }

  // 提取图片列表视图为单独方法
  Widget _buildApodListView() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: AppTheme.purple,
      backgroundColor: AppTheme.midBlue,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // 移除顶部双击提示文本
          SliverPadding(
            padding: const EdgeInsets.all(12),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // 两列布局
                childAspectRatio: 0.68, // 调整宽高比
                crossAxisSpacing: 12, // 水平间距
                mainAxisSpacing: 12, // 垂直间距
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final apod = _apodList[index];
                  return _buildApodCard(apod);
                },
                childCount: _apodList.length,
              ),
            ),
          ),
          if (_hasMore || _isLoadingMore)
            SliverToBoxAdapter(
              child: _buildLoadMoreIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: _isLoadingMore
            ? const CircularProgressIndicator(color: AppTheme.purple)
            : Container(),
      ),
    );
  }

  Widget _buildApodCard(NasaApod apod) {
    bool isVideo = apod.mediaType == 'video';
    // 尝试获取缩略图 URL，如果主 URL 是视频链接
    String imageUrl =
        (isVideo && apod.thumbnailUrl != null) ? apod.thumbnailUrl! : apod.url;

    return GestureDetector(
      onTap: () => _showApodDetails(apod, context),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 图片部分
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 图片或视频占位符加载
                    isVideo
                        ? Container(
                            color: AppTheme.midBlue, // 背景色
                            child: Center(
                              child: Icon(
                                Icons.play_circle_outline,
                                color: AppTheme.purple.withOpacity(0.7),
                                size: 50,
                              ),
                            ),
                          )
                        : Image.network(
                            imageUrl, // 使用 imageUrl 变量
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Icon(Icons.image_not_supported,
                                    size: 40, color: Colors.grey),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  color: AppTheme.purple,
                                  value: loadingProgress.expectedTotalBytes !=
                                          null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          (loadingProgress.expectedTotalBytes ??
                                              1)
                                      : null,
                                ),
                              );
                            },
                          ),
                    // 标题叠加层
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.7),
                            ],
                          ),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          apod.displayTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    // 日期标签
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.purple.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          apod.date,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // 如果是视频，添加一个播放图标提示
                    if (isVideo)
                      Center(
                        child: Icon(
                          Icons.play_circle_fill,
                          color: Colors.white.withOpacity(0.7),
                          size: 60,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showApodDetails(NasaApod apod, BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ApodDetailScreen(apod: apod),
      ),
    );
  }

  // 显示日期选择器
  Future<void> _showDatePicker() async {
    if (!mounted) return;

    // 计算NASA APOD最早日期和今天之间的可选范围
    final DateTime firstApodDate = DateTime(1995, 6, 16);
    final DateTime now = DateTime.now();

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _currentDate,
      firstDate: firstApodDate,
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.purple,
              onPrimary: AppTheme.white,
              surface: AppTheme.midBlue,
              onSurface: AppTheme.white,
            ),
            dialogTheme:
                const DialogThemeData(backgroundColor: AppTheme.darkBlue),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      _loadSpecificDateApod(picked);
    }
  }

  // 加载特定日期的APOD
  Future<void> _loadSpecificDateApod(DateTime date) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final String formattedDate = _getFormattedDate(date);
      NasaApod? apod;

      // 尝试从缓存获取
      if (_cachedApods.containsKey(formattedDate)) {
        apod = _cachedApods[formattedDate];
      } else {
        // 从API获取
        apod = await _nasaService.getAstronomyPictureByDate(date);
        // 添加到缓存
        _cachedApods[formattedDate] = apod;
      }

      if (mounted) {
        if (apod != null) {
          if (apod.mediaType == 'video') {
            // 如果是视频类型，显示提示
            _showTemporaryMessage('暂无');
          } else {
            // 只有图片类型才导航到详情页面
            _showApodDetails(apod, context);
          }
        }
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });

        // 显示错误提示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('获取数据失败: $_errorMessage'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 显示临时消息
  void _showTemporaryMessage(String message) {
    // 使用Overlay显示临时消息
    OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 100, // 放在底部
        width: MediaQuery.of(context).size.width,
        child: AnimatedOpacity(
          opacity: 1.0,
          duration: const Duration(milliseconds: 500),
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey, // 不透明灰色
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlayEntry);

    // 3秒后开始淡出，并在淡出后移除
    Future.delayed(const Duration(seconds: 2)).then((_) {
      if (!mounted) return;

      // 创建一个新的临时视图，用于淡出效果
      OverlayEntry fadeOverlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          bottom: 100, // 放在底部
          width: MediaQuery.of(context).size.width,
          child: AnimatedOpacity(
            opacity: 0.0,
            duration: const Duration(milliseconds: 500),
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey, // 不透明灰色
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    message,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // 移除原来的覆盖层，添加新的带淡出效果的覆盖层
      overlayEntry.remove();
      Overlay.of(context).insert(fadeOverlayEntry);

      // 淡出后移除覆盖层
      Future.delayed(const Duration(milliseconds: 500)).then((_) {
        fadeOverlayEntry.remove();
      });
    });
  }

  // 滚动到顶部的方法
  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }
}

// NASA每日一图详情页面
class ApodDetailScreen extends StatelessWidget {
  final NasaApod apod;

  const ApodDetailScreen({super.key, required this.apod});

  @override
  Widget build(BuildContext context) {
    bool isVideo = apod.mediaType == 'video';
    String displayImageUrl =
        (isVideo && apod.thumbnailUrl != null) ? apod.thumbnailUrl! : apod.url;

    return Scaffold(
      backgroundColor: AppTheme.darkBlue,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBlue,
        title: const Text(
          'NASA每日一图详情',
          style: TextStyle(color: AppTheme.white),
        ),
        iconTheme: const IconThemeData(color: AppTheme.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 图片或视频占位符/缩略图部分
            Container(
              color: Colors.black,
              height: MediaQuery.of(context).size.height * 0.4,
              width: double.infinity,
              child: isVideo
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        if (apod.thumbnailUrl != null)
                          Image.network(
                            apod.thumbnailUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Center(
                                    child: Icon(Icons.ondemand_video,
                                        color: AppTheme.white, size: 50)),
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                  child: CircularProgressIndicator(
                                      color: AppTheme.purple));
                            },
                          )
                        else // 如果没有缩略图，显示通用视频图标
                          const Center(
                              child: Icon(Icons.ondemand_video,
                                  color: AppTheme.white, size: 80)),
                        Center(
                          child: Icon(
                            Icons.play_circle_fill_rounded,
                            color: Colors.white.withOpacity(0.8),
                            size: 80,
                          ),
                        ),
                        Positioned(
                          bottom: 10,
                          left: 0,
                          right: 0,
                          child: Text(
                            '这是一个视频资源，点击可尝试在外部打开',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 12),
                          ),
                        )
                      ],
                    )
                  : GestureDetector(
                      onTap: () {
                        if (apod.hdurl != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FullScreenImageView(
                                imageUrl: apod.hdurl!,
                                title: apod.displayTitle,
                              ),
                            ),
                          );
                        }
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Center(
                            child: Image.network(
                              displayImageUrl, // 使用 displayImageUrl
                              fit: BoxFit.contain, // 保持原比例完整显示
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(
                                  child: Icon(Icons.image_not_supported,
                                      color: AppTheme.white, size: 50),
                                );
                              },
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const Center(
                                  child: CircularProgressIndicator(
                                      color: AppTheme.purple),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
            ),

            // 详情部分
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    apod.displayTitle,
                    style: const TextStyle(
                      color: AppTheme.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    apod.date,
                    style: const TextStyle(
                      color: AppTheme.lightBlue,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (apod.copyright != null) ...[
                    Text(
                      '© ${apod.copyright}',
                      style: const TextStyle(
                        color: AppTheme.lightBlue,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    apod.displayExplanation,
                    style: const TextStyle(color: AppTheme.white),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 全屏图片查看页面
class FullScreenImageView extends StatefulWidget {
  final String imageUrl;
  final String title;

  const FullScreenImageView({
    super.key,
    required this.imageUrl,
    required this.title,
  });

  @override
  State<FullScreenImageView> createState() => _FullScreenImageViewState();
}

class _FullScreenImageViewState extends State<FullScreenImageView> {
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  final TransformationController _transformationController =
      TransformationController();

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 可缩放的高清图片
          InteractiveViewer(
            transformationController: _transformationController,
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: Image.network(
                widget.imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) {
                    _isLoading = false;
                    return child;
                  }
                  // 删除加载指示器，直接返回空容器
                  return Container();
                },
                errorBuilder: (context, error, stackTrace) {
                  _hasError = true;
                  _errorMessage = error.toString();
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.white, size: 64),
                          const SizedBox(height: 16),
                          const Text(
                            '加载高清图片失败',
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage ?? '未知错误',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.purple,
                            ),
                            child: const Text('返回'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
