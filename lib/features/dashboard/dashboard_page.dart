import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../utils/context_extensions.dart';
import '../../widgets/common_data_table_page.dart';

/// Dashboard 页面
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {

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

    return SizedBox(
      height: 400,
      child: CommonDataTablePage(
        // 无查询条件区域
        querySection: const SizedBox.shrink(),
        
        // 表格标题
        tableTitle: context.S.recentlyGeneratedPdfFiles,
        
        // 右上角按钮（查看全部）
        actionButtons: [
          ActionButton(
            label: context.S.viewAll,
            color: Colors.blue,
            onPressed: () {
              // TODO: 跳转到查看全部页面
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.S.viewAll),
                  backgroundColor: Colors.blue,
                ),
              );
            },
          ),
        ],
        
        // 不显示复选框
        showCheckbox: false,
        
        // 表格列定义
        columns: [
          DataTableColumn(
            label: 'id',
            builder: (row, context) => Text(row['id'].toString()),
          ),
          DataTableColumn(
            label: context.S.customerName,
            builder: (row, context) => Text(row['customerName']),
          ),
          DataTableColumn(
            label: context.S.accountFileName,
            builder: (row, context) => Text(row['accountFileName']),
          ),
          DataTableColumn(
            label: context.S.fileVersion,
            builder: (row, context) => Text(row['fileVersion']),
          ),
          DataTableColumn(
            label: context.S.templateUsed,
            builder: (row, context) => Text(row['templateUsed']),
          ),
          DataTableColumn(
            label: context.S.accountManagerCode,
            builder: (row, context) => Text(row['accountManagerCode']),
          ),
          DataTableColumn(
            label: context.S.accountManagerName,
            builder: (row, context) => Text(row['accountManagerName']),
          ),
          DataTableColumn(
            label: context.S.updateTime,
            builder: (row, context) => Text(row['updateTime']),
          ),
        ],
        
        // 自定义列宽
        columnWidths: const [
          60,   // id
          120,  // 客户姓名
          280,  // 开户文件名称
          80,   // 文件版本
          280,  // 使用的模板
          140,  // 客户经理编码
          140,  // 客户经理姓名
          120,  // 更新时间
        ],
        
        // 数据
        data: pdfData,
        
        // 不显示分页（设置totalItems=0）
        currentPage: 1,
        totalItems: 0,
        itemsPerPage: 20,
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

