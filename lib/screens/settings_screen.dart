import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  double _textSize = 16.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          _buildSectionHeader('通用设置'),
          SwitchListTile(
            title: const Text('通知'),
            subtitle: const Text('启用或禁用应用通知'),
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() {
                _notificationsEnabled = value;
              });
            },
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('深色模式'),
            subtitle: const Text('切换应用主题'),
            value: _darkModeEnabled,
            onChanged: (value) {
              setState(() {
                _darkModeEnabled = value;
              });
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('文字大小'),
            subtitle: Text('调整应用文字大小: ${_textSize.toInt()}'),
            trailing: SizedBox(
              width: 200,
              child: Slider(
                min: 12.0,
                max: 24.0,
                divisions: 6,
                value: _textSize,
                onChanged: (value) {
                  setState(() {
                    _textSize = value;
                  });
                },
              ),
            ),
          ),
          const Divider(),
          _buildSectionHeader('关于'),
          const ListTile(
            title: Text('应用版本'),
            subtitle: Text('1.0.0'),
          ),
          const Divider(),
          ListTile(
            title: const Text('清除缓存'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // 处理清除缓存
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('缓存已清除')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }
}
