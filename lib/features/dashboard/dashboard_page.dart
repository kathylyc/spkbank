import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../utils/context_extensions.dart';

/// Dashboard 页面
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade100,
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 统计卡片区域
            _buildSummaryCards(context),
            const SizedBox(height: 24),
            // 最近生成的PDF文件表格
            _buildRecentPdfFilesTable(context),
            const SizedBox(height: 24),
            // 图表区域
            _buildChartsSection(context),
          ],
        ),
      ),
    );
  }

  /// 构建统计卡片
  Widget _buildSummaryCards(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            title: context.S.templateQuantity,
            value: '8',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            title: context.S.customerQuantity,
            value: '8',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            title: context.S.signedDocumentQuantity,
            value: '8',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            title: context.S.pendingSignatureDocumentQuantity,
            value: '8',
          ),
        ),
      ],
    );
  }

  /// 构建单个统计卡片
  Widget _buildSummaryCard({
    required String title,
    required String value,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4CAF50), // 浅绿色
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建最近生成的PDF文件表格
  Widget _buildRecentPdfFilesTable(BuildContext context) {
    // 模拟数据
    final List<Map<String, dynamic>> pdfData = [
      {
        'id': 1,
        'customerName': '张三',
        'accountFileName': 'Account Mandate for Business Account',
        'fileVersion': 'v1.0',
        'templateUsed': 'Account Mandate for Business Account',
        'accountManagerCode': '20030211',
        'accountManagerName': '张经理',
        'updateTime': '2025-10-12',
      },
      {
        'id': 2,
        'customerName': '李四',
        'accountFileName': 'Appendix 2b - Entity Self Certification...',
        'fileVersion': 'v1.0',
        'templateUsed': 'Appendix 2b - Entity Self Certification...',
        'accountManagerCode': '20030211',
        'accountManagerName': '张经理',
        'updateTime': '2025-10-12',
      },
      {
        'id': 3,
        'customerName': '王五',
        'accountFileName': 'Account Mandate for Business Account',
        'fileVersion': 'v1.0',
        'templateUsed': 'Account Mandate for Business Account',
        'accountManagerCode': '20030211',
        'accountManagerName': '张经理',
        'updateTime': '2025-10-12',
      },
      {
        'id': 4,
        'customerName': '张三',
        'accountFileName': 'Appendix 2b - Entity Self Certification...',
        'fileVersion': 'v1.0',
        'templateUsed': 'Appendix 2b - Entity Self Certification...',
        'accountManagerCode': '20030211',
        'accountManagerName': '张经理',
        'updateTime': '2025-10-12',
      },
      {
        'id': 5,
        'customerName': '李四',
        'accountFileName': 'Account Mandate for Business Account',
        'fileVersion': 'v1.0',
        'templateUsed': 'Account Mandate for Business Account',
        'accountManagerCode': '20030211',
        'accountManagerName': '张经理',
        'updateTime': '2025-10-12',
      },
      {
        'id': 6,
        'customerName': '王五',
        'accountFileName': 'Appendix 2b - Entity Self Certification...',
        'fileVersion': 'v1.0',
        'templateUsed': 'Appendix 2b - Entity Self Certification...',
        'accountManagerCode': '20030211',
        'accountManagerName': '张经理',
        'updateTime': '2025-10-12',
      },
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题和查看全部按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.S.recentlyGeneratedPdfFiles,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // TODO: 跳转到查看全部页面
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.S.viewAll),
                        backgroundColor: Colors.blue,
                      ),
                    );
                  },
                  child: Text(
                    context.S.viewAll,
                    style: const TextStyle(
                      color: Color(0xFF4299E1),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 表格
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                border: TableBorder(
                  horizontalInside: BorderSide(
                    color: Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                columnWidths: const {
                  0: FixedColumnWidth(50),
                  1: FixedColumnWidth(100),
                  2: FixedColumnWidth(200),
                  3: FixedColumnWidth(80),
                  4: FixedColumnWidth(200),
                  5: FixedColumnWidth(120),
                  6: FixedColumnWidth(120),
                  7: FixedColumnWidth(120),
                },
                children: [
                  // 表头
                  TableRow(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                    ),
                    children: [
                      _buildDashboardTableCell('id', isHeader: true),
                      _buildDashboardTableCell(context.S.customerName, isHeader: true),
                      _buildDashboardTableCell(context.S.accountFileName, isHeader: true),
                      _buildDashboardTableCell(context.S.fileVersion, isHeader: true),
                      _buildDashboardTableCell(context.S.templateUsed, isHeader: true),
                      _buildDashboardTableCell(context.S.accountManagerCode, isHeader: true),
                      _buildDashboardTableCell(context.S.accountManagerName, isHeader: true),
                      _buildDashboardTableCell(context.S.updateTime, isHeader: true),
                    ],
                  ),
                  // 数据行
                  ...pdfData.map((row) => TableRow(
                    children: [
                      _buildDashboardTableCell('${row['id']}'),
                      _buildDashboardTableCell(row['customerName']),
                      _buildDashboardTableCell(row['accountFileName']),
                      _buildDashboardTableCell(row['fileVersion']),
                      _buildDashboardTableCell(row['templateUsed']),
                      _buildDashboardTableCell(row['accountManagerCode']),
                      _buildDashboardTableCell(row['accountManagerName']),
                      _buildDashboardTableCell(row['updateTime']),
                    ],
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建Dashboard表格单元格
  Widget _buildDashboardTableCell(String text, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          fontSize: isHeader ? 14 : 13,
          color: isHeader ? Colors.black87 : Colors.black54,
        ),
      ),
    );
  }

  /// 构建图表区域
  Widget _buildChartsSection(BuildContext context) {
    return Row(
      children: [
        // 左侧饼图
        Expanded(
          child: _buildPieChartCard(context),
        ),
        const SizedBox(width: 16),
        // 右侧柱状图
        Expanded(
          child: _buildBarChartCard(context),
        ),
      ],
    );
  }

  /// 构建饼图卡片
  Widget _buildPieChartCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.S.customerAccountFileCountStatistics,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                // 饼图
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 200,
                    child: PieChart(
                      PieChartData(
                        sections: [
                          PieChartSectionData(
                            value: 10,
                            title: '10',
                            color: const Color(0xFF4299E1),
                            radius: 80,
                          ),
                          PieChartSectionData(
                            value: 9,
                            title: '9',
                            color: const Color(0xFF14B8A6),
                            radius: 80,
                          ),
                          PieChartSectionData(
                            value: 8,
                            title: '8',
                            color: const Color(0xFFF97316),
                            radius: 80,
                          ),
                        ],
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                      ),
                    ),
                  ),
                ),
                // 图例
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLegendItem('张三', const Color(0xFF4299E1)),
                      const SizedBox(height: 12),
                      _buildLegendItem('李四', const Color(0xFF14B8A6)),
                      const SizedBox(height: 12),
                      _buildLegendItem('王五', const Color(0xFFF97316)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建图例项
  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  /// 构建柱状图卡片
  Widget _buildBarChartCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.S.monthlyNewCustomerAndNewAccountFileStatistics,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 250,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          const months = ['1月', '2月', '3月', '4月', '5月'];
                          if (value.toInt() >= 0 && value.toInt() < months.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                months[value.toInt()],
                                style: const TextStyle(fontSize: 12),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() % 50 == 0) {
                            return Text(
                              '${value.toInt()}',
                              style: const TextStyle(fontSize: 12),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 50,
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade300),
                      left: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  barGroups: [
                    BarChartGroupData(
                      x: 0,
                      barsSpace: 4,
                      barRods: [
                        BarChartRodData(
                          toY: 150,
                          color: const Color(0xFF4299E1),
                          width: 20,
                        ),
                        BarChartRodData(
                          toY: 100,
                          color: const Color(0xFF14B8A6),
                          width: 20,
                        ),
                      ],
                    ),
                    BarChartGroupData(
                      x: 1,
                      barsSpace: 4,
                      barRods: [
                        BarChartRodData(
                          toY: 100,
                          color: const Color(0xFF4299E1),
                          width: 20,
                        ),
                        BarChartRodData(
                          toY: 140,
                          color: const Color(0xFF14B8A6),
                          width: 20,
                        ),
                      ],
                    ),
                    BarChartGroupData(
                      x: 2,
                      barsSpace: 4,
                      barRods: [
                        BarChartRodData(
                          toY: 200,
                          color: const Color(0xFF4299E1),
                          width: 20,
                        ),
                        BarChartRodData(
                          toY: 230,
                          color: const Color(0xFF14B8A6),
                          width: 20,
                        ),
                      ],
                    ),
                    BarChartGroupData(
                      x: 3,
                      barsSpace: 4,
                      barRods: [
                        BarChartRodData(
                          toY: 140,
                          color: const Color(0xFF4299E1),
                          width: 20,
                        ),
                        BarChartRodData(
                          toY: 100,
                          color: const Color(0xFF14B8A6),
                          width: 20,
                        ),
                      ],
                    ),
                    BarChartGroupData(
                      x: 4,
                      barsSpace: 4,
                      barRods: [
                        BarChartRodData(
                          toY: 120,
                          color: const Color(0xFF4299E1),
                          width: 20,
                        ),
                        BarChartRodData(
                          toY: 140,
                          color: const Color(0xFF14B8A6),
                          width: 20,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

