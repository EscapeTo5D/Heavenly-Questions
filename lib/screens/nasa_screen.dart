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
  // 用于取消异步操作的标志
  bool _isMounted = true;

  @override
  void initState() {
    super.initState();
    _loadApodList();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _isMounted = false; // 标记组件已被销毁
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // 监听滚动事件
  void _onScroll() {
    if (!mounted) return; // 检查是否已卸载

    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMoreApod();
    }
  }

  // 加载多天的NASA每日一图
  Future<void> _loadApodList() async {
    if (!mounted) return; // 检查是否已卸载

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
        // 检查是否已卸载
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

  // 优化：并行加载更多NASA每日一图
  Future<void> _loadMoreApod() async {
    if (_isLoadingMore || !_hasMore || !mounted) return; // 检查是否已卸载

    setState(() {
      _isLoadingMore = true;
    });

    try {
      // 使用新的批量API获取10张图片
      final List<NasaApod> newApodList =
          await _nasaService.getBatchAstronomyPictures(_currentDate, 10);

      // 过滤掉重复的图片
      final List<NasaApod> uniqueNewApods = [];
      for (final apod in newApodList) {
        final String formattedDate =
            _getFormattedDate(DateTime.parse(apod.date));
        if (!_cachedApods.containsKey(formattedDate)) {
          uniqueNewApods.add(apod);
          // 添加到缓存
          _cachedApods[formattedDate] = apod;
        }
      }

      // 更新当前日期为最后一个处理过的日期减一天
      if (newApodList.isNotEmpty) {
        final lastDate = DateTime.parse(newApodList.last.date);
        _currentDate = lastDate.subtract(const Duration(days: 1));

        // 检查是否已达到最早的数据
        if (_currentDate.isBefore(DateTime(1995, 6, 16))) {
          _hasMore = false;
        }
      }

      if (mounted) {
        // 检查是否已卸载
        setState(() {
          _apodList.addAll(uniqueNewApods);
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        // 检查是否已卸载
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
      // 设置5秒超时
      return await _nasaService
          .getAstronomyPictureByDate(date)
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      // 超时或错误时返回null
      return null;
    }
  }

  // 重置当前日期并刷新数据
  Future<void> _refreshData() async {
    if (!mounted) return; // 检查是否已卸载

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
                childAspectRatio: 0.65, // 进一步调整宽高比，适应容器高度增加
                crossAxisSpacing: 12, // 水平间距
                mainAxisSpacing: 12, // 垂直间距
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final apod = _apodList[index];
                  return _buildApodCard(apod, context);
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

  Widget _buildApodCard(NasaApod apod, BuildContext context) {
    // 方法1：计算屏幕宽度来设置合适的图片高度
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth - 36) / 2; // 计算单个卡片的宽度（减去内外边距）
    final imageHeight = cardWidth * 1; // 设置图片高度为卡片宽度的0.9倍

    return Card(
      margin: EdgeInsets.zero,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: AppTheme.midBlue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 图片部分 - 方法2：使用容器限制图片大小
          Container(
            height: imageHeight,
            width: double.infinity,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              color: AppTheme.darkBlue,
            ),
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: GestureDetector(
                onTap: () => _showApodDetails(apod, context),
                child: Stack(
                  children: [
                    // 方法3：使用BoxFit控制图片填充方式
                    Container(
                      color: Colors.black, // 添加黑色背景以确保图片更美观
                      child: Image.network(
                        apod.url,
                        height: imageHeight,
                        width: double.infinity,
                        fit: BoxFit.cover, // 改为cover以填满容器并截取多余部分
                        // 优化：缓存图片
                        cacheHeight: 400,
                        cacheWidth: 600,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            height: imageHeight,
                            width: double.infinity,
                            color: AppTheme.midBlue,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(
                                    color: AppTheme.purple,
                                    value: loadingProgress.expectedTotalBytes !=
                                            null
                                        ? loadingProgress
                                                .cumulativeBytesLoaded /
                                            (loadingProgress
                                                    .expectedTotalBytes ??
                                                1)
                                        : null,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    '加载中...',
                                    style: TextStyle(
                                        color: AppTheme.white, fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: imageHeight,
                            width: double.infinity,
                            color: AppTheme.midBlue,
                            child: const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.image_not_supported,
                                      color: AppTheme.white, size: 32),
                                  SizedBox(height: 4),
                                  Text(
                                    '加载失败',
                                    style: TextStyle(
                                        color: AppTheme.white, fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // 右下角的媒体类型图标
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.darkBlue.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.image,
                          color: AppTheme.lightBlue,
                          size: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 标题部分 - 固定高度确保布局一致
          Container(
            height: 42, // 固定高度容纳两行文本
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Text(
              apod.displayTitle,
              style: const TextStyle(
                color: AppTheme.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // 日期部分
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  DateFormat('yyyy年MM月dd日').format(DateTime.parse(apod.date)),
                  style: const TextStyle(
                    color: AppTheme.lightBlue,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
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
    if (!mounted) return; // 检查是否已卸载

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
    if (!mounted) return; // 检查是否已卸载

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

    // 2秒后开始淡出，并在淡出后移除
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
            // 图片部分
            apod.mediaType == 'image'
                ? Image.network(
                    apod.url,
                    height: MediaQuery.of(context).size.height * 0.4,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: MediaQuery.of(context).size.height * 0.4,
                        width: double.infinity,
                        color: AppTheme.midBlue,
                        child: const Center(
                          child:
                              CircularProgressIndicator(color: AppTheme.purple),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: MediaQuery.of(context).size.height * 0.4,
                        width: double.infinity,
                        color: AppTheme.midBlue,
                        child: const Center(
                          child: Icon(Icons.image_not_supported,
                              color: AppTheme.white, size: 50),
                        ),
                      );
                    },
                  )
                : Container(
                    height: MediaQuery.of(context).size.height * 0.4,
                    width: double.infinity,
                    color: AppTheme.midBlue,
                    child: const Center(
                      child: Icon(Icons.image_not_supported,
                          color: AppTheme.white, size: 50),
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
                    DateFormat('yyyy年MM月dd日').format(DateTime.parse(apod.date)),
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

                  // 正文说明部分 - 确保使用翻译后的说明文本
                  const Text(
                    "详细描述：",
                    style: TextStyle(
                      color: AppTheme.lightBlue,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 首先尝试显示翻译后的说明，如果没有则显示原始说明
                  Text(
                    apod.translatedExplanation ?? apod.explanation,
                    style: const TextStyle(
                      color: AppTheme.white,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),

                  if (apod.translatedExplanation == null)
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.purple.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        "翻译未完成，显示原文",
                        style: TextStyle(
                          color: AppTheme.lightBlue,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),
                  if (apod.hdurl != null) ...[
                    Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.hd),
                        label: const Text('查看高清图片'),
                        onPressed: () {
                          // 这里可以实现显示高清图片的功能，需要使用url_launcher或图片查看器
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
