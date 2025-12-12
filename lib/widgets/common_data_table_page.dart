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

  /// 是否禁用外层容器padding（用于在dashboard等已有padding的容器中使用）
  final bool disableOuterPadding;

  /// 横向滚动条样式配置（已弃用，请使用 scrollBarConfig）
  final ScrollBarStyle? scrollBarStyle;

  /// 滚动条配置
  final ScrollBarConfig? scrollBarConfig;

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
    this.disableOuterPadding = false,
    this.scrollBarStyle, // 保留以向后兼容
    this.scrollBarConfig,
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

    // 获取基础列宽 - 优先使用列定义中的width，然后是CommonDataTablePage的columnWidths，最后是智能计算的默认宽度
    if (widget.columnWidths != null && widget.columnWidths!.length == widget.columns.length) {
      baseWidths = List.from(widget.columnWidths!);
    } else {
      // 优先使用列定义中的width，否则使用智能计算的默认宽度
      baseWidths = List.generate(widget.columns.length, (index) {
        final column = widget.columns[index];

        // 如果列定义中有指定width，优先使用
        if (column.width != null) {
          return column.width!;
        }

        final label = column.label;

        // 根据列标签和常见内容类型设置不同的宽度
        if (label.toLowerCase() == 'id' || label == '序号') {
          return 80.0;
        }
        if (label.contains('姓名') || label.contains('电话') || label.contains('编码')) {
          return 140.0;
        }
        if (label.contains('公司') || label.contains('地址') || label.contains('开户文件名') || label.contains('使用模板')) {
          return 220.0;
        }
        if (label.contains('文件版本')) {
          return 100.0;
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
          padding: widget.disableOuterPadding ? EdgeInsets.zero : const EdgeInsets.all(24.0),
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
        SizedBox(
          width: 180,
          child: Text(
            widget.tableTitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
        ),

        // 右侧功能按钮 - 可水平滚动
        Expanded(child: _buildScrollableActionButtons()),
      ],
    );
  }

  /// 构建可水平滚动的功能按钮
  Widget _buildScrollableActionButtons() {
    return Align(
      alignment: Alignment.centerRight,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const AlwaysScrollableScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...widget.actionButtons.asMap().entries.map((entry) {
              final index = entry.key;
              final button = entry.value;
              return Padding(
                // 第一个按钮不需要左边距
                padding: EdgeInsets.only(left: index == 0 ? 0 : 12),
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
              );
            }),
          ],
        ),
      ),
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
          // 固定表头 - 不显示滚动条
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

          // 可滚动数据体 - 显示自定义滚动条
          Expanded(
            child: _buildCustomScrollBar(
              scrollDirection: Axis.horizontal,
              controller: _bodyScrollController,
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
  /// 构建自定义滚动条
  Widget _buildCustomScrollBar({
    required Axis scrollDirection,
    required ScrollController controller,
    required Widget child,
  }) {
    // 优先使用新的 ScrollBarConfig，如果为空则使用旧的 ScrollBarStyle 向后兼容
    final scrollBarConfig = widget.scrollBarConfig;
    final scrollBarStyle = widget.scrollBarStyle;

    // 如果都为空，使用默认配置
    final effectiveConfig = scrollBarConfig ?? ScrollBarConfig.defaultConfig;

    // 向后兼容：如果只传了旧的 scrollBarStyle，转换为新的配置
    Color? thumbColor = effectiveConfig.thumbColor;
    Color? trackColor = effectiveConfig.backgroundColor;
    double? thickness = effectiveConfig.height;
    BorderRadius? borderRadius = effectiveConfig.borderRadius;
    EdgeInsets? margin = effectiveConfig.margin;
    bool alwaysShow = effectiveConfig.alwaysShow;
    double? minThumbLength = effectiveConfig.thumbMinLength;

    // 如果有旧的 scrollBarStyle 配置，且新配置为空或默认值，则使用旧配置覆盖
    if (scrollBarStyle != null && scrollBarConfig == null) {
      thumbColor = thumbColor ?? scrollBarStyle.thumbColor;
      trackColor = trackColor ?? scrollBarStyle.trackColor;
      thickness = thickness ?? scrollBarStyle.thickness;
      borderRadius = borderRadius ?? scrollBarStyle.borderRadius;
      margin = margin ?? scrollBarStyle.margin;
      alwaysShow = alwaysShow || scrollBarStyle.alwaysShow;
      minThumbLength = minThumbLength ?? scrollBarStyle.minThumbLength;
    }

    // 计算滚动条圆角半径
    final radius = borderRadius != null
        ? borderRadius.topLeft
        : const Radius.circular(4.0);

    return ScrollbarTheme(
      data: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed) || states.contains(WidgetState.dragged)) {
            return (thumbColor ?? Colors.grey).withValues(alpha: 0.8);
          }
          return thumbColor;
        }),
        trackColor: WidgetStateProperty.all(trackColor),
        thickness: WidgetStateProperty.all(thickness),
        radius: radius,
        mainAxisMargin: margin?.horizontal ?? 0,
        crossAxisMargin: margin?.vertical ?? 0,
        trackBorderColor: WidgetStateProperty.all(Colors.transparent),
        trackVisibility: WidgetStateProperty.all(true),
        thumbVisibility: WidgetStateProperty.all(true),
        minThumbLength: minThumbLength,
      ),
      child: MediaQuery.removePadding(
        context: context,
        removeBottom: scrollDirection == Axis.horizontal,
        removeRight: scrollDirection == Axis.vertical,
        child: Scrollbar(
          controller: controller,
          thumbVisibility: alwaysShow,
          scrollbarOrientation: scrollDirection == Axis.horizontal
              ? ScrollbarOrientation.bottom
              : ScrollbarOrientation.right,
          thickness: thickness ?? 8.0,
          radius: radius,
          child: SingleChildScrollView(
            scrollDirection: scrollDirection,
            controller: controller,
            physics: const ClampingScrollPhysics(),
            child: child,
          ),
        ),
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
  final double? width;

  const DataTableColumn({
    required this.label,
    required this.builder,
    this.width,
  });
}

/// 滚动条配置（新增的简化配置方式）
class ScrollBarConfig {
  /// 滑块颜色
  final Color? thumbColor;

  /// 滑块最小长度（像素）
  final double? thumbMinLength;

  /// 滚动条背景色（轨道颜色）
  final Color? backgroundColor;

  /// 滚动条高度/厚度（像素）
  final double? height;

  /// 是否常驻显示
  final bool alwaysShow;

  /// 滚动条圆角
  final BorderRadius? borderRadius;

  /// 滚动条边距
  final EdgeInsets? margin;

  const ScrollBarConfig({
    this.thumbColor,
    this.thumbMinLength,
    this.backgroundColor,
    this.height,
    this.alwaysShow = true,
    this.borderRadius,
    this.margin,
  });

  /// 默认滚动条配置
  static const ScrollBarConfig defaultConfig = ScrollBarConfig(
    thumbColor: Colors.grey,
    thumbMinLength: 48.0,
    backgroundColor: Colors.transparent,
    height: 8.0,
    alwaysShow: true,
    borderRadius: BorderRadius.all(Radius.circular(4.0)),
  );

  /// 蓝色主题滚动条配置
  static const ScrollBarConfig blueConfig = ScrollBarConfig(
    thumbColor: Color(0xFF2196F3),
    thumbMinLength: 48.0,
    backgroundColor: Color(0xFFF0F0F0),
    height: 10.0,
    alwaysShow: true,
    borderRadius: BorderRadius.all(Radius.circular(8.0)),
    margin: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
  );

  /// 橙色数据密集型滚动条配置
  static const ScrollBarConfig orangeConfig = ScrollBarConfig(
    thumbColor: Colors.orange,
    thumbMinLength: 64.0,
    backgroundColor: Colors.grey,
    height: 12.0,
    alwaysShow: true,
    borderRadius: BorderRadius.all(Radius.circular(6.0)),
    margin: EdgeInsets.symmetric(horizontal: 1, vertical: 1),
  );
}

/// 滚动条样式配置（已弃用，请使用 ScrollBarConfig）
class ScrollBarStyle {
  /// 滚动条颜色
  final Color? thumbColor;

  /// 滚动条轨道颜色
  final Color? trackColor;

  /// 滚动条厚度
  final double? thickness;

  /// 滚动条圆角
  final BorderRadius? borderRadius;

  /// 滚动条边距
  final EdgeInsets? margin;

  /// 是否始终显示滚动条
  final bool alwaysShow;

  /// 滚动条最小长度
  final double? minThumbLength;

  /// 滚动条主轴对齐方式
  final MainAxisSize? mainAxisSize;

  const ScrollBarStyle({
    this.thumbColor,
    this.trackColor,
    this.thickness,
    this.borderRadius,
    this.margin,
    this.alwaysShow = false,
    this.minThumbLength,
    this.mainAxisSize,
  });

  /// 默认滚动条样式
  static const ScrollBarStyle defaultStyle = ScrollBarStyle(
    thumbColor: Colors.grey,
    trackColor: Colors.transparent,
    thickness: 8.0,
    alwaysShow: true, // 修改为始终显示
    minThumbLength: 48.0,
    borderRadius: BorderRadius.all(Radius.circular(4.0)),
  );

  /// 自定义蓝色滚动条样式
  static const ScrollBarStyle blueStyle = ScrollBarStyle(
    thumbColor: Color(0xFF2196F3),
    trackColor: Color(0xFFF0F0F0),
    thickness: 10.0,
    alwaysShow: true,
    minThumbLength: 48.0,
    borderRadius: BorderRadius.all(Radius.circular(8.0)),
    margin: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
  );

  /// 自定义橙色滚动条样式（适用于数据密集型表格）
  static const ScrollBarStyle orangeStyle = ScrollBarStyle(
    thumbColor: Colors.orange,
    trackColor: Colors.grey,
    thickness: 12.0,
    alwaysShow: true,
    minThumbLength: 64.0,
    borderRadius: BorderRadius.all(Radius.circular(6.0)),
    margin: EdgeInsets.symmetric(horizontal: 1, vertical: 1),
  );
}

