import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../constants/theme.dart';
import '../models/nasa_apod.dart';
import '../services/nasa_service.dart';

class NasaScreen extends StatefulWidget {
  const NasaScreen({super.key});

  @override
  State<NasaScreen> createState() => _NasaScreenState();
}

class _NasaScreenState extends State<NasaScreen> {
  final NasaService _nasaService = NasaService();
  final ScrollController _scrollController = ScrollController();
  final Map<String, NasaApod> _cachedApods = HashMap<String, NasaApod>();

  List<NasaApod> _apodList = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  DateTime _currentDate = DateTime.now();
  bool _hasMore = true;
  bool _isMounted = true;

  @override
  void initState() {
    super.initState();
    _loadApodList();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _isMounted = false;
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // 监听滚动事件
  void _onScroll() {
    if (!mounted) return;

    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMoreApod();
    }
  }

  // 加载多天的NASA每日一图
  Future<void> _loadApodList() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _apodList = [];
      _currentDate = DateTime.now();
    });

    try {
      await _loadMoreApod();
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

      // 准备10个并行请求
      for (int i = 0; i < 10; i++) {
        final String formattedDate = _getFormattedDate(date);

        // 检查缓存中是否已有此日期的数据
        if (_cachedApods.containsKey(formattedDate)) {
          dates.add(date);
          futures.add(Future.value(_cachedApods[formattedDate]));
        } else {
          dates.add(date);
          futures.add(_fetchApodWithTimeout(date));
        }

        date = date.subtract(const Duration(days: 1));

        if (date.isBefore(DateTime(1995, 6, 16))) {
          _hasMore = false;
          break;
        }
      }

      // 并行执行所有请求
      final results = await Future.wait(futures);

      if (!_isMounted) return;

      // 处理结果
      final List<NasaApod> newApodList = [];

      for (int i = 0; i < results.length; i++) {
        if (results[i] != null) {
          newApodList.add(results[i]!);
          final String formattedDate = _getFormattedDate(dates[i]);
          _cachedApods[formattedDate] = results[i]!;
        }
      }

      // 更新日期指针
      if (dates.isNotEmpty) {
        _currentDate = dates.last.subtract(const Duration(days: 1));
      }

      if (mounted) {
        setState(() {
          _apodList.addAll(newApodList);
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
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

  // 使用超时机制获取APOD数据
  Future<NasaApod?> _fetchApodWithTimeout(DateTime date) async {
    try {
      return await _nasaService
          .getAstronomyPictureByDate(date)
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      return null;
    }
  }

  // 重置当前日期并刷新数据
  Future<void> _refreshData() async {
    if (!mounted) return;

    setState(() {
      _hasMore = true;
    });
    await _loadApodList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBlue,
      appBar: AppBar(
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
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _apodList.isEmpty) {
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

    if (_errorMessage != null && _apodList.isEmpty) {
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

    if (_apodList.isEmpty) {
      return const Center(
          child: Text('无数据', style: TextStyle(color: AppTheme.white)));
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: AppTheme.purple,
      backgroundColor: AppTheme.midBlue,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
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
          if (_hasMore)
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
            ? const Column(
                children: [
                  CircularProgressIndicator(color: AppTheme.purple),
                  SizedBox(height: 8),
                  Text(
                    '加载中...',
                    style: TextStyle(color: AppTheme.lightBlue),
                  ),
                ],
              )
            : const Text(
                '上拉加载更多',
                style: TextStyle(color: AppTheme.lightBlue),
              ),
      ),
    );
  }

  Widget _buildApodCard(NasaApod apod) {
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
                    // 图片加载
                    apod.mediaType == 'image'
                        ? Image.network(
                            apod.url,
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
                          )
                        : const Center(
                            child:
                                Icon(Icons.movie, size: 40, color: Colors.grey),
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
                          apod.title,
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
            dialogBackgroundColor: AppTheme.darkBlue,
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
        if (apod != null) {
          _cachedApods[formattedDate] = apod;
        }
      }

      if (mounted) {
        if (apod != null) {
          // 导航到详情页面
          _showApodDetails(apod, context);
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
}

// NASA每日一图详情页面
class ApodDetailScreen extends StatelessWidget {
  final NasaApod apod;

  const ApodDetailScreen({super.key, required this.apod});

  @override
  Widget build(BuildContext context) {
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
            // 图片部分 - 最简单的显示方式
            Container(
              color: Colors.black,
              height: MediaQuery.of(context).size.height * 0.4,
              width: double.infinity,
              child: apod.mediaType == 'image'
                  ? Center(
                      child: Image.network(
                        apod.url,
                        fit: BoxFit.contain, // 保持原比例完整显示
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(Icons.image_not_supported,
                                color: AppTheme.white, size: 50),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(
                                color: AppTheme.purple),
                          );
                        },
                      ),
                    )
                  : const Center(
                      child: Icon(Icons.movie, color: AppTheme.white, size: 50),
                    ),
            ),

            // 详情部分
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    apod.title,
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
                  const Text(
                    '描述',
                    style: TextStyle(
                      color: AppTheme.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    apod.explanation,
                    style: const TextStyle(color: AppTheme.white),
                  ),
                  const SizedBox(height: 24),
                  if (apod.mediaType == 'video') ...[
                    const Text(
                      '视频内容',
                      style: TextStyle(
                        color: AppTheme.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.play_circle_outline),
                        label: const Text('观看视频'),
                        onPressed: () {
                          // 这里可以实现打开视频链接的功能
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.purple,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                  if (apod.hdurl != null) ...[
                    Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.hd),
                        label: const Text('查看高清图片'),
                        onPressed: () {
                          // 这里可以实现显示高清图片的功能
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.purple,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
