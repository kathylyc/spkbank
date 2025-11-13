import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../utils/context_extensions.dart';
import '../../widgets/common_data_table_page.dart';

/// PDF模板管理页面
class PdfTemplatePage extends StatefulWidget {
  const PdfTemplatePage({super.key});

  @override
  State<PdfTemplatePage> createState() => _PdfTemplatePageState();
}

class _PdfTemplatePageState extends State<PdfTemplatePage> {
  // 分页
  int _currentPage = 1;
  int _totalItems = 0;
  
  // PDF文件数据
  List<Map<String, dynamic>> _allPdfData = [];
  List<Map<String, dynamic>> _pdfData = [];
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// 加载数据 - 从assets/pdf目录读取所有PDF文件
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 读取AssetManifest.json获取所有assets文件
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifestContent);
      
      // 过滤出assets/pdf/目录下的PDF文件
      final pdfFiles = manifestMap.keys
          .where((key) => key.startsWith('assets/pdf/') && key.endsWith('.pdf'))
          .toList();
      
      // 构建数据列表
      _allPdfData = pdfFiles.asMap().entries.map((entry) {
        final index = entry.key;
        final assetPath = entry.value;
        final fileName = assetPath.split('/').last;
        
        return {
          'id': index + 1,
          'name': fileName,
          'assetPath': assetPath,
          'count': 0, // 引用次数暂时设为0，后续可以从数据库获取
        };
      }).toList();
      
      // 更新总数
      _totalItems = _allPdfData.length;
      
      // 根据当前页更新显示的数据
      _updatePageData();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载PDF文件列表失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  /// 根据当前页更新显示的数据
  void _updatePageData() {
    const itemsPerPage = 20;
    final startIndex = (_currentPage - 1) * itemsPerPage;
    
    if (startIndex >= _allPdfData.length) {
      _pdfData = [];
      return;
    }
    
    final endIndex = startIndex + itemsPerPage;
    _pdfData = _allPdfData.sublist(
      startIndex,
      endIndex > _allPdfData.length ? _allPdfData.length : endIndex,
    );
  }

  /// 页码变化
  void _handlePageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
    _updatePageData();
  }

  /// 获取Downloads目录
  Future<Directory?> _getDownloadsDirectory() async {
    if (Platform.isAndroid) {
      // Android: 尝试获取外部存储目录，然后访问Downloads子目录
      try {
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          // 获取外部存储的根目录（通常是 /storage/emulated/0）
          final externalPath = externalDir.path;
          // 找到外部存储根目录
          final rootPath = externalPath.split('/Android')[0];
          final downloadsDir = Directory(p.join(rootPath, 'Download'));
          
          // 如果Download目录不存在，尝试Downloads（某些设备使用复数形式）
          if (!await downloadsDir.exists()) {
            final downloadsDirAlt = Directory(p.join(rootPath, 'Downloads'));
            if (await downloadsDirAlt.exists()) {
              return downloadsDirAlt;
            }
            // 如果都不存在，创建Download目录
            await downloadsDir.create(recursive: true);
          }
          
          return downloadsDir;
        }
      } catch (e) {
        debugPrint('获取Android Downloads目录失败: $e');
      }
    } else if (Platform.isIOS) {
      // iOS: 使用Documents目录，用户可以通过Files应用访问
      try {
        final documentsDir = await getApplicationDocumentsDirectory();
        final downloadsDir = Directory(p.join(documentsDir.path, 'Downloads'));
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
        }
        return downloadsDir;
      } catch (e) {
        debugPrint('获取iOS Downloads目录失败: $e');
      }
    }
    return null;
  }

  /// 下载PDF - 将assets中的PDF文件复制到Downloads目录
  Future<void> _handleDownload(Map<String, dynamic> row) async {
    final assetPath = row['assetPath'] as String?;
    final fileName = row['name'] as String;
    
    if (assetPath == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('文件路径不存在'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // 显示下载中提示
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('正在下载: $fileName'),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    try {
      // 获取Downloads目录
      final downloadsDir = await _getDownloadsDirectory();
      if (downloadsDir == null) {
        throw Exception('无法获取Downloads目录，请检查存储权限');
      }

      // 从assets读取PDF文件
      final ByteData data = await rootBundle.load(assetPath);
      final List<int> bytes = data.buffer.asUint8List();

      // 构建目标文件路径
      final targetPath = p.join(downloadsDir.path, fileName);
      final targetFile = File(targetPath);

      // 如果文件已存在，添加时间戳后缀
      String finalPath = targetPath;
      if (await targetFile.exists()) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final nameWithoutExt = p.basenameWithoutExtension(fileName);
        final ext = p.extension(fileName);
        finalPath = p.join(downloadsDir.path, '${nameWithoutExt}_$timestamp$ext');
      }

      // 写入文件
      await File(finalPath).writeAsBytes(bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('下载成功: $fileName'),
                const SizedBox(height: 4),
                Text(
                  '保存路径: ${p.basename(finalPath)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('下载PDF失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('下载失败: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return CommonDataTablePage(
      // 查询条件区域（空）
      querySection: const SizedBox.shrink(),
      
      // 表格标题
      tableTitle: context.S.recentlyGeneratedPdfFiles,
      
      // 功能按钮（空）
      actionButtons: const [],
      
      // 不显示复选框
      showCheckbox: false,
      
      // 表格列定义
      columns: [
        DataTableColumn(
          label: 'id',
          builder: (row, context) => Text(row['id'].toString()),
        ),
        DataTableColumn(
          label: '模板名称',
          builder: (row, context) => Text(row['name']),
        ),
        DataTableColumn(
          label: '引用次数',
          builder: (row, context) => Text(row['count'].toString()),
        ),
        DataTableColumn(
          label: '操作',
          builder: (row, context) => _buildDownloadButton(row),
        ),
      ],
      
      // 自定义列宽
      columnWidths: const [
        80,   // id
        400,  // 模板名称
        120,  // 引用次数
        150,  // 操作
      ],
      
      // 数据
      data: _pdfData,
      
      // 分页配置
      currentPage: _currentPage,
      totalItems: _totalItems,
      itemsPerPage: 20,
      onPageChanged: _handlePageChanged,
    );
  }

  /// 构建下载按钮
  Widget _buildDownloadButton(Map<String, dynamic> row) {
    return ElevatedButton(
      onPressed: () => _handleDownload(row),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: const Text('下载', style: TextStyle(fontSize: 13)),
    );
  }
}

