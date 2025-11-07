import 'package:flutter/material.dart';
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
  int _totalItems = 100; // 示例总数
  
  // 模拟数据
  List<Map<String, dynamic>> _pdfData = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// 加载数据
  void _loadData() {
    // 生成模拟数据
    final names = [
      'Account Mandate for Business Account',
      'Appendix 2b - Entity Self Certification...',
      'Application Form for Corporate Account',
      'Customer Due Diligence Form',
      'Business Registration Certificate',
    ];
    
    _pdfData = List.generate(20, (index) {
      final nameIndex = index % names.length;
      return {
        'id': (_currentPage - 1) * 20 + index + 1,
        'name': names[nameIndex],
        'count': 15 - (index % 8),
      };
    });
    
    setState(() {});
  }

  /// 页码变化
  void _handlePageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
    _loadData();
  }

  /// 下载PDF
  void _handleDownload(Map<String, dynamic> row) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('下载: ${row['name']}'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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

