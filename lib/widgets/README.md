# 通用数据表格页面组件使用说明

## CommonDataTablePage

这是一个通用的数据表格页面组件，用于展示包含查询条件和数据表格的页面。

### 功能特点

- ✅ 上下分区布局：上区域为查询条件，下区域为数据表格
- ✅ 灵活的查询条件区域：可自定义任意查询表单
- ✅ 可配置的表格列：支持自定义列渲染
- ✅ 内置分页功能：每页默认20条记录
- ✅ 复选框支持：可选择性启用行选择功能
- ✅ 功能按钮配置：表格区域右上角可添加多个操作按钮
- ✅ 响应式设计：适配不同屏幕尺寸
- ✅ 固定表头：上下滚动数据时表头保持固定
- ✅ 横向滚动：表格内容超出屏幕宽度时可左右滚动，表头和数据体同步滚动
- ✅ 纵向滚动：数据行可独立上下滚动

### 基本用法

#### 完整功能页面（带查询和功能按钮）

```dart
import '../../widgets/common_data_table_page.dart';

class YourPage extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return CommonDataTablePage(
      // 查询条件区域
      querySection: _buildQuerySection(),
      
      // 表格标题
      tableTitle: '数据列表标题',
      
      // 功能按钮
      actionButtons: [
        ActionButton(
          label: '新增',
          onPressed: () {
            // 新增逻辑
          },
        ),
      ],
      
      // 表格列定义
      columns: [
        DataTableColumn(
          label: 'ID',
          builder: (row, context) => Text(row['id'].toString()),
        ),
        DataTableColumn(
          label: '名称',
          builder: (row, context) => Text(row['name']),
        ),
      ],
      
      // 数据
      data: _yourData,
      
      // 分页配置
      currentPage: _currentPage,
      totalItems: _totalItems,
      onPageChanged: (page) {
        setState(() {
          _currentPage = page;
        });
        _loadData();
      },
    );
  }
}
```

#### 简化页面（无查询条件和功能按钮）

```dart
CommonDataTablePage(
  // 查询条件区域为空
  querySection: const SizedBox.shrink(),
  
  // 表格标题
  tableTitle: 'PDF模板列表',
  
  // 功能按钮为空
  actionButtons: const [],
  
  // 不显示复选框
  showCheckbox: false,
  
  // 表格列定义
  columns: [
    DataTableColumn(
      label: 'ID',
      builder: (row, context) => Text(row['id'].toString()),
    ),
    DataTableColumn(
      label: '名称',
      builder: (row, context) => Text(row['name']),
    ),
  ],
  
  // 数据
  data: _yourData,
  
  // 分页配置
  currentPage: _currentPage,
  totalItems: _totalItems,
  onPageChanged: _handlePageChanged,
)
```

### 参数说明

#### CommonDataTablePage 参数

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `querySection` | Widget | ✅ | - | 查询条件区域的widget |
| `tableTitle` | String | ✅ | - | 表格区域的标题描述 |
| `actionButtons` | List<ActionButton> | ✅ | - | 右上角的功能按钮列表 |
| `columns` | List<DataTableColumn> | ✅ | - | 表格列定义 |
| `data` | List<Map<String, dynamic>> | ✅ | - | 表格数据 |
| `itemsPerPage` | int | ❌ | 20 | 每页显示的条数 |
| `currentPage` | int | ❌ | 1 | 当前页码（从1开始） |
| `totalItems` | int | ❌ | 0 | 总记录数 |
| `onPageChanged` | Function(int)? | ❌ | null | 页码变化回调 |
| `showCheckbox` | bool | ❌ | true | 是否显示复选框列 |
| `onSelectionChanged` | Function(List<int>)? | ❌ | null | 复选框选中状态变化回调 |
| `columnWidths` | List<double>? | ❌ | null | 自定义列宽配置（不提供则自动计算） |

#### ActionButton 参数

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `label` | String | ✅ | - | 按钮文本 |
| `onPressed` | VoidCallback? | ❌ | null | 点击回调 |
| `color` | Color? | ❌ | Colors.blue | 按钮颜色 |

#### DataTableColumn 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `label` | String | ✅ | 列标题 |
| `builder` | Widget Function(Map<String, dynamic>, BuildContext) | ✅ | 单元格内容构建函数 |

### 高级用法示例

#### 1. 自定义查询条件区域

```dart
Widget _buildQuerySection() {
  return Row(
    children: [
      Expanded(
        child: TextField(
          decoration: InputDecoration(labelText: '搜索关键字'),
        ),
      ),
      SizedBox(width: 16),
      ElevatedButton(
        onPressed: _handleSearch,
        child: Text('查询'),
      ),
      SizedBox(width: 8),
      ElevatedButton(
        onPressed: _handleReset,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey.shade200,
        ),
        child: Text('重置'),
      ),
    ],
  );
}
```

#### 2. 自定义单元格渲染（状态标签）

```dart
DataTableColumn(
  label: '签署状态',
  builder: (row, context) {
    final status = row['status'];
    Color backgroundColor;
    Color textColor;
    
    switch (status) {
      case '已签署':
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        break;
      case '未签署':
        backgroundColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        break;
      default:
        backgroundColor = Colors.grey.shade100;
        textColor = Colors.grey.shade800;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 13,
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  },
),
```

#### 3. 操作列示例（多种按钮样式）

```dart
DataTableColumn(
  label: '操作',
  builder: (row, context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 蓝色按钮（主操作）
        ElevatedButton(
          onPressed: () => _handlePreview(row),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('文件预览', style: TextStyle(fontSize: 13)),
        ),
        
        const SizedBox(width: 8),
        
        // 灰色按钮（次要操作）
        ElevatedButton(
          onPressed: () => _handleEdit(row),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade300,
            foregroundColor: Colors.grey.shade800,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('修改', style: TextStyle(fontSize: 13)),
        ),
        
        const SizedBox(width: 8),
        
        // 红色按钮（危险操作）
        ElevatedButton(
          onPressed: () => _handleDelete(row),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('删除', style: TextStyle(fontSize: 13)),
        ),
      ],
    );
  },
),
```

#### 4. 标签显示示例

```dart
DataTableColumn(
  label: '标签',
  builder: (row, context) {
    final tags = row['tags'] as List<String>;
    return Wrap(
      spacing: 8,
      children: tags.map((tag) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(tag),
        );
      }).toList(),
    );
  },
),
```

#### 5. 链接样式示例

```dart
DataTableColumn(
  label: '附件',
  builder: (row, context) {
    final files = row['files'] as List<String>;
    return InkWell(
      onTap: () => _viewFiles(files),
      child: Text(
        files.join(','),
        style: TextStyle(
          color: Colors.blue,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  },
),
```

### 完整示例

完整的使用示例请参考：

1. **带查询条件和功能按钮的页面**：`lib/features/customer/customer_page.dart`
   - 包含查询条件区域（客户姓名、电话号码、客户标签）
   - 包含功能按钮（新增客户、导入客户、导出客户）
   - 显示复选框列
   - 包含多个操作按钮（修改、上传附件、删除）
   - 支持分页

2. **简化的纯表格页面**：`lib/features/pdf_template/pdf_template_page.dart`
   - 无查询条件区域
   - 无功能按钮
   - 不显示复选框列
   - 只有简单的下载按钮
   - 支持分页

3. **嵌入式表格展示**：`lib/features/dashboard/dashboard_page.dart`
   - 无查询条件区域
   - 有"查看全部"按钮
   - 不显示复选框列
   - 不显示分页器（显示最近几条记录）
   - 固定高度显示

4. **开户文件管理页面**：`lib/features/customer_file/customer_file_page.dart`
   - 包含查询条件区域（客户姓名、电话号码、开户文件名）
   - 包含功能按钮（扫描生成PDF、新增开户文件、导出压缩包）
   - 显示复选框列
   - 包含状态标签显示（已签署/未签署）
   - 包含三种样式的操作按钮（文件预览-蓝色、修改-灰色、删除-红色）
   - 支持分页

5. **客户经理管理页面**：`lib/features/account_manager/account_manager_page.dart`
   - 包含查询条件区域（客户经理编号、客户经理姓名、客户经理手机）
   - 包含功能按钮（新增客户经理、下载导入模板、导入客户经理）
   - 显示复选框列
   - 包含操作按钮（修改-蓝色、重置密码-蓝色、删除-红色）
   - 支持分页

### 样式定制

组件使用了Material Design风格，默认颜色方案：

- 主色调：蓝色 (`Colors.blue`)
- 边框色：浅灰色 (`Colors.grey.shade200`)
- 表头背景：浅灰色 (`Colors.grey.shade50`)
- 危险操作：红色 (`Colors.red`)

如需修改样式，可以直接修改 `common_data_table_page.dart` 文件中的相关样式定义。

### 滚动特性

组件支持灵活的滚动功能：

1. **固定表头**：表头始终保持在顶部可见，不会随数据滚动而移动
2. **纵向滚动**：数据行可以上下滚动查看更多内容
3. **横向滚动**：当表格列较多超出屏幕宽度时，可以左右滚动
4. **同步滚动**：表头和数据体的横向滚动自动同步，确保列对齐

### 列宽和对齐

组件使用固定列宽来确保表头和数据体完美对齐：

1. **自动列宽计算**：根据列标签智能计算合适的列宽
   - ID、序号列：80px
   - 姓名、电话、编码：140px
   - 地址：300px
   - 标签：200px
   - 附件：180px
   - 操作：240px
   - 状态、类型：120px
   - 默认：150px

2. **自动填充屏幕**：当列总宽度小于可用宽度时，自动延长文字列以填满屏幕
   - 自动识别可延长的列（排除ID、操作、数量等列）
   - 将多余空间平均分配给可延长的列
   - 响应式调整，窗口大小变化时自动重新计算

3. **自定义列宽**：可以通过 `columnWidths` 参数自定义每列的宽度

```dart
CommonDataTablePage(
  columns: [...],  // 假设有5列
  columnWidths: [80, 150, 200, 180, 240],  // 自定义每列宽度
  // ... 其他参数
)
```

4. **对齐保证**：
   - 表头和数据体使用完全相同的列宽配置
   - 所有单元格内容左对齐
   - 复选框列固定50px宽度，居中对齐

### 注意事项

1. **数据格式**：传入的 `data` 必须是 `List<Map<String, dynamic>>` 格式
2. **列标识**：建议在数据中包含唯一的 `id` 字段，用于复选框选择
3. **分页处理**：需要自行实现数据加载逻辑，通过 `onPageChanged` 回调处理
4. **响应式布局**：查询条件区域建议使用 `Expanded` 包裹输入框以适应不同屏幕宽度
5. **性能优化**：大数据量时建议启用虚拟滚动或服务端分页
6. **列宽配置**：
   - 组件会自动根据列标签计算合适的列宽
   - 如需自定义，通过 `columnWidths` 参数传入每列宽度（单位：px）
   - 确保 `columnWidths` 数组长度与 `columns` 长度一致
7. **滚动体验**：使用了 `ClampingScrollPhysics` 来优化滚动体验
8. **最后一列显示**：确保操作列能完整显示，建议设置合适的列宽（如 240px）

### 扩展建议

如需更多功能，可考虑添加：

- ✅ **固定列宽**：已实现，确保列对齐
- ✅ **固定表头**：已实现，支持纵向滚动
- ✅ **横向滚动**：已实现，支持宽表格
- ✅ **自动填充屏幕**：已实现，列数少时自动延长文字列
- 排序功能：点击列标题排序
- 筛选功能：列级别的快速筛选
- 导出功能：导出为Excel/CSV
- 列宽拖拽调整：鼠标拖拽调整列宽
- 列显示/隐藏：自定义显示哪些列
- 固定列：左侧或右侧列固定（如操作列始终可见）
- 行高自适应：根据内容自动调整行高

