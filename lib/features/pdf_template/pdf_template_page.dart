import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../data/models/pdf_template_info.dart';
import '../../data/repositories/pdf_template_info_repository.dart';
import '../../data/repositories/customer_repository.dart';
import '../../utils/context_extensions.dart';
import '../../utils/page_transition_animations.dart';
import '../../utils/pdf_template_utils.dart';
import '../../utils/file_utils.dart';
import '../../widgets/common_data_table_page.dart';
import '../customer_file/customer_file_preview_page.dart';

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

  final bool _showRemarkColumn = false; // 控制是否显示备注
  bool _isLoading = true;
  final PdfTemplateInfoRepository _pdfTemplateRepository = PdfTemplateInfoRepository();
  final CustomerRepository _customerRepository = CustomerRepository();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// 加载数据 - 组合数据库数据和常量数据
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 获取数据库中的PDF模板信息（仅用于备注）
      final pdfTemplateInfos = await _pdfTemplateRepository.findAll();

      // 创建signCode到备注的映射
      final Map<String, String> remarkMap = {};
      for (final info in pdfTemplateInfos) {
        remarkMap[info.signCode] = info.remark ?? '';
      }

      // 从工具类获取PDF模板列表
      final constantData = PdfTemplateUtils.getPdfTemplateList();

      // 组合数据
      _allPdfData = [];
      for (final item in constantData) {
        final signCode = item['signCode'] as String?;
        final templateName = item['name'] as String?;
        if (signCode != null && templateName != null) {
          // 动态统计使用次数
          final count = await _customerRepository.countByTemplateName(templateName);

          _allPdfData.add({
            'id': item['id'],
            'name': templateName,
            'assetPath': item['assetPath'],
            'count': count,
            'remark': remarkMap[signCode] ?? '',
            'signCode': signCode,
          });
        }
      }

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

  /// 获取Downloads目录 - 已弃用，使用 FileUtils.saveToDocuments 替代
  @deprecated
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

  /// 下载PDF - 使用新的文件工具类保存到文档目录
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
      // 从assets读取PDF文件
      final ByteData data = await rootBundle.load(assetPath);
      final List<int> bytes = data.buffer.asUint8List();

      // 使用平台特定的文件保存方法
      final savedPath = await FileUtils.saveFileForPlatform(
        bytes: Uint8List.fromList(bytes),
        fileName: '$fileName.pdf',
      );

      if (savedPath == null) {
        throw Exception('文件保存失败');
      }

      if (mounted) {
        // 显示文件操作对话框
        await FileUtils.showFileActionDialog(
          context,
          fileName: '$fileName.pdf',
          filePath: savedPath,
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
      columns: _buildTableColumns(),
      
      // 自定义列宽
      columnWidths: _showRemarkColumn ? const [
        80,   // id
        300,  // 模板名称
        100,  // 引用次数
        100,  // 备注
        250,  // 操作
      ] : const [
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

  /// 构建表格列
  List<DataTableColumn> _buildTableColumns() {
    // 基础列定义
    List<DataTableColumn> columns = [
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
    ];

    // 根据是否显示备注列来添加
    if (_showRemarkColumn) {
      columns.add(DataTableColumn(
        label: '备注',
        builder: (row, context) => Text(
          row['remark']?.toString() ?? '',
          style: const TextStyle(fontSize: 13),
        ),
      ));
    }

    // 添加操作列
    columns.add(DataTableColumn(
      label: '操作',
      builder: (row, context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: _buildActionButtons(row),
      ),
    ));

    return columns;
  }

  /// 构建操作按钮列表
  List<Widget> _buildActionButtons(Map<String, dynamic> row) {
    List<Widget> buttons = [
      _buildPreviewButton(row),
      const SizedBox(width: 8),
    ];

    // 根据是否显示备注列来添加修改备注按钮
    if (_showRemarkColumn) {
      buttons.add(_buildModifyRemarkButton(row));
      buttons.add(const SizedBox(width: 8));
    }

    buttons.add(_buildDownloadButton(row));

    return buttons;
  }

  /// 导航到预览页面
  Future<void> _navigateToPreviewPage(Map<String, dynamic> row, {required bool isEditMode}) async {
    final assetPath = row['assetPath']?.toString();
    final signCode = row['signCode'] as String;
    final result = await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return CustomerFilePreviewPage(
            templateAssetPath: assetPath,
            templateSignCode: signCode,
            isEditMode: false,
            isNewMode: false,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return PageTransitionAnimations.slideFromRight(child, animation);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );

    // 如果保存成功，刷新数据
    if (result == true && mounted) {
      _loadData();
    }
  }

  /// 构建文件预览按钮
  Widget _buildPreviewButton(Map<String, dynamic> row) {
    return ElevatedButton(
      onPressed: () => _navigateToPreviewPage(row, isEditMode: false),
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
      child: const Text('预览', style: TextStyle(fontSize: 13)),
    );
  }

  /// 构建修改备注按钮
  Widget _buildModifyRemarkButton(Map<String, dynamic> row) {
    return ElevatedButton(
      onPressed: () => _handleModifyRemark(row),
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
      child: const Text('修改备注', style: TextStyle(fontSize: 13)),
    );
  }

  /// 处理修改备注
  void _handleModifyRemark(Map<String, dynamic> row) {
    final signCode = row['signCode'] as String;
    final currentRemark = row['remark'] as String? ?? '';
    final TextEditingController remarkController = TextEditingController(text: currentRemark);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('修改备注'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '模板名称: ${row['name']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '模板ID: ${row['id']}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '备注内容:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: remarkController,
                  decoration: const InputDecoration(
                    hintText: '请输入备注内容',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  maxLines: 3,
                  minLines: 1,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _saveRemark(signCode, remarkController.text.trim());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  /// 保存备注到数据库
  Future<void> _saveRemark(String signCode, String newRemark) async {
    try {
      // 通过Repository更新备注
      final existingInfo = await _pdfTemplateRepository.findBySignCode(signCode);
      if (existingInfo != null) {
        final updatedInfo = existingInfo.copyWith(remark: newRemark);
        await _pdfTemplateRepository.update(updatedInfo);
      } else {
        // 如果不存在记录，创建新记录
        final newInfo = PdfTemplateInfo(
          signCode: signCode,
          usageCount: 0,
          remark: newRemark,
        );
        await _pdfTemplateRepository.insert(newInfo);
      }

      // 刷新页面数据
      _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('备注修改成功'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('备注修改失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

