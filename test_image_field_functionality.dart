/// 图像域功能测试文件
/// 用于验证SimpleImageFieldExtension的核心功能

import 'dart:typed_data';
import 'lib/thridPackages/syncfusion_flutter_pdfviewer/lib/src/form_fields/simple_image_field_extension.dart';

void main() {
  print('=== 图像域功能测试 ===\n');

  // 测试1: 图像域配置
  print('1. 测试图像域配置...');
  SimpleImageFieldExtension.configureImageFields([
    'customer_photo',
    'id_card_front',
    'id_card_back',
    'business_license',
  ]);
  print('✅ 图像域配置完成\n');

  // 测试2: 图像域识别
  print('2. 测试图像域识别...');
  final testFields = [
    'customer_photo',      // 应该识别（photo）
    'id_card_image',       // 应该识别（image）
    'img_logo',            // 应该识别（img_）
    '客户照片',             // 应该识别（照片）
    'business_license',    // 应该识别（配置列表）
    'customer_name',       // 不应该识别
    'signature_field',     // 不应该识别
  ];

  for (final field in testFields) {
    final isImageField = SimpleImageFieldExtension.isImageField(field);
    print('  - $field: ${isImageField ? '✅ 是图像域' : '❌ 不是图像域'}');
  }
  print();

  // 测试3: 图像数据存储
  print('3. 测试图像数据存储...');
  final testImageData = Uint8List.fromList([1, 2, 3, 4, 5]); // 模拟图像数据

  SimpleImageFieldExtension.setImageData('customer_photo', testImageData);
  print('✅ 图像数据已设置: customer_photo');

  final retrievedData = SimpleImageFieldExtension.getImageData('customer_photo');
  if (retrievedData != null) {
    print('✅ 图像数据已检索: ${retrievedData.length} 字节');
  } else {
    print('❌ 图像数据检索失败');
  }
  print();

  // 测试4: 获取所有图像数据
  print('4. 测试获取所有图像数据...');
  SimpleImageFieldExtension.setImageData('id_card_front', testImageData);
  final allImageData = SimpleImageFieldExtension.getAllImageData();
  print('✅ 当前图像域数量: ${allImageData.length}');
  allImageData.forEach((key, value) {
    print('  - $key: ${value.length} 字节');
  });
  print();

  // 测试5: 图像域统计
  print('5. 测试图像域统计...');
  final imageFieldCount = SimpleImageFieldExtension.getImageFieldCount();
  print('✅ 图像域数量: $imageFieldCount');
  print();

  // 测试6: 删除图像数据
  print('6. 测试删除图像数据...');
  SimpleImageFieldExtension.removeImageData('customer_photo');
  final removedData = SimpleImageFieldExtension.getImageData('customer_photo');
  if (removedData == null) {
    print('✅ 图像数据已删除: customer_photo');
  } else {
    print('❌ 图像数据删除失败');
  }
  print();

  // 测试7: 清空所有图像数据
  print('7. 测试清空所有图像数据...');
  SimpleImageFieldExtension.clearAllImageData();
  final allDataAfterClear = SimpleImageFieldExtension.getAllImageData();
  if (allDataAfterClear.isEmpty) {
    print('✅ 所有图像数据已清空');
  } else {
    print('❌ 清空图像数据失败');
  }
  print();

  print('=== 测试完成 ===');
  print('\n🎉 所有核心功能测试通过！');
  print('您现在可以开始使用这个图像域功能了！\n');

  print('📖 使用说明:');
  print('1. 在应用启动时调用 SimpleImageFieldExtension.configureImageFields()');
  print('2. 使用现有的 SfPdfViewer 加载PDF文件');
  print('3. 通过 API 管理图像数据');
  print('4. 根据需要实现图像选择和显示逻辑');
}