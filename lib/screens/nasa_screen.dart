import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  // 加载更多NASA每日一图
  Future<void> _loadMoreApod() async {
    if (_isLoadingMore || !_hasMore || !mounted) return; // 检查是否已卸载

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final List<NasaApod> newApodList = [];
      DateTime date = _currentDate;
      int loadedCount = 0;

      // 每次加载10张图片
      while (loadedCount < 10 && _hasMore && _isMounted) {
        try {
          final apod = await _nasaService.getAstronomyPictureByDate(date);
          if (!_isMounted) return; // 检查异步操作过程中是否已卸载

          newApodList.add(apod);
          loadedCount++;
          date = date.subtract(const Duration(days: 1));
        } catch (e) {
          // 如果日期早于NASA APOD开始日期，认为没有更多数据
          if (date.isBefore(DateTime(1995, 6, 16))) {
            _hasMore = false;
            break;
          }
          date = date.subtract(const Duration(days: 1));
          continue;
        }
      }

      if (mounted) {
        // 检查是否已卸载
        setState(() {
          _apodList.addAll(newApodList);
          _currentDate = date;
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

  // 重置当前日期并刷新数据
  void _refreshData() {
    if (!mounted) return; // 检查是否已卸载

    setState(() {
      _hasMore = true;
    });
    _loadApodList();
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
          child: CircularProgressIndicator(color: AppTheme.purple));
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

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _apodList.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _apodList.length) {
          return _buildLoadMoreIndicator();
        }
        final apod = _apodList[index];
        return _buildApodCard(apod, context);
      },
    );
  }

  Widget _buildLoadMoreIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: _isLoadingMore
            ? const CircularProgressIndicator(color: AppTheme.purple)
            : const Text(
                '上拉加载更多',
                style: TextStyle(color: AppTheme.lightBlue),
              ),
      ),
    );
  }

  Widget _buildApodCard(NasaApod apod, BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: AppTheme.midBlue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 图片部分
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: GestureDetector(
              onTap: () => _showApodDetails(apod, context),
              child: Stack(
                children: [
                  apod.mediaType == 'image'
                      ? Image.network(
                          apod.url,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              height: 200,
                              width: double.infinity,
                              color: AppTheme.midBlue,
                              child: const Center(
                                child: CircularProgressIndicator(
                                    color: AppTheme.purple),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 200,
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
                          height: 200,
                          width: double.infinity,
                          color: AppTheme.midBlue,
                          child: const Center(
                            child: Icon(Icons.movie,
                                color: AppTheme.white, size: 50),
                          ),
                        ),
                  // 标题层
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            AppTheme.darkBlue.withOpacity(0.9),
                            AppTheme.darkBlue.withOpacity(0.0),
                          ],
                        ),
                      ),
                      child: Text(
                        apod.title,
                        style: const TextStyle(
                          color: AppTheme.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 日期部分
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('yyyy年MM月dd日').format(DateTime.parse(apod.date)),
                  style: const TextStyle(
                    color: AppTheme.lightBlue,
                    fontSize: 14,
                  ),
                ),
                Icon(
                  apod.mediaType == 'image' ? Icons.image : Icons.video_library,
                  color: AppTheme.lightBlue,
                  size: 16,
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
                          // 这里可以实现打开视频链接的功能，需要使用url_launcher包
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
