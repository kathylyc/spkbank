import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// PDF表单字段数据模型
class PdfFormField {
  final String name;
  final String type;
  final String? value;
  final bool isReadOnly;
  final double? x;
  final double? y;
  final double? width;
  final double? height;
  final int? pageIndex;

  PdfFormField({
    required this.name,
    required this.type,
    this.value,
    this.isReadOnly = false,
    this.x,
    this.y,
    this.width,
    this.height,
    this.pageIndex,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'value': value ?? '',
      'isReadOnly': isReadOnly,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'pageIndex': pageIndex,
    };
  }

  @override
  String toString() {
    return 'PdfFormField{name: $name, type: $type, value: $value, isReadOnly: $isReadOnly, x: $x, y: $y, width: $width, height: $height}';
  }
}

/// PDF表单读取器
class PdfFormReader {
  // ========== 配置常量 ==========
  /// 是否在处理PDF时设置中文字体
  /// true: 为所有字段设置支持中文的字体
  /// false: 不设置字体，保持原始字体
  static const bool ENABLE_FONT_PROCESSING = true;
  
  /// 是否过滤Unicode编码为27979的字符（"测"字）
  /// true: 自动移除字段值中包含字符27979的内容
  /// false: 不过滤，保留所有字符
  static const bool ENABLE_FILTER_UNICODE_27979 = false;
  
  /// 要过滤的Unicode字符编码列表（可以扩展）
  static const List<int> FILTERED_UNICODE_CHARS = [27979];
  
  // 缓存加载的字体，避免重复加载
  static PdfTrueTypeFont? _cachedChineseFont;
  
  /// 加载支持中文的字体
  /// 字体文件应该放在 assets/fonts/ 目录下
  /// 支持的字体文件名：chinese_font.ttf, NotoSansSC-Regular.ttf, SourceHanSansSC-Regular.ttf, simsun.ttf
  static Future<PdfTrueTypeFont?> _loadChineseFont() async {
    if (_cachedChineseFont != null) {
      return _cachedChineseFont;
    }
    
    // 尝试加载不同的字体文件名
    // 注意：将实际存在的字体文件放在前面，提高加载效率
    final List<String> fontPaths = [
      // 实际存在的字体文件（优先）
      'assets/fonts/SourceHanSansSC-Regular.otf',
      'assets/fonts/SourceHanSansTC-Regular.otf',
      // 其他可能的字体文件
      'assets/fonts/chinese_font.ttf',
      'assets/fonts/SourceHanSansSC-Regular.ttf',
      'assets/fonts/SourceHanSansTC-Regular.ttf',
      'assets/fonts/NotoSansSC-Regular.ttf',
      'assets/fonts/NotoSansSC-Regular.otf',
      'assets/fonts/simsun.ttf',
      'assets/fonts/SimSun.ttf',
    ];
    
    for (final fontPath in fontPaths) {
      try {
        debugPrint('尝试加载字体: $fontPath');
        final ByteData fontData = await rootBundle.load(fontPath);
        
        // 检查字体数据是否为空
        if (fontData.lengthInBytes == 0) {
          debugPrint('字体文件 $fontPath 数据为空，跳过');
          continue;
        }
        
        final List<int> fontBytes = fontData.buffer.asUint8List();
        
        // 验证字体数据是否有效（至少应该有几千字节）
        if (fontBytes.length < 1000) {
          debugPrint('字体文件 $fontPath 数据太小(${fontBytes.length}字节)，可能损坏');
          continue;
        }
        
        // PdfTrueTypeFont 需要字体字节和字体大小
        // 注意：PdfTrueTypeFont 应该支持 .ttf 和 .otf 格式
        try {
          _cachedChineseFont = PdfTrueTypeFont(fontBytes, 12);
        } catch (e) {
          debugPrint('创建 PdfTrueTypeFont 失败: $e');
          debugPrint('可能是字体格式不支持或文件损坏');
          continue;
        }
        debugPrint('✓ 成功加载中文字体: $fontPath (大小: ${fontBytes.length} 字节)');
        return _cachedChineseFont;
      } catch (e) {
        // 字体文件不存在或无法加载，尝试下一个
        final errorMsg = e.toString();
        if (errorMsg.contains('does not exist') || errorMsg.contains('empty data')) {
          debugPrint('× 字体文件不存在或数据为空: $fontPath');
        } else {
          debugPrint('× 加载字体失败 $fontPath: $e');
        }
      }
    }
    
    debugPrint('⚠ 警告: 未找到可用的中文字体文件');
    debugPrint('已尝试的字体路径:');
    for (final path in fontPaths) {
      debugPrint('  - $path');
    }
    debugPrint('请确保：');
    debugPrint('1. 字体文件已放到 assets/fonts/ 目录下');
    debugPrint('2. pubspec.yaml 中已配置 assets/fonts/ 路径');
    debugPrint('3. 已运行 flutter pub get');
    debugPrint('4. 已重启应用');
    return null;
  }
  
  /// 从asset文件读取PDF表单字段
  static Future<List<PdfFormField>> readFormFieldsFromAsset(String assetPath) async {
    try {
      // 加载PDF文件
      final ByteData data = await rootBundle.load(assetPath);
      final List<int> bytes = data.buffer.asUint8List();
      
      // 解析PDF文档
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      
      // 提取表单字段
      final List<PdfFormField> fields = extractFormFields(document);
      
      // 关闭文档
      document.dispose();
      
      return fields;
    } catch (e) {
      throw Exception('读取PDF表单字段失败: $e');
    }
  }

  /// 从字节数据读取PDF表单字段
  static Future<List<PdfFormField>> readFormFieldsFromBytes(List<int> bytes) async {
    try {
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      final List<PdfFormField> fields = extractFormFields(document);
      document.dispose();
      return fields;
    } catch (e) {
      throw Exception('读取PDF表单字段失败: $e');
    }
  }

  /// 提取表单字段
  static List<PdfFormField> extractFormFields(PdfDocument document) {
    final List<PdfFormField> fields = [];
    
    try {
      // 检查PDF是否有表单
      final form = document.form;
      if (form.fields.count > 0) {
        final PdfFormFieldCollection formFields = form.fields;
        
        // 遍历所有表单字段
        for (int i = 0; i < formFields.count; i++) {
          final PdfField field = formFields[i];
          
          String type = 'Unknown';
          String? value;
          bool isReadOnly = false;
          double? x;
          double? y;
          double? width;
          double? height;
          int? pageIndex;
          
          // 尝试获取字段的边界信息
          try {
            final bounds = field.bounds;
            x = bounds.left;
            y = bounds.top;
            width = bounds.width;
            height = bounds.height;
            
            // 尝试获取字段所在的页码
            // 方法1: 尝试直接访问字段的page属性（如果Syncfusion PDF库支持）
            try {
              // 在Syncfusion PDF库中，某些字段类型可能有page属性
              // 我们尝试通过dynamic类型访问
              dynamic fieldDynamic = field;
              if (fieldDynamic.page != null) {
                // 如果page是一个PdfPage对象，需要获取其索引
                try {
                  final pageObj = fieldDynamic.page;
                  // 遍历页面找到匹配的页面对象
                  for (int pageIdx = 0; pageIdx < document.pages.count; pageIdx++) {
                    if (document.pages[pageIdx] == pageObj) {
                      pageIndex = pageIdx;
                      debugPrint('字段 ${field.name} 通过page属性确定位于第 ${pageIdx + 1} 页 (索引: $pageIndex)');
                      break;
                    }
                  }
                                 } catch (e) {
                   // 如果page是索引值
                   try {
                     final pageIdxValue = fieldDynamic.page as int;
                     pageIndex = pageIdxValue;
                     debugPrint('字段 ${field.name} 通过page索引确定位于第 ${pageIndex + 1} 页 (索引: $pageIndex)');
                   } catch (e2) {
                     // 忽略错误
                   }
                 }
              }
            } catch (e) {
              // page属性不存在或无法访问，继续使用其他方法
            }
            
            // 方法2: 如果方法1失败，通过字段的bounds和页面范围来推断
            // 注意：在PDF中，每个字段的bounds是相对于其所在页面的
            // 所有字段的坐标都是在各自页面的坐标系中（原点在左下角）
            // 所以我们需要通过其他方式来确定页码
            
            if (pageIndex == null) {
              // 遍历所有页面，尝试获取页面上的注释或字段
              // 在Syncfusion PDF库中，表单字段可能关联到页面的注释
              for (int pageIdx = 0; pageIdx < document.pages.count; pageIdx++) {
                final page = document.pages[pageIdx];
                try {
                  // 尝试获取页面上的注释集合
                  final annotations = page.annotations;
                  if (annotations != null) {
                    // 遍历注释，查找匹配的字段
                    for (int annIdx = 0; annIdx < annotations.count; annIdx++) {
                      final annotation = annotations[annIdx];
                      // 检查注释是否与当前字段相关
                      // 这需要根据Syncfusion PDF库的具体实现来调整
                      try {
                        // 如果注释有bounds，比较是否与字段bounds匹配
                        final annBounds = annotation.bounds;
                        if (annBounds != null && x != null && y != null) {
                          // 检查bounds是否匹配（允许小的误差）
                          if ((annBounds.left - x).abs() < 1 && 
                              (annBounds.top - y).abs() < 1) {
                            pageIndex = pageIdx;
                            debugPrint('字段 ${field.name} 通过页面注释匹配确定位于第 ${pageIdx + 1} 页 (索引: $pageIndex)');
                            break;
                          }
                        }
                      } catch (e) {
                        // 忽略错误，继续查找
                      }
                    }
                  }
                  if (pageIndex != null) break;
                } catch (e) {
                  // 忽略错误，继续查找下一页
                }
              }
            }
            
            // 方法3: 如果以上方法都失败，使用坐标推断（作为最后手段）
            // 这个方法不太可靠，因为所有字段的坐标都是相对于各自页面的
            // 但如果PDF文档中字段是按页面顺序添加的，我们可以尝试推断
            if (pageIndex == null && y != null && y >= 0) {
              // 假设字段是按照页面顺序处理的，使用一个简单的启发式方法
              // 如果Y坐标在合理范围内（0到典型页面高度），假设在第一页
              final firstPage = document.pages[0];
              final pageHeight = firstPage.size.height;
              
              // 如果Y坐标在典型页面高度范围内，可能在第一页
              // 但由于所有字段坐标都是相对于各自页面的，这个方法不太可靠
              // 所以我们只作为最后的备选方案
              if (y < pageHeight * 1.5) { // 允许一定误差
                pageIndex = 0;
                debugPrint('字段 ${field.name} 通过坐标推断位于第1页 (索引: $pageIndex), Y坐标: $y');
              } else {
                // 如果Y坐标很大，可能在后续页面
                // 但这不可靠，因为Y坐标是相对于页面底部的
                pageIndex = 0; // 默认设为第一页
                debugPrint('警告: 字段 ${field.name} 的Y坐标 $y 超出典型范围，默认设为第1页');
              }
            }
            
            // 如果仍然无法确定，默认设为第一页（索引0）
            if (pageIndex == null) {
              pageIndex = 0;
              debugPrint('警告: 无法确定字段 ${field.name} 的页码，默认设为第1页');
            }
          } catch (e) {
            debugPrint('获取字段边界信息失败: $e');
            // 如果获取边界失败，尝试其他方法
            pageIndex = 0; // 默认为第一页
          }
          
          // 根据字段类型处理
          if (field is PdfTextBoxField) {
            type = 'TextBox';
            value = field.text;
            isReadOnly = field.readOnly;
          } else if (field is PdfComboBoxField) {
            type = 'ComboBox';
            value = field.selectedValue;
            isReadOnly = field.readOnly;
          } else if (field is PdfCheckBoxField) {
            type = 'CheckBox';
            value = field.isChecked ? 'Yes' : 'No';
            isReadOnly = field.readOnly;
          } else if (field is PdfRadioButtonListField) {
            type = 'RadioButton';
            value = field.selectedIndex >= 0 ? field.items[field.selectedIndex].value : '';
            isReadOnly = field.readOnly;
          } else if (field is PdfSignatureField) {
            type = 'Signature';
            value = 'Signed';
            isReadOnly = field.readOnly;
          } else if (field is PdfListBoxField) {
            type = 'ListBox';
            // 获取选中的值
            if (field.items.count > 0) {
              final selectedItems = <String>[];
              for (int j = 0; j < field.items.count; j++) {
                final itemValue = field.items[j].value;
                selectedItems.add(itemValue);
              }
              value = selectedItems.join(', ');
            }
            isReadOnly = field.readOnly;
          } else if (field is PdfButtonField) {
            type = 'Button';
            value = 'Button';
            isReadOnly = field.readOnly;
          }
          
          final fieldName = field.name;
          if (fieldName != null && fieldName.isNotEmpty) {
            fields.add(PdfFormField(
              name: fieldName,
              type: type,
              value: value,
              isReadOnly: isReadOnly,
              x: x,
              y: y,
              width: width,
              height: height,
              pageIndex: pageIndex,
            ));
          }
        }
      }
    } catch (e) {
      debugPrint('提取表单字段时出错: $e');
    }
    
    return fields;
  }

  /// 更新PDF表单字段值并另存为新的PDF文件
  static Future<String> updateFieldValueAndSave(
    String assetPath,
    String fieldName,
    dynamic fieldValue,
  ) async {
    try {
      // 加载PDF文件
      final ByteData data = await rootBundle.load(assetPath);
      final List<int> bytes = data.buffer.asUint8List();
      
      // 解析PDF文档
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      
      // 更新字段值
      final form = document.form;
      final PdfFormFieldCollection formFields = form.fields;
      
      if (formFields.count > 0) {
        for (int i = 0; i < formFields.count; i++) {
          final PdfField field = formFields[i];
          
          if (field.name == fieldName) {
            // 根据字段类型更新值
            // 注意：不修改字体设置，保持原始PDF的字体配置
            if (field is PdfCheckBoxField) {
              if (fieldValue is bool) {
                field.isChecked = fieldValue;
              }
            } else if (field is PdfTextBoxField) {
              if (fieldValue is String) {
                field.text = fieldValue;
              }
            } else if (field is PdfComboBoxField) {
              if (fieldValue is String) {
                field.selectedValue = fieldValue;
              }
            } else if (field is PdfRadioButtonListField) {
              if (fieldValue is int) {
                field.selectedIndex = fieldValue;
              }
            } else if (field is PdfListBoxField) {
              // ListBox 的处理需要更多逻辑
              debugPrint('ListBox类型字段暂不支持自动更新');
            }
            
            debugPrint('已更新字段 $fieldName 的值为: $fieldValue');
            break;
          }
        }
      }
      
      // 根据配置决定是否处理字体和过滤字符
      if (ENABLE_FONT_PROCESSING) {
        await _processFonts(document, formFields);
      }
      
      if (ENABLE_FILTER_UNICODE_27979) {
        await _filterUnicodeCharacters(formFields);
        // 重要：即使过滤功能禁用，也要在保存前最后过滤ListBox字段的items
        await _filterListBoxItemsBeforeSave(formFields);
      }
      
      // 重要：即使过滤功能禁用，也要过滤ListBox字段的items选项
      // 因为ListBox的items是导致保存错误的直接原因
      await _filterListBoxItems(formFields);
      
      // 保存PDF文件
      final Directory tempDir = await getTemporaryDirectory();
      final String fileName = 'updated_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final String filePath = '${tempDir.path}/$fileName';
      final File file = File(filePath);
      
      List<int> pdfBytes = [];
      bool documentDisposed = false;
      
      
      try {
        // 尝试保存PDF（所有字段已设置为支持中文的字体，且已过滤字符27979）
        debugPrint('开始保存PDF...');
        final savedBytes = await document.save();
        
        // 检查保存结果是否有效
        if (savedBytes.isEmpty) {
          throw Exception('PDF保存返回空数据');
        }
        
        pdfBytes = savedBytes;
        debugPrint('PDF保存成功，大小: ${pdfBytes.length} 字节');
      } catch (e, stackTrace) {
        // 如果保存失败，记录详细的错误信息
        debugPrint('========== PDF保存失败 ==========');
        debugPrint('错误详情: $e');
        debugPrint('错误类型: ${e.runtimeType}');
        debugPrint('堆栈跟踪:');
        debugPrint(stackTrace.toString());
        
        // 如果是null check错误，可能是某些字段在设置字体后状态异常
        // 尝试重新加载文档，只更新字段值，不设置字体
        if (e.toString().contains('null value') || 
            e.toString().contains('Null check') ||
            e.toString().contains('null')) {
          debugPrint('检测到null值错误，尝试备用方法：不设置字体重新保存');
          
          try {
            // 关闭当前文档
            document.dispose();
            documentDisposed = true;
            
            // 重新加载PDF文档
            final ByteData data2 = await rootBundle.load(assetPath);
            final List<int> bytes2 = data2.buffer.asUint8List();
            final PdfDocument document2 = PdfDocument(inputBytes: bytes2);
            
            // 只更新目标字段的值，不设置字体
            final form2 = document2.form;
            final PdfFormFieldCollection formFields2 = form2.fields;
            
            if (formFields2.count > 0) {
              for (int i = 0; i < formFields2.count; i++) {
                final PdfField field = formFields2[i];
                if (field.name == fieldName) {
                  if (field is PdfCheckBoxField && fieldValue is bool) {
                    field.isChecked = fieldValue;
                  } else if (field is PdfTextBoxField && fieldValue is String) {
                    field.text = fieldValue;
                  } else if (field is PdfComboBoxField && fieldValue is String) {
                    field.selectedValue = fieldValue;
                  } else if (field is PdfRadioButtonListField && fieldValue is int) {
                    field.selectedIndex = fieldValue;
                  }
                  break;
                }
              }
            }
            
            // 尝试保存（不设置字体）
            try {
              final savedBytes2 = await document2.save();
              if (savedBytes2.isNotEmpty) {
                pdfBytes = savedBytes2;
                document2.dispose();
                documentDisposed = true; // 标记为已关闭
                debugPrint('✓ 使用备用方法保存成功（未设置字体）');
                // 备用方法成功，跳出catch块，继续执行文件写入
                // 不抛出异常，让代码继续执行后面的写入逻辑
              } else {
                document2.dispose();
                throw Exception('备用方法保存返回空数据');
              }
            } catch (e2) {
              document2.dispose();
              debugPrint('备用方法也失败: $e2');
              throw e2; // 重新抛出，让外层catch处理
            }
          } catch (e3) {
            debugPrint('尝试备用方法时出错: $e3');
            // 如果备用方法完全失败，继续抛出原始异常
          }
          
          // 如果备用方法也失败，记录错误信息
          // 注意：如果备用方法成功，pdfBytes会在上面被赋值
          if (pdfBytes.isEmpty) {
            debugPrint('检测到null值错误，可能的原因：');
            debugPrint('1. 字段的某些必需属性为null');
            debugPrint('2. 字体设置时某些字段的内部状态异常');
            debugPrint('3. PDF文档结构问题');
            debugPrint('4. 某些字段类型不支持字体设置');
            debugPrint('================================');
            
            // 关闭文档并抛出异常
            if (!documentDisposed) {
              document.dispose();
              documentDisposed = true;
            }
            
            throw Exception('保存PDF失败: $e');
          }
        } else {
          // 非null错误，直接抛出
          debugPrint('================================');
          if (!documentDisposed) {
            document.dispose();
            documentDisposed = true;
          }
          throw Exception('保存PDF失败: $e');
        }
      } finally {
        // 确保文档被关闭（如果还没有关闭的话）
        if (!documentDisposed) {
          document.dispose();
        }
      }
      
      // 将PDF写入文件
      try {
        await file.writeAsBytes(pdfBytes);
        debugPrint('PDF文件已写入: $filePath');
      } catch (e) {
        debugPrint('写入PDF文件失败: $e');
        throw Exception('写入PDF文件失败: $e');
      }
      
      debugPrint('PDF文件已保存到: $filePath');
      return filePath;
    } catch (e) {
      debugPrint('更新并保存PDF失败: $e');
      throw Exception('更新并保存PDF失败: $e');
    }
  }
  
  /// 检查字符串是否包含中文字符
  static bool _containsChinese(String text) {
    for (int i = 0; i < text.length; i++) {
      final int codeUnit = text.codeUnitAt(i);
      // 检查是否在CJK统一汉字范围内
      if (codeUnit >= 0x4E00 && codeUnit <= 0x9FFF) {
        return true;
      }
    }
    return false;
  }
  
  /// 过滤掉指定Unicode编码的字符
  /// [text] 要过滤的文本
  /// [unicodeCode] Unicode编码（如27979）
  /// 返回过滤后的文本
  static String _filterUnicodeCharacter(String text, int unicodeCode) {
    final StringBuffer result = StringBuffer();
    int removedCount = 0;
    
    for (int i = 0; i < text.length; i++) {
      final int codeUnit = text.codeUnitAt(i);
      if (codeUnit != unicodeCode) {
        result.writeCharCode(codeUnit);
      } else {
        removedCount++;
      }
    }
    
    if (removedCount > 0) {
      debugPrint('从文本中移除了 $removedCount 个Unicode $unicodeCode 字符');
    }
    
    return result.toString();
  }
  
  /// 处理字体：为所有字段设置支持中文的字体
  /// [document] PDF文档
  /// [formFields] 表单字段集合
  static Future<void> _processFonts(
    PdfDocument document,
    PdfFormFieldCollection formFields,
  ) async {
    debugPrint('开始处理字体...');
    
    // 加载支持中文的字体
    PdfTrueTypeFont? chineseFont;
    try {
      chineseFont = await _loadChineseFont();
    } catch (e) {
      debugPrint('加载中文字体失败: $e');
    }
    
    if (chineseFont == null) {
      document.dispose();
      throw Exception('无法加载中文字体文件，请确保字体文件已放到 assets/fonts/ 目录下');
    }
    
    try {
      int fontSetCount = 0;
      int fontSetFailedCount = 0;
      int skippedCount = 0;
      
      for (int i = 0; i < formFields.count; i++) {
        final PdfField field = formFields[i];
        final String fieldName = field.name ?? '未知字段$i';
        final String fieldType = field.runtimeType.toString();
        
        try {
          bool shouldSkip = false;
          
          if (field is PdfTextBoxField) {
            try {
              final _ = field.bounds;
              final _ = field.readOnly;
            } catch (e) {
              debugPrint('字段 $fieldName 属性访问失败，跳过设置字体: $e');
              skippedCount++;
              shouldSkip = true;
            }
            
            if (!shouldSkip) {
              try {
                field.font = chineseFont;
                fontSetCount++;
                debugPrint('✓ 为 TextBox 字段 $fieldName 设置字体成功');
              } catch (e, stackTrace) {
                debugPrint('× 为 TextBox 字段 $fieldName 设置字体失败: $e');
                debugPrint('字段类型: $fieldType');
                debugPrint('堆栈跟踪: $stackTrace');
                fontSetFailedCount++;
              }
            }
          } else if (field is PdfComboBoxField) {
            try {
              final _ = field.bounds;
              final _ = field.readOnly;
            } catch (e) {
              debugPrint('字段 $fieldName 属性访问失败，跳过设置字体: $e');
              skippedCount++;
              shouldSkip = true;
            }
            
            if (!shouldSkip) {
              try {
                field.font = chineseFont;
                fontSetCount++;
                debugPrint('✓ 为 ComboBox 字段 $fieldName 设置字体成功');
              } catch (e, stackTrace) {
                debugPrint('× 为 ComboBox 字段 $fieldName 设置字体失败: $e');
                debugPrint('字段类型: $fieldType');
                debugPrint('堆栈跟踪: $stackTrace');
                fontSetFailedCount++;
              }
            }
          } else if (field is PdfListBoxField) {
            try {
              final _ = field.bounds;
              final _ = field.readOnly;
            } catch (e) {
              debugPrint('字段 $fieldName 属性访问失败，跳过设置字体: $e');
              skippedCount++;
              shouldSkip = true;
            }
            
            if (!shouldSkip) {
              try {
                field.font = chineseFont;
                fontSetCount++;
                debugPrint('✓ 为 ListBox 字段 $fieldName 设置字体成功');
              } catch (e, stackTrace) {
                debugPrint('× 为 ListBox 字段 $fieldName 设置字体失败: $e');
                debugPrint('字段类型: $fieldType');
                debugPrint('堆栈跟踪: $stackTrace');
                fontSetFailedCount++;
              }
            }
          } else {
            skippedCount++;
            debugPrint('- 跳过字段 $fieldName (类型: $fieldType，不需要设置字体)');
          }
        } catch (e, stackTrace) {
          fontSetFailedCount++;
          debugPrint('× 处理字段 $fieldName 时发生异常: $e');
          debugPrint('字段类型: $fieldType');
          debugPrint('堆栈跟踪: $stackTrace');
        }
      }
      
      debugPrint('字体设置统计: 成功=$fontSetCount, 失败=$fontSetFailedCount, 跳过=$skippedCount');
      if (fontSetFailedCount > 0) {
        debugPrint('警告: 有 $fontSetFailedCount 个字段设置字体失败，可能影响PDF保存');
      }
    } catch (e, stackTrace) {
      debugPrint('设置中文字体时发生异常: $e');
      debugPrint('堆栈跟踪: $stackTrace');
    }
  }
  
  /// 过滤Unicode字符：移除字段值中指定的Unicode字符
  /// [formFields] 表单字段集合
  static Future<void> _filterUnicodeCharacters(
    PdfFormFieldCollection formFields,
  ) async {
    debugPrint('开始过滤不支持字符（Unicode ${FILTERED_UNICODE_CHARS.join(", ")}）...');
    int filteredCount = 0;
    
    try {
      for (int i = 0; i < formFields.count; i++) {
        final PdfField field = formFields[i];
        final String fieldName = field.name ?? '未知字段$i';
        
        try {
          if (field is PdfTextBoxField) {
            final text = field.text;
            if (text != null && text.isNotEmpty) {
              String filteredText = text;
              for (final unicodeCode in FILTERED_UNICODE_CHARS) {
                filteredText = _filterUnicodeCharacter(filteredText, unicodeCode);
              }
              if (filteredText != text) {
                field.text = filteredText;
                filteredCount++;
                debugPrint('过滤字段 $fieldName: 原文本: "$text" -> 新文本: "$filteredText"');
              }
            }
          } else if (field is PdfComboBoxField) {
            final selectedValue = field.selectedValue;
            if (selectedValue != null && selectedValue.isNotEmpty) {
              String filteredValue = selectedValue;
              for (final unicodeCode in FILTERED_UNICODE_CHARS) {
                filteredValue = _filterUnicodeCharacter(filteredValue, unicodeCode);
              }
              if (filteredValue != selectedValue) {
                // 检查过滤后的值是否在选项列表中
                bool foundInItems = false;
                for (int j = 0; j < field.items.count; j++) {
                  if (field.items[j].value == filteredValue) {
                    foundInItems = true;
                    break;
                  }
                }
                
                if (foundInItems) {
                  field.selectedValue = filteredValue;
                  filteredCount++;
                  debugPrint('过滤字段 $fieldName: 原值: "$selectedValue" -> 新值: "$filteredValue"');
                } else if (field.items.count > 0) {
                  field.selectedValue = field.items[0].value;
                  filteredCount++;
                  debugPrint('过滤字段 $fieldName: 原值: "$selectedValue" -> 使用第一个选项: "${field.items[0].value}"');
                }
              }
            }
          } else if (field is PdfListBoxField) {
            // ListBox字段需要处理items选项列表和选中值
            try {
              // 1. 过滤items选项列表中的值
              bool itemsFiltered = false;
              for (int j = 0; j < field.items.count; j++) {
                final item = field.items[j];
                final originalValue = item.value;
                if (originalValue != null && originalValue.isNotEmpty) {
                  String filteredValue = originalValue;
                  for (final unicodeCode in FILTERED_UNICODE_CHARS) {
                    filteredValue = _filterUnicodeCharacter(filteredValue, unicodeCode);
                  }
                  if (filteredValue != originalValue) {
                    // 更新选项的值
                    item.value = filteredValue;
                    itemsFiltered = true;
                    debugPrint('过滤ListBox选项 $fieldName[$j]: "$originalValue" -> "$filteredValue"');
                  }
                }
              }
              
              // 2. 过滤选中的值
              if (field.selectedValues != null && field.selectedValues.isNotEmpty) {
                List<String> filteredSelectedValues = [];
                for (final selectedValue in field.selectedValues) {
                  if (selectedValue != null && selectedValue.isNotEmpty) {
                    String filteredValue = selectedValue;
                    for (final unicodeCode in FILTERED_UNICODE_CHARS) {
                      filteredValue = _filterUnicodeCharacter(filteredValue, unicodeCode);
                    }
                    // 检查过滤后的值是否在items中
                    bool foundInItems = false;
                    for (int j = 0; j < field.items.count; j++) {
                      if (field.items[j].value == filteredValue) {
                        foundInItems = true;
                        filteredSelectedValues.add(filteredValue);
                        break;
                      }
                    }
                    if (!foundInItems && filteredValue.isNotEmpty) {
                      // 如果过滤后的值不在items中，尝试添加到items（如果可能）
                      filteredSelectedValues.add(filteredValue);
                    }
                  }
                }
                // 更新选中的值
                if (filteredSelectedValues.isNotEmpty) {
                  field.selectedValues = filteredSelectedValues;
                  filteredCount++;
                  debugPrint('过滤ListBox选中值 $fieldName: ${field.selectedValues} -> $filteredSelectedValues');
                }
              }
              
              if (itemsFiltered) {
                filteredCount++;
              }
            } catch (e) {
              debugPrint('过滤ListBox字段 $fieldName 时出错: $e');
            }
          }
        } catch (e) {
          debugPrint('过滤字段 $fieldName 时出错: $e');
        }
      }
      
      debugPrint('字符过滤完成: 共处理 $filteredCount 个字段');
    } catch (e) {
      debugPrint('过滤字符时发生异常: $e');
    }
  }
  
  /// 在执行document.save()之前，最后一次过滤Unicode字符
  /// [formFields] 表单字段集合
  static Future<void> _filterUnicodeCharactersBeforeSave(
    PdfFormFieldCollection formFields,
  ) async {
    debugPrint('执行document.save()前的最后过滤检查...');
    
    try {
      for (int i = 0; i < formFields.count; i++) {
        final PdfField field = formFields[i];
        final String fieldName = field.name ?? '未知字段$i';
        
        try {
          if (field is PdfTextBoxField) {
            final text = field.text;
            if (text != null && text.isNotEmpty) {
              bool needsFilter = false;
              for (final unicodeCode in FILTERED_UNICODE_CHARS) {
                if (text.contains(String.fromCharCode(unicodeCode))) {
                  needsFilter = true;
                  break;
                }
              }
              
              if (needsFilter) {
                String filteredText = text;
                for (final unicodeCode in FILTERED_UNICODE_CHARS) {
                  filteredText = _filterUnicodeCharacter(filteredText, unicodeCode);
                }
                field.text = filteredText;
                debugPrint('最后检查：字段 $fieldName 仍包含过滤字符，已移除');
              }
            }
          } else if (field is PdfComboBoxField) {
            final selectedValue = field.selectedValue;
            if (selectedValue != null && selectedValue.isNotEmpty) {
              bool needsFilter = false;
              for (final unicodeCode in FILTERED_UNICODE_CHARS) {
                if (selectedValue.contains(String.fromCharCode(unicodeCode))) {
                  needsFilter = true;
                  break;
                }
              }
              
              if (needsFilter) {
                String filteredValue = selectedValue;
                for (final unicodeCode in FILTERED_UNICODE_CHARS) {
                  filteredValue = _filterUnicodeCharacter(filteredValue, unicodeCode);
                }
                
                // 检查过滤后的值是否在选项中
                bool foundInItems = false;
                for (int j = 0; j < field.items.count; j++) {
                  if (field.items[j].value == filteredValue) {
                    foundInItems = true;
                    break;
                  }
                }
                
                if (foundInItems) {
                  field.selectedValue = filteredValue;
                  debugPrint('最后检查：字段 $fieldName 仍包含过滤字符，已移除');
                } else if (field.items.count > 0) {
                  field.selectedValue = field.items[0].value;
                  debugPrint('最后检查：字段 $fieldName 仍包含过滤字符，已设置为第一个选项');
                }
              }
            }
          } else if (field is PdfListBoxField) {
            // ListBox字段需要处理items选项列表和选中值
            try {
              debugPrint('最后检查ListBox字段: $fieldName，共有 ${field.items.count} 个选项');

              // 1. 检查并过滤items选项列表中的值
              bool itemsNeedFilter = false;
              for (int j = 0; j < field.items.count; j++) {
                final item = field.items[j];
                final itemValue = item.value ?? '';
                if (itemValue.isNotEmpty) {
                  for (final unicodeCode in FILTERED_UNICODE_CHARS) {
                    if (itemValue.contains(String.fromCharCode(unicodeCode))) {
                      itemsNeedFilter = true;
                      debugPrint('⚠ 最后检查发现ListBox选项 $fieldName[$j] 包含字符 $unicodeCode: "$itemValue"');
                      break;
                    }
                  }
                  if (itemsNeedFilter) break;
                }
              }

              if (itemsNeedFilter) {
                // 过滤所有items选项
                for (int j = 0; j < field.items.count; j++) {
                  final item = field.items[j];
                  final originalValue = item.value ?? '';
                  if (originalValue.isNotEmpty) {
                    String filteredValue = originalValue;
                    for (final unicodeCode in FILTERED_UNICODE_CHARS) {
                      filteredValue = _filterUnicodeCharacter(filteredValue, unicodeCode);
                    }
                    if (filteredValue != originalValue) {
                      item.value = filteredValue;
                      debugPrint('✓ 最后检查ListBox选项 $fieldName[$j]: "$originalValue" -> "$filteredValue"');

                      // 再次验证
                      final currentValue = item.value ?? '';
                      if (currentValue.contains(String.fromCharCode(27979))) {
                        debugPrint('⚠ 严重警告：过滤后选项 $fieldName[$j] 仍包含字符27979: "$currentValue"');
                      }
                    }
                  }
                }
              }

              // 最后验证：检查所有items是否还有需要过滤的字符
              bool stillHasFilteredChar = false;
              for (int j = 0; j < field.items.count; j++) {
                final itemValue = field.items[j].value ?? '';
                for (final unicodeCode in FILTERED_UNICODE_CHARS) {
                  if (itemValue.contains(String.fromCharCode(unicodeCode))) {
                    stillHasFilteredChar = true;
                    debugPrint('❌ 错误：ListBox选项 $fieldName[$j] 仍包含字符 $unicodeCode: "$itemValue"');
                  }
                }
              }
              if (stillHasFilteredChar) {
                debugPrint('❌ 错误：ListBox字段 $fieldName 仍有未过滤的字符，保存可能失败！');
              } else {
                debugPrint('✓ ListBox字段 $fieldName 所有选项已验证，无需要过滤的字符');
              }
              
              // 2. 检查并过滤选中的值
              if (field.selectedValues != null && field.selectedValues.isNotEmpty) {
                bool selectedNeedFilter = false;
                for (final selectedValue in field.selectedValues) {
                  if (selectedValue != null && selectedValue.isNotEmpty) {
                    for (final unicodeCode in FILTERED_UNICODE_CHARS) {
                      if (selectedValue.contains(String.fromCharCode(unicodeCode))) {
                        selectedNeedFilter = true;
                        break;
                      }
                    }
                    if (selectedNeedFilter) break;
                  }
                }
                
                if (selectedNeedFilter) {
                  List<String> filteredSelectedValues = [];
                  for (final selectedValue in field.selectedValues) {
                    if (selectedValue != null && selectedValue.isNotEmpty) {
                      String filteredValue = selectedValue;
                      for (final unicodeCode in FILTERED_UNICODE_CHARS) {
                        filteredValue = _filterUnicodeCharacter(filteredValue, unicodeCode);
                      }
                      // 检查过滤后的值是否在items中
                      bool foundInItems = false;
                      for (int j = 0; j < field.items.count; j++) {
                        if (field.items[j].value == filteredValue) {
                          foundInItems = true;
                          filteredSelectedValues.add(filteredValue);
                          break;
                        }
                      }
                      if (!foundInItems && filteredValue.isNotEmpty) {
                        filteredSelectedValues.add(filteredValue);
                      }
                    }
                  }
                  if (filteredSelectedValues.isNotEmpty) {
                    field.selectedValues = filteredSelectedValues;
                    debugPrint('最后检查ListBox选中值 $fieldName: 已过滤');
                  }
                }
              }
            } catch (e) {
              debugPrint('最后检查ListBox字段 $fieldName 时出错: $e');
            }
          }
        } catch (e) {
          debugPrint('最后检查字段 $fieldName 时出错: $e');
        }
      }
      debugPrint('最后过滤检查完成');
    } catch (e) {
      debugPrint('最后过滤检查时发生异常: $e');
    }
  }
  
  /// 过滤ListBox字段的items选项列表
  /// 即使过滤功能禁用，也要处理ListBox，因为它是导致保存错误的直接原因
  /// [formFields] 表单字段集合
  static Future<void> _filterListBoxItems(
    PdfFormFieldCollection formFields,
  ) async {
    debugPrint('开始过滤ListBox字段的items选项（Unicode ${FILTERED_UNICODE_CHARS.join(", ")}）...');
    int filteredCount = 0;
    
    try {
      for (int i = 0; i < formFields.count; i++) {
        final PdfField field = formFields[i];
        if (field is PdfListBoxField) {
          final String fieldName = field.name ?? '未知字段$i';
          
          try {
            // 过滤items选项列表中的值
            bool itemsFiltered = false;
            for (int j = 0; j < field.items.count; j++) {
              final item = field.items[j];
              final originalValue = item.value;
              if (originalValue != null && originalValue.isNotEmpty) {
                String filteredValue = originalValue;
                for (final unicodeCode in FILTERED_UNICODE_CHARS) {
                  filteredValue = _filterUnicodeCharacter(filteredValue, unicodeCode);
                }
                if (filteredValue != originalValue) {
                  item.value = filteredValue;
                  itemsFiltered = true;
                  debugPrint('过滤ListBox选项 $fieldName[$j]: "$originalValue" -> "$filteredValue"');
                }
              }
            }
            
            // 过滤选中的值
            if (field.selectedValues != null && field.selectedValues.isNotEmpty) {
              List<String> filteredSelectedValues = [];
              for (final selectedValue in field.selectedValues) {
                if (selectedValue != null && selectedValue.isNotEmpty) {
                  String filteredValue = selectedValue;
                  for (final unicodeCode in FILTERED_UNICODE_CHARS) {
                    filteredValue = _filterUnicodeCharacter(filteredValue, unicodeCode);
                  }
                  // 检查过滤后的值是否在items中
                  bool foundInItems = false;
                  for (int j = 0; j < field.items.count; j++) {
                    if (field.items[j].value == filteredValue) {
                      foundInItems = true;
                      filteredSelectedValues.add(filteredValue);
                      break;
                    }
                  }
                  if (!foundInItems && filteredValue.isNotEmpty) {
                    filteredSelectedValues.add(filteredValue);
                  }
                }
              }
              if (filteredSelectedValues.isNotEmpty) {
                field.selectedValues = filteredSelectedValues;
                filteredCount++;
                debugPrint('过滤ListBox选中值 $fieldName: 已过滤');
              }
            }
            
            if (itemsFiltered) {
              filteredCount++;
            }
          } catch (e) {
            debugPrint('过滤ListBox字段 $fieldName 时出错: $e');
          }
        }
      }
      
      debugPrint('ListBox items过滤完成: 共处理 $filteredCount 个字段');
    } catch (e) {
      debugPrint('过滤ListBox items时发生异常: $e');
    }
  }
  
  /// 在执行document.save()之前，最后一次过滤ListBox字段的items
  /// [formFields] 表单字段集合
  static Future<void> _filterListBoxItemsBeforeSave(
    PdfFormFieldCollection formFields,
  ) async {
    debugPrint('执行document.save()前的ListBox items最后过滤检查...');
    int filteredCount = 0;

    try {
      for (int i = 0; i < formFields.count; i++) {
        final PdfField field = formFields[i];
        if (field is PdfListBoxField) {
          final String fieldName = field.name ?? '未知字段$i';
          
          try {
            // 检查并过滤items选项列表中的值
            bool itemsNeedFilter = false;
            for (int j = 0; j < field.items.count; j++) {
              final item = field.items[j];
              final itemValue = item.value;
              if (itemValue != null && itemValue.isNotEmpty) {
                for (final unicodeCode in FILTERED_UNICODE_CHARS) {
                  if (itemValue.contains(String.fromCharCode(unicodeCode))) {
                    itemsNeedFilter = true;
                    break;
                  }
                }
                if (itemsNeedFilter) break;
              }
            }
            
            if (itemsNeedFilter) {
              // 过滤所有items选项
              for (int j = 0; j < field.items.count; j++) {
                final item = field.items[j];
                final originalValue = item.value;
                if (originalValue != null && originalValue.isNotEmpty) {
                  String filteredValue = originalValue;
                  for (final unicodeCode in FILTERED_UNICODE_CHARS) {
                    filteredValue = _filterUnicodeCharacter(filteredValue, unicodeCode);
                  }
                  if (filteredValue != originalValue) {
                    item.value = filteredValue;
                    debugPrint('最后检查ListBox选项 $fieldName[$j]: "$originalValue" -> "$filteredValue"');
                  }
                }
              }
            }
            
            // 检查并过滤选中的值
            if (field.selectedValues != null && field.selectedValues.isNotEmpty) {
              bool selectedNeedFilter = false;
              for (final selectedValue in field.selectedValues) {
                if (selectedValue != null && selectedValue.isNotEmpty) {
                  for (final unicodeCode in FILTERED_UNICODE_CHARS) {
                    if (selectedValue.contains(String.fromCharCode(unicodeCode))) {
                      selectedNeedFilter = true;
                      break;
                    }
                  }
                  if (selectedNeedFilter) break;
                }
              }
              
              if (selectedNeedFilter) {
                List<String> filteredSelectedValues = [];
                for (final selectedValue in field.selectedValues) {
                  if (selectedValue != null && selectedValue.isNotEmpty) {
                    String filteredValue = selectedValue;
                    for (final unicodeCode in FILTERED_UNICODE_CHARS) {
                      filteredValue = _filterUnicodeCharacter(filteredValue, unicodeCode);
                    }
                    // 检查过滤后的值是否在items中
                    bool foundInItems = false;
                    for (int j = 0; j < field.items.count; j++) {
                      if (field.items[j].value == filteredValue) {
                        foundInItems = true;
                        filteredSelectedValues.add(filteredValue);
                        break;
                      }
                    }
                    if (!foundInItems && filteredValue.isNotEmpty) {
                      filteredSelectedValues.add(filteredValue);
                    }
                  }
                }
                if (filteredSelectedValues.isNotEmpty) {
                  field.selectedValues = filteredSelectedValues;
                  debugPrint('最后检查ListBox选中值 $fieldName: 已过滤');
                }
              }
            }
          } catch (e) {
            debugPrint('最后检查ListBox字段 $fieldName 时出错: $e');
          }
        }
      }
      debugPrint('ListBox items最后过滤检查完成');
    } catch (e) {
      debugPrint('ListBox items最后过滤检查时发生异常: $e');
    }
  }
}
