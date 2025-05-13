import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../utils/routes.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBlue,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBlue,
        title: const Text(
          '个人中心',
          style: TextStyle(color: AppTheme.white),
        ),
        elevation: 0,
      ),
      body: _buildUserView(),
    );
  }

  Widget _buildUserView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          // 用户头像
          const CircleAvatar(
            radius: 50,
            backgroundColor: AppTheme.purple,
            child: Icon(
              Icons.person,
              size: 60,
              color: AppTheme.white,
            ),
          ),
          const SizedBox(height: 20),
          // 用户名
          const Text(
            '宇宙探索者',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.white,
            ),
          ),
          const SizedBox(height: 30),

          // 用户选项列表
          _buildProfileItem(
            Icons.favorite,
            '我的收藏',
            '收藏的文章和内容',
            () {
              // 实现我的收藏功能
            },
          ),
          _buildProfileItem(
            Icons.history,
            '浏览历史',
            '最近查看的内容',
            () {
              // 实现浏览历史功能
            },
          ),
          _buildProfileItem(
            Icons.book,
            '学习记录',
            '天文知识学习进度',
            () {
              // 实现学习记录功能
            },
          ),
          _buildProfileItem(
            Icons.quiz,
            '题库管理',
            '添加和编辑天文问题',
            () {
              Navigator.pushNamed(context, AppRoutes.quizManagement);
            },
          ),
          _buildProfileItem(
            Icons.help_outline,
            '帮助与反馈',
            '常见问题和意见反馈',
            () {
              // 实现帮助与反馈功能
            },
          ),
          _buildProfileItem(
            Icons.info_outline,
            '关于应用',
            '版本信息和开发者',
            () {
              Navigator.pushNamed(context, AppRoutes.about);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProfileItem(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Card(
        color: AppTheme.midBlue,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          leading: Icon(icon, color: AppTheme.purple, size: 28),
          title: Text(
            title,
            style: const TextStyle(
              color: AppTheme.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(color: AppTheme.white.withOpacity(0.7)),
          ),
          trailing: const Icon(Icons.arrow_forward_ios,
              color: AppTheme.purple, size: 16),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          onTap: onTap,
        ),
      ),
    );
  }
}
