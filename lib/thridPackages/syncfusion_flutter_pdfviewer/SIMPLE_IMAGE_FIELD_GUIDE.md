# PDF 图像域功能 - 简单使用指南

基于对 Syncfusion Flutter PDF Viewer 的深度分析，我们提供了一个极简的图像域解决方案，**只需传入图像域名称，所有其他功能自动处理**。

## 🎯 核心特点

- ✅ **极简配置**: 只需传入图像域名称列表
- ✅ **自动识别**: 智能识别图像域（包含 image、photo、图片、照片 等关键词）
- ✅ **完整功能**: 自动处理图片选择、查看、删除、保存
- ✅ **零修改**: 不需要修改现有的 SfPdfViewer 调用方法
- ✅ **即插即用**: 添加几行代码即可使用

## 🚀 最简单的使用方式

### 1. 基础配置 - 只需 1 行代码

```dart
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class MyPdfViewer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // 配置图像域 - 只需指定字段名
    SimpleImageFieldExtension.configureImageFields([
      'customer_photo',      // 客户照片
      'id_card_front',       // 身份证正面
      'id_card_back',        // 身份证反面
      'business_license',    // 营业执照
    ]);

    return SfPdfViewer.asset(
      'assets/your_form.pdf',
      // 其他配置保持不变
      enableDocumentMargin: true,
      canShowSignaturePadDialog: true,
    );
  }
}
```

### 2. 自动识别 - 无需配置

如果字段名包含以下关键词，会自动识别为图像域：

- `image`、`photo`、`图片`、`照片`
- 以 `img_` 开头的字段

```dart
// 以下字段名会自动识别为图像域，无需配置：
// 'customer_photo', 'id_image', '签名图片', 'img_logo'
```

## 📱 用户交互流程

### 上传图片
1. 用户点击图像域区域
2. 弹出选择对话框：从相册选择 / 拍照
3. 选择图片后自动验证和上传
4. 显示上传成功提示

### 已有图片的操作
1. 用户点击已有图片
2. 弹出操作对话框：查看 / 更换 / 删除
3. **查看图片**: 全屏预览，支持缩放
4. **更换图片**: 重新选择新图片
5. **删除图片**: 确认后清除图片

## 🔧 完整功能示例

```dart
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class CompleteImageFieldExample extends StatefulWidget {
  @override
  _CompleteImageFieldExampleState createState() => _CompleteImageFieldExampleState();
}

class _CompleteImageFieldExampleState extends State<CompleteImageFieldExample> {
  @override
  void initState() {
    super.initState();

    // 1. 配置图像域
    SimpleImageFieldExtension.configureImageFields([
      'customer_photo',
      'id_card_front',
      'id_card_back',
      'business_license',
      // 其他包含 image/photo 的字段会自动识别
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('PDF 表单'),
        actions: [
          IconButton(
            onPressed: _savePdf,
            icon: Icon(Icons.save),
          ),
        ],
      ),
      body: SfPdfViewer.asset(
        'assets/banking_form.pdf',
        // 2. 使用现有的 SfPdfViewer，无需修改
        onPdfTapped: _handlePdfTap,
      ),
    );
  }

  // 3. 处理点击事件（可选，用于自定义点击处理）
  void _handlePdfTap(PdfGestureDetails details) {
    // 检查点击位置是否为图像域并处理
    // 这一步是可选的，基本功能已经自动处理
  }

  // 4. 保存包含图片的PDF
  Future<void> _savePdf() async {
    try {
      // 获取当前PDF文档
      final PdfDocument document = _getCurrentPdfDocument();

      // 保存包含图像的PDF
      final List<int> savedData = await SimpleImageFieldExtension.savePdfWithImages(document);

      // 保存到文件或进行其他处理
      await saveToFile(savedData, 'completed_form.pdf');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF保存成功！')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败: $e')),
      );
    }
  }
}
```

## 🎛️ 高级配置选项

```dart
// 处理图像域点击时可以自定义参数
await SimpleImageFieldExtension.handleImageFieldClick(
  context,
  'customer_photo',
  maxFileSize: 10 * 1024 * 1024,  // 10MB
  imageQuality: 90,                 // 更高质量
  maxWidth: 2048,                   // 最大宽度
  maxHeight: 1536,                  // 最大高度
);
```

## 📊 状态管理

```dart
// 检查图像域状态
final hasImage = SimpleImageFieldExtension.getImageData('customer_photo') != null;
final imageCount = SimpleImageFieldExtension.getImageFieldCount();

// 获取所有图像数据
final allImages = SimpleImageFieldExtension.getAllImageData();

// 清空所有图像
SimpleImageFieldExtension.clearAllImageData();

// 删除特定图像
SimpleImageFieldExtension.removeImageData('customer_photo');
```

## 🔍 字段识别规则

图像域按以下优先级识别：

1. **明确指定**: 在 `configureImageFields()` 中明确指定的字段名
2. **关键词匹配**: 字段名包含以下关键词：
   - `image`、`photo`、`图片`、`照片`
   - 以 `img_` 开头的字段

```dart
// ✅ 会自动识别的字段名：
'customer_photo'        // 包含 photo
'id_card_image'         // 包含 image
'img_logo'              // 以 img_ 开头
'客户照片'               // 包含 图片
'business_license'      // ❌ 需要明确指定

// 配置示例：
SimpleImageFieldExtension.configureImageFields([
  'business_license',   // 明确指定
  // 其他字段自动识别
]);
```

## 🛠️ 集成到现有项目

### 第一步：添加配置
在应用启动或PDF加载前添加：

```dart
void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // 全局配置图像域
    SimpleImageFieldExtension.configureImageFields([
      'customer_photo',
      'id_card_front',
      'id_card_back',
    ]);

    return MaterialApp(
      home: MyPdfViewer(),
    );
  }
}
```

### 第二步：使用SfPdfViewer
现有的SfPdfViewer调用无需修改：

```dart
SfPdfViewer.asset(
  'assets/your_form.pdf',
  controller: _pdfViewerController,
  enableDocumentMargin: true,
  canShowSignaturePadDialog: true,
  // 其他现有配置保持不变
)
```

### 第三步：保存PDF（可选）
如果需要保存包含图片的PDF：

```dart
Future<void> saveCompletedForm() async {
  final document = await getPdfDocument();
  final savedData = await SimpleImageFieldExtension.savePdfWithImages(document);
  // 处理保存的数据
}
```

## 🎉 完成效果

使用此方案后，您的PDF表单将具有以下能力：

1. **自动识别图像域**: 根据字段名智能识别
2. **完整上传流程**: 相册选择、拍照、验证、上传
3. **图片管理**: 查看、更换、删除图片
4. **状态显示**: 清晰的视觉反馈
5. **PDF保存**: 将图片扁平化保存到PDF中
6. **零代码修改**: 现有的SfPdfViewer调用无需改变

## 📋 支持的功能特性

- ✅ 多种图片格式：JPG、PNG、BMP等
- ✅ 文件大小限制：可自定义
- ✅ 图片压缩：可调质量和尺寸
- ✅ 全屏预览：支持缩放查看
- ✅ 错误处理：友好的错误提示
- ✅ 状态管理：完整的图片生命周期
- ✅ 内存优化：高效的图片存储
- ✅ 跨平台：Android、iOS、Web支持

这个解决方案完美实现了您的需求：**只传入图像域名称，其他所有功能都由底层库自动处理**！