import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../screens/game_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('saved_notifications') ?? [];
    _items = raw.map((s) {
      try {
        return Map<String, dynamic>.from(json.decode(s));
      } catch (_) {
        return <String, dynamic>{};
      }
    }).where((m) => m.isNotEmpty).toList();
    setState(() => _loading = false);
  }

  Future<void> _markRead(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('saved_notifications') ?? [];
    if (index < 0 || index >= raw.length) return;
    final Map<String, dynamic> obj = Map<String, dynamic>.from(json.decode(raw[index]));
    obj['read'] = true;
    raw[index] = json.encode(obj);
    await prefs.setStringList('saved_notifications', raw);
    _loadNotifications();
  }

  Future<void> _deleteAt(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('saved_notifications') ?? [];
    if (index < 0 || index >= raw.length) return;
    raw.removeAt(index);
    await prefs.setStringList('saved_notifications', raw);
    _loadNotifications();
  }

  Future<void> _markAllRead() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('saved_notifications') ?? [];
    final updated = raw.map((s) {
      final obj = Map<String, dynamic>.from(json.decode(s));
      obj['read'] = true;
      return json.encode(obj);
    }).toList();
    await prefs.setStringList('saved_notifications', updated);
    _loadNotifications();
  }

  String _relativeTime(String iso) {
    try {
      final date = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inSeconds < 60) return '${diff.inSeconds}s 전';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m 전';
      if (diff.inHours < 24) return '${diff.inHours}h 전';
      return DateFormat('yyyy-MM-dd HH:mm').format(date);
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('알림'),
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: const Text('모두 읽음', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('알림이 없습니다'))
              : ListView.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final title = item['title'] ?? '';
                    final body = item['body'] ?? '';
                    final payload = item['payload'];
                    final read = item['read'] == true;
                    final received = item['receivedAt'] ?? '';

                    return ListTile(
                      tileColor: read ? Colors.transparent : Colors.white12,
                      title: Text(
                        title,
                        style: TextStyle(
                          fontWeight: read ? FontWeight.normal : FontWeight.bold,
                        ),
                      ),
                      subtitle: Text('$body\n${_relativeTime(received)}'),
                      isThreeLine: true,
                      onTap: () async {
                        // 마크 읽음
                        await _markRead(index);
                        // payload가 게임 id라면 상세로 이동
                        if (payload != null && payload.toString().isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GameDetailScreen(gameId: payload.toString()),
                            ),
                          );
                        }
                      },
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'delete') await _deleteAt(index);
                          if (v == 'read') await _markRead(index);
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(value: 'read', child: Text('읽음 처리')),
                          const PopupMenuItem(value: 'delete', child: Text('삭제')),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
