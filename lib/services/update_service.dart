import 'dart:convert';

import 'package:http/http.dart' as http;

/// 内置更新检查：从 GitHub Releases 拉取最新版本。
class UpdateInfo {
  final bool hasUpdate;
  final String latestVersion;
  final String apkUrl;
  final String notes;
  final String error;

  const UpdateInfo({
    this.hasUpdate = false,
    this.latestVersion = '',
    this.apkUrl = '',
    this.notes = '',
    this.error = '',
  });
}

class UpdateService {
  /// GitHub 仓库（Release 数据源）
  static const String repoOwner = 'wuyuzhiren';
  static const String repoName = 'xiaozhi-riding-companion';

  /// 解析语义版本号，返回 [major, minor, patch]；解析失败返回 null
  static List<int>? _parseVersion(String v) {
    final m = RegExp(r'(\d+)\.(\d+)\.(\d+)').firstMatch(v);
    if (m == null) return null;
    return [int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!)];
  }

  static bool _isNewer(String remote, String current) {
    final a = _parseVersion(remote);
    final b = _parseVersion(current);
    if (a == null || b == null) return false;
    for (int i = 0; i < 3; i++) {
      if (a[i] != b[i]) return a[i] > b[i];
    }
    return false;
  }

  /// 检查 GitHub 最新 Release 是否比当前版本新。
  static Future<UpdateInfo> checkForUpdate({
    required String currentVersion,
  }) async {
    try {
      final uri = Uri.parse(
        'https://api.github.com/repos/$repoOwner/$repoName/releases/latest',
      );
      final resp = await http.get(
        uri,
        headers: const {'User-Agent': 'ai-assistant', 'Accept': 'application/vnd.github+json'},
      );
      if (resp.statusCode == 404) {
        return const UpdateInfo(error: '未找到发布版本（仓库还没有 Release）');
      }
      if (resp.statusCode != 200) {
        return UpdateInfo(error: '检查失败（HTTP ${resp.statusCode}）');
      }
      final json = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      final tag = (json['tag_name'] as String? ?? '').replaceFirst('v', '');
      final notes = (json['body'] as String? ?? '').trim();
      final assets = (json['assets'] as List? ?? []);
      String apkUrl = '';
      for (final asset in assets) {
        final name = (asset as Map<String, dynamic>)['name'] as String? ?? '';
        if (name.endsWith('.apk')) {
          apkUrl = (asset['browser_download_url'] as String? ?? '');
          break;
        }
      }
      final hasUpdate = _isNewer(tag, currentVersion);
      return UpdateInfo(
        hasUpdate: hasUpdate,
        latestVersion: tag,
        apkUrl: apkUrl,
        notes: notes,
      );
    } catch (e) {
      return UpdateInfo(error: '检查失败: $e');
    }
  }
}
