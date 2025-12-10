import 'package:bank_flutter/utils/snackbar_utils.dart';
import 'package:bank_flutter/utils/version_utils.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../utils/context_extensions.dart';
import '../../utils/screen_utils.dart';
import '../../utils/storage_utils.dart';
import '../../widgets/common_data_table_page.dart';
import '../../data/models/user.dart';
import '../../data/repositories/customer_repository.dart';

/// Dashboard 页面
class DashboardPage extends StatefulWidget {
  final VoidCallback? onNavigateToCustomerFile;

  const DashboardPage({
    super.key,
    this.onNavigateToCustomerFile,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final CustomerRepository _repository = CustomerRepository();
  final DateFormat _dateFormatter = DateFormat('yyyy-MM-dd HH:mm:ss');

  // 统计数据
  int _templateCount = 0;
  int _customerCount = 0;
  int _signedDocumentCount = 0;
  int _pendingDocumentCount = 0;
  
  // 最近生成的PDF文件数据
  List<Map<String, dynamic>> _recentPdfFiles = [];
  bool _isLoadingPdfFiles = true;
  
  // 饼图数据
  List<Map<String, Object?>> _pieChartData = [];
  
  // 柱状图数据
  List<Map<String, Object?>> _barChartData = [];
  
  bool _isLoading = true;
  User? _loginUser;
  
  bool get _isAccountManager => _loginUser?.userType == '01';
  String? get _managerAccount => _isAccountManager ? _loginUser?.userName : null;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  /// 加载用户信息
  Future<void> _loadUserInfo() async {
    final loginUser = await StorageUtils.getLoginUser();
    if (mounted) {
      setState(() {
        _loginUser = loginUser;
      });
      _loadData();
    }
  }

  /// 加载所有数据
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _isLoadingPdfFiles = true;
    });

    try {
      // 并行加载所有统计数据
      final results = await Future.wait([
        _repository.countDistinctTemplates(managerAccount: _managerAccount),
        _repository.count(managerAccount: _managerAccount),
        _repository.countSignedDocuments(managerAccount: _managerAccount),
        _repository.countPendingDocuments(managerAccount: _managerAccount),
        _repository.findAccountFilesWithDetails(limit: 10, managerAccount: _managerAccount),
        _repository.countFilesByCustomer(limit: 10, managerAccount: _managerAccount),
        _repository.getMonthlyStats(months: 5, managerAccount: _managerAccount),
      ]);

      setState(() {
        _templateCount = results[0] as int;
        _customerCount = results[1] as int;
        _signedDocumentCount = results[2] as int;
        _pendingDocumentCount = results[3] as int;
        _recentPdfFiles = (results[4] as List<Map<String, Object?>>)
            .map((row) => _convertToTableData(row))
            .toList();
        _pieChartData = results[5] as List<Map<String, Object?>>;
        _barChartData = results[6] as List<Map<String, Object?>>;
        _isLoading = false;
        _isLoadingPdfFiles = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isLoadingPdfFiles = false;
      });
      if (mounted) {
        SnackbarUtils.error('加载数据失败: $e', context);
      }
    }
  }

  /// 将数据库查询结果转换为表格数据格式
  Map<String, dynamic> _convertToTableData(Map<String, Object?> row) {
    final updateTime = row['update_time'] as String?;
    String formattedTime = '-';
    if (updateTime != null && updateTime.isNotEmpty) {
      try {
        final dateTime = DateTime.parse(updateTime);
        formattedTime = _dateFormatter.format(dateTime);
      } catch (e) {
        formattedTime = updateTime;
      }
    }

    return {
      'id': row['id'] ?? 0,
      'customerName': row['customer_name'] ?? '-',
      'company': (row['company'] as String?)?.isEmpty ?? true ? '-' : (row['company'] as String),
      'accountFileName': row['account_file_name'] ?? '-',
      'fileVersion': row['file_version'],
      'templateUsed': row['template_name'] ?? '-',
      'accountManagerCode': row['manager_code'] ?? '-',
      'accountManagerName': row['manager_name'] ?? '-',
      'updateTime': formattedTime,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
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
            value: _templateCount.toString(),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            title: context.S.customerQuantity,
            value: _customerCount.toString(),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            title: context.S.signedDocumentQuantity,
            value: _signedDocumentCount.toString(),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            title: context.S.pendingSignatureDocumentQuantity,
            value: _pendingDocumentCount.toString(),
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
        padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: ScreenUtils.isPhonePortrait(context) ? 80: 40,
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
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
    if (_isLoadingPdfFiles) {
      return Container(
        height: 450,
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 0),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Container(
      height: 450,
      margin: const EdgeInsets.symmetric(horizontal: 0),
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
              // 跳转到开户文件管理页面
              widget.onNavigateToCustomerFile?.call();
            },
          ),
        ],

        // 不显示复选框
        showCheckbox: false,

        // 禁用外层容器padding，因为dashboard已经有padding了
        disableOuterPadding: true,

        // 表格列定义
        columns: [
          DataTableColumn(
            label: '公司名称（中文/英文）',
            builder: (row, context) => Text(row['company']),
          ),
          DataTableColumn(
            label: context.S.accountFileName,
            builder: (row, context) => Text(row['accountFileName']),
          ),
          DataTableColumn(
            label: context.S.fileVersion,
            builder: (row, context) => Text(VersionUtils.intToString(row['fileVersion'])),
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

        // 数据
        data: _recentPdfFiles,

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
    // 定义颜色列表
    final colors = [
      const Color(0xFF4299E1),
      const Color(0xFF14B8A6),
      const Color(0xFFF97316),
      const Color(0xFFEC4899),
      const Color(0xFF8B5CF6),
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
      const Color(0xFFEF4444),
      const Color(0xFF06B6D4),
      const Color(0xFF84CC16),
    ];

    // 生成饼图数据
    final pieSections = _pieChartData.asMap().entries.map((entry) {
      final index = entry.key;
      final data = entry.value;
      final fileCount = ((data['file_count'] as num?) ?? 0).toInt();
      final color = colors[index % colors.length];
      
      return PieChartSectionData(
        value: fileCount.toDouble(),
        title: fileCount > 0 ? fileCount.toString() : '',
        color: color,
        radius: 80,
      );
    }).toList();

    // 生成图例
    final legendItems = _pieChartData.asMap().entries.map((entry) {
      final index = entry.key;
      final data = entry.value;
      final customerName = data['customer_name'] as String? ?? '-';
      final color = colors[index % colors.length];
      
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _buildLegendItem(customerName, color),
      );
    }).toList();

    if (_pieChartData.isEmpty) {
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
              SizedBox(
                height: 250,
                child: const Center(
                    child: Text('暂无数据'),
                  ),
              ),
            ],
          ),
        ),
      );
    }

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
            SizedBox(
              height: 250,
              child: Row(
                children: [
                  // 饼图
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 200,
                      child: PieChart(
                        PieChartData(
                          sections: pieSections,
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
                      children: legendItems,
                    ),
                  ),
                ],
              )
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
    // 计算最大Y值
    double maxY = 10;
    for (final data in _barChartData) {
      final customerCount = ((data['customer_count'] as num?) ?? 0).toDouble();
      final fileCount = ((data['file_count'] as num?) ?? 0).toDouble();
      final max = customerCount > fileCount ? customerCount : fileCount;
      if (max > maxY) {
        maxY = max;
      }
    }
    // 向上取整到最近的10的倍数
    maxY = (maxY / 10).ceil() * 10.0;
    if (maxY < 10) maxY = 10;

    // 生成月份标签
    final monthLabels = _barChartData.map((data) {
      final monthStr = data['month'] as String? ?? '';
      if (monthStr.length >= 7) {
        final parts = monthStr.split('-');
        if (parts.length >= 2) {
          final month = int.tryParse(parts[1]) ?? 0;
          return '$month月';
        }
      }
      return monthStr;
    }).toList();

    // 生成柱状图数据
    final barGroups = _barChartData.asMap().entries.map((entry) {
      final index = entry.key;
      final data = entry.value;
      final customerCount = ((data['customer_count'] as num?) ?? 0).toDouble();
      final fileCount = ((data['file_count'] as num?) ?? 0).toDouble();

      return BarChartGroupData(
        x: index,
        barsSpace: 4,
        barRods: [
          BarChartRodData(
            toY: customerCount,
            color: const Color(0xFF4299E1),
            width: 20,
          ),
          BarChartRodData(
            toY: fileCount,
            color: const Color(0xFF14B8A6),
            width: 20,
          ),
        ],
      );
    }).toList();

    if (_barChartData.isEmpty) {
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
                child: const Center(
                  child: Text('暂无数据'),
                ),
              ),
            ],
          ),
        ),
      );
    }

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
                  maxY: maxY,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < monthLabels.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                monthLabels[index],
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
                          final interval = maxY > 50 ? 10.0 : 5.0;
                          if (value.toInt() % interval.toInt() == 0) {
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
                    horizontalInterval: maxY > 50 ? 10.0 : 5.0,
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade300),
                      left: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  barGroups: barGroups,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

