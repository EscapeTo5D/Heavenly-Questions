import 'package:flutter/material.dart';
import '../constants/theme.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      decoration: const BoxDecoration(
        color: AppTheme.darkBlue,
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(0, Icons.map, '地图', context),
          _buildNavItem(1, Icons.book, '百科', context),
          _buildAddButton(context),
          _buildNavItem(3, Icons.newspaper, 'NASA', context),
          _buildNavItem(4, Icons.person, '我的', context),
        ],
      ),
    );
  }

  Widget _buildNavItem(
      int index, IconData icon, String label, BuildContext context) {
    final isSelected = currentIndex == index;
    return InkWell(
      onTap: () => onTap(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? AppTheme.lightBlue : AppTheme.white,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? AppTheme.lightBlue : AppTheme.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // 显示添加操作的弹出菜单
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) => _buildAddOptions(context),
        );
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: const BoxDecoration(
          color: AppTheme.purple,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.add,
          color: AppTheme.white,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildAddOptions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppTheme.darkBlue,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt, color: AppTheme.white),
            title: const Text('拍摄星空', style: TextStyle(color: AppTheme.white)),
            onTap: () {
              Navigator.pop(context);
              // 添加拍摄功能
            },
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome, color: AppTheme.white),
            title: const Text('分享观测', style: TextStyle(color: AppTheme.white)),
            onTap: () {
              Navigator.pop(context);
              // 添加分享功能
            },
          ),
          ListTile(
            leading: const Icon(Icons.question_answer, color: AppTheme.white),
            title: const Text('提问', style: TextStyle(color: AppTheme.white)),
            onTap: () {
              Navigator.pop(context);
              // 添加提问功能
            },
          ),
        ],
      ),
    );
  }
}
