import 'package:flutter/material.dart';
import '../constants/theme.dart';

// 黄道球面页面
class ZodiacSphereScreen extends StatelessWidget {
  const ZodiacSphereScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBlue,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBlue,
        iconTheme: const IconThemeData(color: AppTheme.white),
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppTheme.purple.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.public,
                  color: AppTheme.lightBlue,
                  size: 60,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '黄道球面功能',
                style: TextStyle(
                  color: AppTheme.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  '该功能正在开发中，敬请期待...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.white,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
