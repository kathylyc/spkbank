# PDF 图像域功能扩展

基于对 Syncfusion Flutter PDF Viewer 的深度分析，我们实现了一个简洁的图像域解决方案，让用户只需传入图像域名称即可，底层库自动处理图片选择、更换、删除和扁平化保存。

## 🎯 核心特性

- **自动识别**: 根据字段名称自动识别图像域
- **智能处理**: 自动处理图片选择、更换、删除
- **扁平化保存**: 自动将图片扁平化保存到PDF
- **简单配置**: 只需传入图像域名称列表
- **完整功能**: 支持拍照、相册选择、图片预览、删除等

## 🚀 快速开始

### 1. 基本使用

```dart
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

SfPdfViewer.asset(
  'assets/your_form.pdf',
  imageFieldConfig: const ImageFieldConfig(
    imageFieldNames: [
      'customer_photo',
      'id_card_front',
      'id_card_back',
      'business_license'
    ],
  ),
)
```

### 2. 完整配置示例

```dart
SfPdfViewer.asset(
  'assets/banking_form.pdf',
  imageFieldConfig: ImageFieldConfig(
    // 指定哪些字段是图像域
    imageFieldNames: ['photo', 'signature', 'document'],

    // 文件大小限制 (5MB)
    maxFileSize: 5 * 1024 * 1024,

    // 允许的文件格式
    allowedFormats: ['jpg', 'jpeg', 'png', 'bmp'],

    // 自定义文本
    uploadText: '点击上传图片',
    uploadedText: '图片已上传 ✓',

    // 自定义颜色
    uploadedColor: Colors.green.shade100,
    iconColor: Colors.blue,
    textColor: Colors.grey.shade600,

    // 图像处理设置
    enableCrop: false,
    imageQuality: 85,
    maxWidth: 1920,
    maxHeight: 1080,
  ),
)
```

### 3. 保存包含图片的PDF

```dart
class MyPdfViewer extends StatefulWidget {
  @override
  _MyPdfViewerState createState() => _MyPdfViewerState();
}

class _MyPdfViewerState extends State<MyPdfViewer> {
  late ImageFieldManager _imageFieldManager;

  @override
  void initState() {
    super.initState();
    _imageFieldManager = ImageFieldManager();
  }

  Future<void> savePdf() async {
    try {
      // 获取PDF文档
      final PdfDocument document = await getPdfDocument();

      // 保存包含图像的PDF
      final List<int> savedData = await _imageFieldManager.saveDocumentWithImageFields(document);

      // 保存到文件
      await saveToFile(savedData, 'output_with_images.pdf');

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

## 🔍 自动识别规则

图像域会根据以下规则自动识别：

1. **配置指定**: 在 `ImageFieldConfig.imageFieldNames` 中明确指定的字段名
2. **命名约定**: 字段名包含以下关键词的会被自动识别
   - `image`
   - `photo`
   - `图片`
   - `照片`
   - 以 `img_` 开头的字段

```dart
// 以下字段名都会被识别为图像域:
'customer_photo'        // ✅ 包含 photo
'id_card_image'         // ✅ 包含 image
'img_signature'         // ✅ 以 img_ 开头
'客户照片'               // ✅ 包含 图片
'business_license'      // ❌ 需要在配置中明确指定
```

## 📱 用户交互流程

### 上传图片
1. 用户点击图像域
2. 弹出选择对话框：从相册选择 / 拍照
3. 选择图片后自动验证大小和格式
4. 显示上传成功提示

### 已有图片的操作
1. 用户点击已有图片的图像域
2. 弹出操作对话框：查看 / 更换 / 删除
3. 查看图片：全屏预览，支持缩放
4. 更换图片：重新选择新图片
5. 删除图片：确认后清除图片

## 🔧 高级功能

### 自定义图像处理

```dart
ImageFieldConfig(
  // 启用图片裁剪
  enableCrop: true,

  // 图像质量控制 (0-100)
  imageQuality: 90,

  // 最大尺寸限制
  maxWidth: 2048,
  maxHeight: 1536,

  // 自定义UI
  uploadText: '请上传证件照片',
  uploadedText: '已上传 ✓',
  uploadedColor: Color(0xFFE8F5E8),
  iconColor: Color(0xFF2196F3),
)
```

### 批量保存多个图像域

```dart
// 获取所有图像数据
final Map<String, Uint8List> allImageData = _imageFieldManager.getAllImageData();

// 手动保存到特定文档
final List<int> savedData = await _imageFieldManager.saveDocumentWithImageFieldsMap(
  document,
  allImageData,
);
```

### 图像数据管理

```dart
// 获取特定字段的图像数据
final Uint8List? imageData = _imageFieldManager.getImageData('customer_photo');

// 手动设置图像数据
_imageFieldManager.saveImageData('customer_photo', imageBytes);

// 删除图像数据
_imageFieldManager.removeImageData('customer_photo');
```

## 🏗️ 架构设计

### 核心组件

1. **PdfImageFormField**: 图像域表单字段类，扩展自PdfFormField
2. **ImageFieldManager**: 图像域管理器，处理所有图像相关操作
3. **ImageFieldConfig**: 图像域配置类，定义图像域行为和外观
4. **FormFieldContainer**: 表单域容器，集成图像域支持

### 处理流程

```
用户点击图像域 → ImageFieldManager → 图片选择/处理 → 数据存储 → UI更新 → PDF保存
```

## 📋 支持的文件格式

- **JPEG (.jpg, .jpeg)**: 推荐用于照片
- **PNG (.png)**: 支持透明背景
- **BMP (.bmp)**: 位图格式

## 🚨 注意事项

1. **性能考虑**:
   - 大图片会自动压缩以提高性能
   - 建议设置合理的文件大小限制

2. **内存管理**:
   - 图像数据会存储在内存中
   - 大量图片时注意内存使用

3. **PDF兼容性**:
   - 保存后的PDF与标准PDF阅读器兼容
   - 图片会扁平化到PDF中，无法再次编辑

4. **权限要求**:
   - Android: 需要相机和存储权限
   - iOS: 需要相机和相册权限

## 🔧 故障排除

### 常见问题

**Q: 图像域没有被识别为可点击区域？**
A: 检查字段名是否符合识别规则，或者在 `ImageFieldConfig` 中明确指定。

**Q: 图片上传失败？**
A: 检查文件大小是否超过限制，文件格式是否支持。

**Q: 保存PDF后图片丢失？**
A: 确保调用了 `ImageFieldManager.saveDocumentWithImageFields()` 方法。

**Q: 内存使用过高？**
A: 减小 `maxFileSize`、`maxWidth`、`maxHeight` 设置，或降低 `imageQuality`。

## 📚 示例代码

完整的使用示例请参考：
- `example/lib/image_field_example.dart` - 完整功能示例
- `example/lib/simple_example.dart` - 最简单的使用方式

## 🎉 总结

通过这个扩展，开发者可以：

1. **极简集成**: 只需一行配置即可支持图像域
2. **自动处理**: 底层自动处理所有复杂的图像操作
3. **功能完整**: 支持完整的图像管理流程
4. **高性能**: 优化的图像处理和内存管理
5. **灵活配置**: 支持丰富的自定义选项

这个解决方案完美解决了Adobe Acrobat图像域在Syncfusion PDF Viewer中的兼容性问题，提供了简洁而强大的图像域功能。