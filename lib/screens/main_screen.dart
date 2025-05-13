import 'package:flutter/material.dart';
import '../widgets/bottom_nav_bar.dart';
import '../constants/theme.dart';
import 'zodiac_sphere_screen.dart';
import 'fixed_nasa_screen.dart';
import 'astronomy_quiz_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // Keep all screens in the list for IndexedStack
  final List<Widget> _screens = [
    const StarMapScreen(), // Index 0
    const EncyclopediaScreen(), // Index 1
    const StarMapScreen(), // Index 2 (Placeholder - show StarMap)
    // Or use: const SizedBox.shrink(), if you want nothing for index 2
    const NasaScreen(), // Index 3
    const ProfileScreen(), // Index 4
  ];

  void _onTabTapped(int index) {
    // Allow tapping index 2 (add button) but don't change the screen
    if (index != 2) {
      setState(() {
        _currentIndex = index;
      });
    } else {
      // Handle add button action here if needed
      print("Add button tapped!");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Use IndexedStack to keep screen states alive
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}

// 星空地图页面
class StarMapScreen extends StatelessWidget {
  const StarMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBlue,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: _buildStarryBackground(
                child: Column(
                  children: [
                    // 黄道星座球
                    Expanded(
                      flex: 3,
                      child: ZodiacSphereScreen(),
                    ),
                    // 其他功能列表
                    Expanded(
                      flex: 2,
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          _buildSectionTitle('探索功能'),
                          const SizedBox(height: 10),
                          _buildFunctionCards(context),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: AppTheme.darkBlue,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '星空探索',
            style: TextStyle(
              color: AppTheme.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.purple, width: 1.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search,
              color: AppTheme.white,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStarryBackground({required Widget child}) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 0.7,
          colors: [AppTheme.midBlue, AppTheme.darkBlue],
        ),
      ),
      child: Stack(
        children: [
          _buildStars(),
          child,
        ],
      ),
    );
  }

  Widget _buildStars() {
    return CustomPaint(
      painter: StarPainter(),
      size: const Size(double.infinity, double.infinity),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppTheme.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildFunctionCards(BuildContext context) {
    // Create a list of function cards
    final List<Widget> cards = [
      _buildFunctionCard(
        context,
        '天文百科',
        Icons.book,
        () {
          // 导航到天文百科页面
        },
      ),
      _buildFunctionCard(
        context,
        '观测指南',
        Icons.explore,
        () {
          // 导航到观测指南页面
        },
      ),
      _buildFunctionCard(
        context,
        '天象预报',
        Icons.event,
        () {
          // 导航到天象预报页面
        },
      ),
      _buildFunctionCard(
        context,
        '天文学习',
        Icons.school,
        () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const AstronomyQuizScreen()),
          );
        },
      ),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 15,
      crossAxisSpacing: 15,
      childAspectRatio: 1.5,
      children: cards,
    );
  }

  Widget _buildFunctionCard(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1D2951),
              Color(0xFF191A30),
            ],
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 5,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: AppTheme.purple,
              size: 30,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 为应用绘制星空背景的自定义画笔
class StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = DateTime.now().millisecondsSinceEpoch;
    const numberOfStars = 100;

    for (var i = 0; i < numberOfStars; i++) {
      final x = (random * (i + 1) * 7) % size.width;
      final y = (random * (i + 1) * 13) % size.height;
      final radius = (random * (i + 1)) % 2 + 0.5;
      final opacity = (random * (i + 1)) % 100 / 100 * 0.5 + 0.3;

      final paint = Paint()
        ..color = AppTheme.white.withOpacity(opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// 绘制猎户座星座连线的自定义画笔
class ConstellationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final paint = Paint()
      ..color = AppTheme.purple
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = AppTheme.lightBlue
      ..style = PaintingStyle.fill;

    final whiteDotPaint = Paint()
      ..color = AppTheme.white
      ..style = PaintingStyle.fill;

    // 猎户座简化版星点位置
    final points = [
      Offset(width * 0.1, 15),
      Offset(width * 0.3, 25),
      Offset(width * 0.5, 15),
      Offset(width * 0.7, 30),
    ];

    // 绘制星点连线
    canvas.drawLine(points[0], points[1], paint);
    canvas.drawLine(points[1], points[2], paint);
    canvas.drawLine(points[2], points[3], paint);

    // 绘制星点
    canvas.drawCircle(points[0], 3, dotPaint);
    canvas.drawCircle(points[1], 2, whiteDotPaint);
    canvas.drawCircle(points[2], 2.5, dotPaint);
    canvas.drawCircle(points[3], 2, whiteDotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// 黄道星座页面
class ZodiacConstellationScreen extends StatelessWidget {
  const ZodiacConstellationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBlue,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBlue,
        title: const Text('黄道星座', style: TextStyle(color: AppTheme.white)),
        iconTheme: const IconThemeData(color: AppTheme.white),
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildZodiacIntro(),
            const SizedBox(height: 20),
            _buildZodiacFeatureCards(context),
            const SizedBox(height: 20),
            _buildZodiacConstellations(),
          ],
        ),
      ),
    );
  }

  Widget _buildZodiacIntro() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1D2951),
            Color(0xFF191A30),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '黄道星座简介',
            style: TextStyle(
              color: AppTheme.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10),
          Text(
            '黄道星座是指位于黄道附近的十二个星座，分别是白羊座、金牛座、双子座、巨蟹座、狮子座、处女座、天秤座、天蝎座、射手座、摩羯座、水瓶座和双鱼座。黄道是太阳在天球上的周年视运动轨迹。',
            style: TextStyle(
              color: AppTheme.white,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZodiacFeatureCards(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '黄道特性',
          style: TextStyle(
            color: AppTheme.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ZodiacSphereScreen()),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF2E3C7E),
                  Color(0xFF1C2347),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppTheme.purple.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.public,
                    color: AppTheme.lightBlue,
                    size: 36,
                  ),
                ),
                const SizedBox(width: 15),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '黄道球面',
                        style: TextStyle(
                          color: AppTheme.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        '探索黄道在天球上的投影及其特性',
                        style: TextStyle(
                          color: AppTheme.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: AppTheme.white,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildZodiacConstellations() {
    final List<Map<String, dynamic>> zodiacs = [
      {'name': '白羊座', 'date': '3月21日-4月19日', 'symbol': '♈'},
      {'name': '金牛座', 'date': '4月20日-5月20日', 'symbol': '♉'},
      {'name': '双子座', 'date': '5月21日-6月21日', 'symbol': '♊'},
      {'name': '巨蟹座', 'date': '6月22日-7月22日', 'symbol': '♋'},
      {'name': '狮子座', 'date': '7月23日-8月22日', 'symbol': '♌'},
      {'name': '处女座', 'date': '8月23日-9月22日', 'symbol': '♍'},
      {'name': '天秤座', 'date': '9月23日-10月23日', 'symbol': '♎'},
      {'name': '天蝎座', 'date': '10月24日-11月22日', 'symbol': '♏'},
      {'name': '射手座', 'date': '11月23日-12月21日', 'symbol': '♐'},
      {'name': '摩羯座', 'date': '12月22日-1月19日', 'symbol': '♑'},
      {'name': '水瓶座', 'date': '1月20日-2月18日', 'symbol': '♒'},
      {'name': '双鱼座', 'date': '2月19日-3月20日', 'symbol': '♓'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '黄道十二星座',
          style: TextStyle(
            color: AppTheme.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: zodiacs.length,
          itemBuilder: (context, index) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1D2951).withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.purple.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      zodiacs[index]['symbol'],
                      style: const TextStyle(
                        color: AppTheme.white,
                        fontSize: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        zodiacs[index]['name'],
                        style: const TextStyle(
                          color: AppTheme.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        zodiacs[index]['date'],
                        style: TextStyle(
                          color: AppTheme.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

// 星座百科页面（占位）
class EncyclopediaScreen extends StatelessWidget {
  const EncyclopediaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.darkBlue,
      body: Center(
        child: Text(
          '星座百科',
          style: TextStyle(color: AppTheme.white, fontSize: 24),
        ),
      ),
    );
  }
}

// 天文动态页面替换为NASA页面
// class NewsScreen extends StatelessWidget {
//   const NewsScreen({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return const Scaffold(
//       backgroundColor: AppTheme.darkBlue,
//       body: Center(
//         child: Text(
//           '天文动态',
//           style: TextStyle(color: AppTheme.white, fontSize: 24),
//         ),
//       ),
//     );
//   }
// }
