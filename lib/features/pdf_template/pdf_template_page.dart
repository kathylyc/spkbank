import 'package:flutter/material.dart';
import '../../utils/context_extensions.dart';

/// PDF模板管理页面
class PdfTemplatePage extends StatelessWidget {
  const PdfTemplatePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.S.recentlyGeneratedPdfFiles,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _buildPdfTable(context),
          ),
        ],
      ),
    );
  }

  /// 构建PDF表格
  Widget _buildPdfTable(BuildContext context) {
    // 模拟数据
    final List<Map<String, dynamic>> pdfData = [
      {'id': 1, 'name': 'Account Mandate for Business Account', 'count': 15},
      {'id': 2, 'name': 'Appendix 2b - Entity Self Certification...', 'count': 12},
      {'id': 3, 'name': 'Account Mandate for Business Account', 'count': 10},
      {'id': 4, 'name': 'Appendix 2b - Entity Self Certification...', 'count': 8},
      {'id': 5, 'name': 'Account Mandate for Business Account', 'count': 12},
      {'id': 6, 'name': 'Appendix 2b - Entity Self Certification...', 'count': 10},
      {'id': 7, 'name': 'Account Mandate for Business Account', 'count': 15},
      {'id': 8, 'name': 'Appendix 2b - Entity Self Certification...', 'count': 12},
    ];

    return SingleChildScrollView(
      child: Table(
        border: TableBorder.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
        columnWidths: const {
          0: FlexColumnWidth(0.5),
          1: FlexColumnWidth(3),
          2: FlexColumnWidth(1),
          3: FlexColumnWidth(1),
        },
        children: [
          // 表头
          TableRow(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
            ),
            children: [
              _buildTableCell('id', isHeader: true),
              _buildTableCell('模板名称', isHeader: true),
              _buildTableCell('引用次数', isHeader: true),
              _buildTableCell('操作', isHeader: true),
            ],
          ),
          // 数据行
          ...pdfData.map((row) => TableRow(
            children: [
              _buildTableCell('${row['id']}'),
              _buildTableCell(row['name']),
              _buildTableCell('${row['count']}'),
              _buildTableCell(
                '下载',
                isButton: true,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('下载: ${row['name']}'),
                      backgroundColor: Colors.blue,
                    ),
                  );
                },
              ),
            ],
          )),
        ],
      ),
    );
  }

  /// 构建表格单元格
  Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    bool isButton = false,
    VoidCallback? onTap,
  }) {
    Widget content = Padding(
      padding: const EdgeInsets.all(12.0),
      child: isButton
          ? TextButton(
              onPressed: onTap,
              child: Text(
                text,
                style: const TextStyle(
                  color: Color(0xFF4299E1),
                ),
              ),
            )
          : Text(
              text,
              style: TextStyle(
                fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                fontSize: isHeader ? 14 : 13,
              ),
            ),
    );

    return content;
  }
}

