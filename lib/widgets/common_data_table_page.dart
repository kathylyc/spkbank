import 'package:flutter/material.dart';

/// 通用的数据表格页面组件
/// 上区域是查询条件，下区域是查询结果表格
class CommonDataTablePage extends StatefulWidget {
  /// 查询条件区域的widget
  final Widget querySection;
  
  /// 表格区域的标题描述
  final String tableTitle;
  
  /// 右上角的功能按钮列表
  final List<ActionButton> actionButtons;
  
  /// 表格列定义
  final List<DataTableColumn> columns;
  
  /// 表格数据
  final List<Map<String, dynamic>> data;
  
  /// 每页显示的条数
  final int itemsPerPage;
  
  /// 当前页码（从1开始）
  final int currentPage;
  
  /// 总记录数
  final int totalItems;
  
  /// 页码变化回调
  final Function(int page)? onPageChanged;
  
  /// 是否显示复选框列
  final bool showCheckbox;
  
  /// 复选框选中状态变化回调
  final Function(List<int> selectedIds)? onSelectionChanged;
  
  /// 自定义列宽（可选）
  /// 如果不提供，将使用默认的列宽配置
  final List<double>? columnWidths;

  const CommonDataTablePage({
    super.key,
    required this.querySection,
    required this.tableTitle,
    required this.actionButtons,
    required this.columns,
    required this.data,
    this.itemsPerPage = 20,
    this.currentPage = 1,
    this.totalItems = 0,
    this.onPageChanged,
    this.showCheckbox = true,
    this.onSelectionChanged,
    this.columnWidths,
  });

  @override
  State<CommonDataTablePage> createState() => _CommonDataTablePageState();
}

class _CommonDataTablePageState extends State<CommonDataTablePage> {
  final Set<int> _selectedIds = {};
  final ScrollController _headerScrollController = ScrollController();
  final ScrollController _bodyScrollController = ScrollController();
  bool _isScrollingHeader = false;
  bool _isScrollingBody = false;
  
  // 列宽配置
  List<double> _columnWidths = [];

  @override
  void initState() {
    super.initState();
    
    // 监听表头滚动，同步到数据体
    _headerScrollController.addListener(() {
      if (_isScrollingBody) return;
      _isScrollingHeader = true;
      if (_bodyScrollController.hasClients) {
        _bodyScrollController.jumpTo(_headerScrollController.offset);
      }
      _isScrollingHeader = false;
    });
    
    // 监听数据体滚动，同步到表头
    _bodyScrollController.addListener(() {
      if (_isScrollingHeader) return;
      _isScrollingBody = true;
      if (_headerScrollController.hasClients) {
        _headerScrollController.jumpTo(_bodyScrollController.offset);
      }
      _isScrollingBody = false;
    });
  }
  
  /// 计算每列的宽度
  /// [availableWidth] 可用的总宽度（用于自动填充）
  List<double> _calculateColumnWidths(double availableWidth) {
    List<double> baseWidths;
    
    // 获取基础列宽
    if (widget.columnWidths != null && widget.columnWidths!.length == widget.columns.length) {
      baseWidths = List.from(widget.columnWidths!);
    } else {
      // 使用智能计算的默认宽度
      baseWidths = List.generate(widget.columns.length, (index) {
        final label = widget.columns[index].label;
        
        // 根据列标签和常见内容类型设置不同的宽度
        if (label.toLowerCase() == 'id' || label == '序号') {
          return 80.0;
        }
        if (label.contains('姓名') || label.contains('电话') || label.contains('编码')) {
          return 140.0;
        }
        if (label.contains('地址')) {
          return 300.0;
        }
        if (label.contains('标签')) {
          return 200.0;
        }
        if (label.contains('附件')) {
          return 180.0;
        }
        if (label.contains('操作')) {
          return 240.0;
        }
        if (label.contains('状态') || label.contains('类型')) {
          return 120.0;
        }
        return 150.0;
      });
    }
    
    // 计算复选框列宽度
    final checkboxWidth = widget.showCheckbox ? 50.0 : 0.0;
    
    // 计算总宽度
    final totalBaseWidth = baseWidths.fold<double>(0, (sum, width) => sum + width) + checkboxWidth;
    
    // 如果总宽度小于可用宽度，需要自动延长某些列
    if (totalBaseWidth < availableWidth) {
      final extraSpace = availableWidth - totalBaseWidth;
      
      // 找出可以延长的列（排除ID、操作、数字类型的列）
      final expandableIndices = <int>[];
      for (int i = 0; i < widget.columns.length; i++) {
        final label = widget.columns[i].label;
        // 名称、标题类的文字列可以延长
        if (!label.toLowerCase().contains('id') && 
            !label.contains('序号') &&
            !label.contains('操作') &&
            !label.contains('次数') &&
            !label.contains('数量')) {
          expandableIndices.add(i);
        }
      }
      
      // 如果有可延长的列，平均分配额外空间
      if (expandableIndices.isNotEmpty) {
        final extraPerColumn = extraSpace / expandableIndices.length;
        for (final index in expandableIndices) {
          baseWidths[index] += extraPerColumn;
        }
      } else if (baseWidths.isNotEmpty) {
        // 如果没有明确的可延长列，将最后一列延长
        baseWidths[baseWidths.length - 1] += extraSpace;
      }
    }
    
    return baseWidths;
  }

  @override
  void dispose() {
    _headerScrollController.dispose();
    _bodyScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 检查是否有查询条件区域
    final hasQuerySection = widget.querySection is! SizedBox || 
                           (widget.querySection as SizedBox?)?.width != 0.0;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // 计算表格区域的可用宽度（减去外层padding、表格padding和边框）
        final availableWidth = constraints.maxWidth - 48.0 - 40.0 - 2.0;
        
        // 每次都重新计算列宽，以适应窗口大小变化
        _columnWidths = _calculateColumnWidths(availableWidth);
        
        return Container(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 查询条件区域（如果有）
              if (hasQuerySection) ...[
                _buildQuerySection(),
                const SizedBox(height: 24),
              ],
              
              // 表格区域
              Expanded(
                child: _buildTableSection(),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建查询条件区域
  Widget _buildQuerySection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: widget.querySection,
    );
  }

  /// 构建表格区域
  Widget _buildTableSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题和功能按钮
          _buildTableHeader(),
          
          const SizedBox(height: 16),
          
          // 表格
          Expanded(
            child: _buildTable(),
          ),
          
          const SizedBox(height: 16),
          
          // 分页器
          _buildPagination(),
        ],
      ),
    );
  }

  /// 构建表格头部（标题和按钮）
  Widget _buildTableHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 左侧标题
        Text(
          widget.tableTitle,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        
        // 右侧功能按钮
        Row(
          children: widget.actionButtons
              .map((button) => Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: ElevatedButton(
                      onPressed: button.onPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: button.color ?? Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: Text(button.label),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  /// 构建表格
  Widget _buildTable() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          // 固定表头
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: _headerScrollController,
            physics: const ClampingScrollPhysics(),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: _buildTableHeaderContent(),
            ),
          ),
          
          // 可滚动数据体
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: _bodyScrollController,
              physics: const ClampingScrollPhysics(),
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: _buildTableBodyContent(),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// 构建表头内容
  Widget _buildTableHeaderContent() {
    return Row(
      children: [
        // 复选框列
        if (widget.showCheckbox)
          Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Checkbox(
              value: _selectedIds.length == widget.data.length && widget.data.isNotEmpty,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selectedIds.addAll(
                      widget.data.map((row) => row['id'] as int? ?? 0),
                    );
                  } else {
                    _selectedIds.clear();
                  }
                });
                widget.onSelectionChanged?.call(_selectedIds.toList());
              },
            ),
          ),
        
        // 其他列
        ...widget.columns.asMap().entries.map((entry) {
          final index = entry.key;
          final column = entry.value;
          final columnWidth = _columnWidths[index];
          
          return Container(
            width: columnWidth,
            height: 50,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              border: Border(
                right: index < widget.columns.length - 1
                    ? BorderSide(color: Colors.grey.shade300)
                    : BorderSide.none,
              ),
            ),
            child: Text(
              column.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          );
        }),
      ],
    );
  }
  
  /// 构建表格数据体内容
  Widget _buildTableBodyContent() {
    if (widget.data.isEmpty) {
      final dataWidth = _columnWidths.fold<double>(
            0,
            (sum, width) => sum + width,
          ) +
          (widget.showCheckbox ? 50.0 : 0.0);
      return SizedBox(
        width: dataWidth,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 56),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: Text(
            '暂无数据',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ),
      );
    }

    return Column(
      children: widget.data.map((row) {
        final rowId = row['id'] as int? ?? 0;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 复选框列
              if (widget.showCheckbox)
                Container(
                  width: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(color: Colors.grey.shade300),
                      bottom: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Checkbox(
                    value: _selectedIds.contains(rowId),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedIds.add(rowId);
                        } else {
                          _selectedIds.remove(rowId);
                        }
                      });
                      widget.onSelectionChanged?.call(_selectedIds.toList());
                    },
                  ),
                ),
              
              // 其他列
              ...widget.columns.asMap().entries.map((entry) {
                final index = entry.key;
                final column = entry.value;
                final columnWidth = _columnWidths[index];
                
                return Container(
                  width: columnWidth,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      right: index < widget.columns.length - 1
                          ? BorderSide(color: Colors.grey.shade300)
                          : BorderSide.none,
                      bottom: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: DefaultTextStyle(
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade800,
                    ),
                    child: column.builder(row, context),
                  ),
                );
              }),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// 构建分页器
  Widget _buildPagination() {
    final totalPages = (widget.totalItems / widget.itemsPerPage).ceil();
    if (totalPages <= 1) return const SizedBox.shrink();
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // 上一页按钮
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: widget.currentPage > 1
              ? () => widget.onPageChanged?.call(widget.currentPage - 1)
              : null,
          color: Colors.grey.shade600,
        ),
        
        // 页码按钮
        ...List.generate(
          totalPages > 5 ? 5 : totalPages,
          (index) {
            int pageNumber;
            if (totalPages <= 5) {
              pageNumber = index + 1;
            } else if (widget.currentPage <= 3) {
              pageNumber = index + 1;
            } else if (widget.currentPage >= totalPages - 2) {
              pageNumber = totalPages - 4 + index;
            } else {
              pageNumber = widget.currentPage - 2 + index;
            }
            
            final isActive = pageNumber == widget.currentPage;
            
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                onTap: () => widget.onPageChanged?.call(pageNumber),
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isActive ? Colors.blue : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isActive ? Colors.blue : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    pageNumber.toString(),
                    style: TextStyle(
                      fontSize: 14,
                      color: isActive ? Colors.white : Colors.grey.shade800,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        
        // 下一页按钮
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: widget.currentPage < totalPages
              ? () => widget.onPageChanged?.call(widget.currentPage + 1)
              : null,
          color: Colors.grey.shade600,
        ),
      ],
    );
  }
}

/// 功能按钮配置
class ActionButton {
  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  const ActionButton({
    required this.label,
    this.onPressed,
    this.color,
  });
}

/// 表格列定义
class DataTableColumn {
  final String label;
  final Widget Function(Map<String, dynamic> row, BuildContext context) builder;

  const DataTableColumn({
    required this.label,
    required this.builder,
  });
}

