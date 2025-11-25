import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui show Image, ImageByteFormat;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_signaturepad/signaturepad.dart';
import '../../data/models/customer_account_file.dart';
import '../../data/repositories/customer_repository.dart';
import '../../utils/file_manager.dart';
import '../../utils/storage_utils.dart';

/// 开户文件预览页面
class CustomerFilePreviewPage extends StatefulWidget {
  final String? customerName;
  final String? fileName;
  final String? templateName;
  final String? templateAssetPath; // PDF 模板的 asset 路径（可选）
  final String? filePath; // PDF 文件的实际路径（可选，优先使用此路径）
  final bool isEditMode; // 是否为编辑模式
  final String? accountFileUid; // 账户文件 UID（用于保存）
  final String? customerUid; // 客户 UID（用于保存）
  final String? fileVersion; // 文件版本（用于保存）
  final String? fileSrcType; // 文件来源类型（用于保存）
  final String? templateSignCode; // 模板签名代码（用于保存）

  const CustomerFilePreviewPage({
    super.key,
    this.customerName,
    this.fileName,
    this.templateName,
    this.templateAssetPath,
    this.filePath,
    this.isEditMode = false,
    this.accountFileUid,
    this.customerUid,
    this.fileVersion,
    this.fileSrcType,
    this.templateSignCode,
  });

  @override
  State<CustomerFilePreviewPage> createState() => _CustomerFilePreviewPageState();
}

class _CustomerFilePreviewPageState extends State<CustomerFilePreviewPage> {
  PdfViewerController? _pdfViewerController;
  bool _isLoading = true;
  String? _error;
  Uint8List? _pdfBytes;
  Uint8List? _originalPdfBytes; // 保存原始未修改的 PDF 字节
  PdfDocument? _currentDocument; // 保存当前文档的引用，用于保存时复制表单字段值
  
  // 字体相关
  PdfTrueTypeFont? _chineseFont;
  List<int>? _chineseFontBytes;
  
  // Repository
  final CustomerRepository _repository = CustomerRepository();

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    _initializePdf();
  }

  @override
  void dispose() {
    _pdfViewerController?.dispose();
    _currentDocument?.dispose();
    super.dispose();
  }

  /// 初始化PDF：先加载字体，再加载PDF
  Future<void> _initializePdf() async {
    await _loadChineseFont();
    await _loadPdf();
  }

  /// 加载支持中文的字体
  Future<void> _loadChineseFont() async {
    final List<String> fontPaths = [
      'assets/fonts/SourceHanSerifSC-VF.ttf',
    ];

    for (final fontPath in fontPaths) {
      try {
        debugPrint('尝试加载字体: $fontPath');
        final ByteData fontData = await rootBundle.load(fontPath);

        if (fontData.lengthInBytes == 0) {
          continue;
        }

        final List<int> fontBytes = fontData.buffer.asUint8List();

        if (fontBytes.length < 1000) {
          continue;
        }

        try {
          _chineseFont = PdfTrueTypeFont(fontBytes, 10);
          _chineseFontBytes = List<int>.from(fontBytes);
          debugPrint('✓ 成功加载中文字体: $fontPath');
          return;
        } catch (e) {
          debugPrint('创建 PdfTrueTypeFont 失败: $e');
          continue;
        }
      } catch (e) {
        // 字体文件不存在，尝试下一个
      }
    }

    debugPrint('⚠ 警告: 未找到可用的中文字体文件');
  }

  /// 加载PDF文件
  Future<void> _loadPdf() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      Uint8List bytes;

      // 优先使用文件路径加载
      if (widget.filePath != null && widget.filePath!.isNotEmpty) {
        try {
          final file = File(widget.filePath!);
          if (await file.exists()) {
            bytes = await file.readAsBytes();
            debugPrint('从文件路径加载PDF成功: ${widget.filePath}');
          } else {
            throw Exception('文件不存在: ${widget.filePath}');
          }
        } catch (e) {
          debugPrint('从文件路径加载PDF失败: $e');
          // 如果文件路径加载失败，尝试使用 asset 路径
          if (widget.templateAssetPath != null && widget.templateAssetPath!.isNotEmpty) {
            final ByteData data = await rootBundle.load(widget.templateAssetPath!);
            bytes = data.buffer.asUint8List();
            debugPrint('回退到 asset 路径加载PDF: ${widget.templateAssetPath}');
          } else {
            throw Exception('文件路径不存在且未提供 asset 路径');
          }
        }
      } else if (widget.templateAssetPath != null && widget.templateAssetPath!.isNotEmpty) {
        // 使用 asset 路径加载
        final ByteData data = await rootBundle.load(widget.templateAssetPath!);
        bytes = data.buffer.asUint8List();
        debugPrint('从 asset 路径加载PDF成功: ${widget.templateAssetPath}');
      } else {
        throw Exception('未提供有效的 PDF 文件路径或 asset 路径');
      }

      setState(() {
        _pdfBytes = bytes;
        _originalPdfBytes = Uint8List.fromList(bytes); // 保存原始 PDF 的副本
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '加载PDF失败: $e';
        _isLoading = false;
      });
      debugPrint('加载PDF失败，文件路径: ${widget.filePath}, asset路径: ${widget.templateAssetPath}, 错误: $e');
    }
  }

  /// 保存PDF文件
  Future<void> _handleSave() async {
    // 验证必要参数
    if (widget.accountFileUid == null || 
        widget.customerUid == null || 
        widget.fileVersion == null ||
        _originalPdfBytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法保存：缺少必要的信息')),
        );
      }
      return;
    }

    try {
      // 显示保存提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('正在保存开户文件...')),
        );
      }

      // 获取登录用户
      final loginUser = await StorageUtils.getLoginUser();
      final now = DateTime.now();

      // 1. 查询该 account_file_uid 的最大版本号并加一
      String newFileVersion;
      final maxVersion = await _repository.findMaxVersionByAccountFileUid(widget.accountFileUid!);
      if (maxVersion != null) {
        final currentVersion = int.tryParse(maxVersion) ?? 0;
        newFileVersion = (currentVersion + 1).toString();
      } else {
        newFileVersion = '1';
      }

      // 2. 构建目标文件路径
      // 使用 FileManager 的方式构建路径，但我们需要先创建一个临时文件
      final tempDir = await getTemporaryDirectory();
      final tempOriginalPath = '${tempDir.path}/temp_original_${widget.accountFileUid}.pdf';
      final tempOriginalFile = File(tempOriginalPath);
      await tempOriginalFile.writeAsBytes(_originalPdfBytes!);

      // 使用 FileManager 创建目标路径（它会复制文件）
      final savedFilePath = await FileManager.saveAccountFileWithName(
        sourcePath: tempOriginalPath,
        accountFileUid: widget.accountFileUid!,
        fileVersion: newFileVersion,
      );

      // 清理临时文件
      if (await tempOriginalFile.exists()) {
        await tempOriginalFile.delete();
      }

      // 3. 将页面上的表单数据保存到新的PDF中
      // 根据 Syncfusion 文档，对于包含手写签名的表单，最佳实践是：
      // 优先使用 PdfViewerController.saveDocument() 方法，因为它会保存 viewer 中的所有数据，
      // 包括手写签名和其他表单字段的值
      List<int> savedBytes;
      
      // 优先使用 PdfViewerController.saveDocument() 保存，这样可以确保手写签名正确保存
      if (_pdfViewerController != null) {
        try {
          debugPrint('使用 PdfViewerController.saveDocument() 保存（包含手写签名）...');
          savedBytes = await _pdfViewerController!.saveDocument();
          debugPrint('✓ 使用 PdfViewerController.saveDocument() 保存成功');
          
          // 检查是否有签名字段，如果有则扁平化以确保签名正确显示
          if (_currentDocument != null) {
            try {
              final PdfForm form = _currentDocument!.form;
              bool hasSignedFields = false;
              
              for (int i = 0; i < form.fields.count; i++) {
                final PdfField field = form.fields[i];
                if (field is PdfSignatureField) {
                  try {
                    dynamic fieldDynamic = field;
                    final signature = fieldDynamic.signature;
                    if (signature != null) {
                      hasSignedFields = true;
                      debugPrint('✓ 检测到签名字段 ${field.name} 已签名');
                    }
                  } catch (e) {
                    debugPrint('⚠ 检查签名字段 ${field.name} 时出错: $e');
                  }
                }
              }
              
              // 如果有签名，需要重新加载保存的文档并扁平化签名字段
              if (hasSignedFields) {
                try {
                  debugPrint('检测到签名字段，重新加载文档以扁平化签名...');
                  final PdfDocument flattenDocument = PdfDocument(inputBytes: savedBytes);
                  final PdfForm flattenForm = flattenDocument.form;
                  
                  for (int i = 0; i < flattenForm.fields.count; i++) {
                    final PdfField field = flattenForm.fields[i];
                    if (field is PdfSignatureField) {
                      try {
                        dynamic fieldDynamic = field;
                        final signature = fieldDynamic.signature;
                        if (signature != null) {
                          // 扁平化签名字段以确保签名正确显示
                          try {
                            field.flatten();
                            debugPrint('✓ 扁平化签名字段 ${field.name}');
                          } catch (e) {
                            debugPrint('⚠ 扁平化签名字段 ${field.name} 失败: $e');
                          }
                        }
                      } catch (e) {
                        debugPrint('⚠ 处理签名字段 ${field.name} 时出错: $e');
                      }
                    }
                  }
                  
                  // 重新保存扁平化后的文档
                  savedBytes = await flattenDocument.save();
                  flattenDocument.dispose();
                  debugPrint('✓ 签名扁平化完成并重新保存');
                } catch (e) {
                  debugPrint('⚠ 扁平化签名时出错: $e，使用原始保存结果');
                }
              }
            } catch (e) {
              debugPrint('⚠ 检查签名时出错: $e');
            }
          }
        } catch (e, stackTrace) {
          debugPrint('⚠ 使用 PdfViewerController.saveDocument() 失败: $e');
          debugPrint('堆栈跟踪: $stackTrace');
          
          // 如果 PdfViewerController.saveDocument() 失败，回退到手动复制字段值的方法
          if (_currentDocument != null && _chineseFontBytes != null && _originalPdfBytes != null) {
            try {
              debugPrint('回退到手动复制字段值的方法...');
              // 从原始 PDF 字节重新创建文档
              final PdfDocument saveDocument = PdfDocument(inputBytes: _originalPdfBytes!);

              // 从 viewer 文档中获取表单字段的值
              final PdfForm viewerForm = _currentDocument!.form;
              final PdfForm saveForm = saveDocument.form;
              
              // 在循环外创建字体对象（在新文档上下文中），避免重复创建
              final font = _createChineseFont();
              
              // 复制表单字段的值（通过字段名称匹配）
              for (int i = 0; i < viewerForm.fields.count; i++) {
                final PdfField viewerField = viewerForm.fields[i];
                final String? fieldName = viewerField.name;
                
                if (fieldName == null) continue;
                
                // 在保存文档中查找同名字段
                PdfField? saveField;
                for (int j = 0; j < saveForm.fields.count; j++) {
                  if (saveForm.fields[j].name == fieldName) {
                    saveField = saveForm.fields[j];
                    break;
                  }
                }
                
                if (saveField == null) {
                  debugPrint('⚠ 未找到保存文档中的字段: $fieldName');
                  continue;
                }
                
                try {
                  if (viewerField is PdfTextBoxField && saveField is PdfTextBoxField) {
                    saveField.text = viewerField.text;
                    if (font != null) {
                      saveField.font = font;
                    }
                  } else if (viewerField is PdfComboBoxField && saveField is PdfComboBoxField) {
                    saveField.selectedValue = viewerField.selectedValue;
                    if (font != null) {
                      saveField.font = font;
                    }
                  } else if (viewerField is PdfListBoxField && saveField is PdfListBoxField) {
                    saveField.selectedValues = viewerField.selectedValues;
                    if (font != null) {
                      saveField.font = font;
                    }
                  } else if (viewerField is PdfCheckBoxField && saveField is PdfCheckBoxField) {
                    saveField.isChecked = viewerField.isChecked;
                  } else if (viewerField is PdfSignatureField && saveField is PdfSignatureField) {
                    // 处理签名字段：尝试复制签名数据
                    try {
                      dynamic viewerFieldDynamic = viewerField;
                      dynamic saveFieldDynamic = saveField;
                      
                      final viewerSignature = viewerFieldDynamic.signature;
                      if (viewerSignature != null) {
                        try {
                          saveFieldDynamic.signature = viewerSignature;
                          debugPrint('✓ 复制签名字段 $fieldName 的签名数据成功');
                          // 扁平化签名字段
                          saveField.flatten();
                          debugPrint('✓ 扁平化签名字段 $fieldName');
                        } catch (e) {
                          debugPrint('⚠ 设置签名字段 $fieldName 失败: $e');
                        }
                      }
                    } catch (e) {
                      debugPrint('⚠ 处理签名字段 $fieldName 时出错: $e');
                    }
                  }
                } catch (e) {
                  debugPrint('复制字段 $fieldName 的值失败: $e');
                }
              }
              
              // 保存文档
              savedBytes = await saveDocument.save();
              saveDocument.dispose();
              debugPrint('✓ 手动复制字段值保存成功');
            } catch (e2, stackTrace2) {
              debugPrint('⚠ 手动复制字段值也失败: $e2');
              debugPrint('堆栈跟踪: $stackTrace2');
              // 如果还是失败，使用原始 PDF 字节（会丢失表单数据和签名）
              savedBytes = _originalPdfBytes!.toList();
              debugPrint('⚠ 回退到使用原始 PDF 字节（可能丢失表单数据和签名）');
            }
          } else {
            // 如果没有文档引用或中文字体，使用原始 PDF 字节
            savedBytes = _originalPdfBytes!.toList();
            debugPrint('⚠ 使用原始 PDF 字节（可能丢失表单数据和签名）');
          }
        }
      } else {
        // 如果 PdfViewerController 不可用，回退到手动复制字段值的方法
        debugPrint('⚠ PdfViewerController 不可用，使用手动复制字段值的方法');
        if (_currentDocument != null && _chineseFontBytes != null && _originalPdfBytes != null) {
          try {
            final PdfDocument saveDocument = PdfDocument(inputBytes: _originalPdfBytes!);
            final PdfForm viewerForm = _currentDocument!.form;
            final PdfForm saveForm = saveDocument.form;
            final font = _createChineseFont();
            
            for (int i = 0; i < viewerForm.fields.count; i++) {
              final PdfField viewerField = viewerForm.fields[i];
              final String? fieldName = viewerField.name;
              if (fieldName == null) continue;
              
              PdfField? saveField;
              for (int j = 0; j < saveForm.fields.count; j++) {
                if (saveForm.fields[j].name == fieldName) {
                  saveField = saveForm.fields[j];
                  break;
                }
              }
              
              if (saveField == null) continue;
              
              try {
                if (viewerField is PdfTextBoxField && saveField is PdfTextBoxField) {
                  saveField.text = viewerField.text;
                  if (font != null) saveField.font = font;
                } else if (viewerField is PdfComboBoxField && saveField is PdfComboBoxField) {
                  saveField.selectedValue = viewerField.selectedValue;
                  if (font != null) saveField.font = font;
                } else if (viewerField is PdfListBoxField && saveField is PdfListBoxField) {
                  saveField.selectedValues = viewerField.selectedValues;
                  if (font != null) saveField.font = font;
                } else if (viewerField is PdfCheckBoxField && saveField is PdfCheckBoxField) {
                  saveField.isChecked = viewerField.isChecked;
                } else if (viewerField is PdfSignatureField && saveField is PdfSignatureField) {
                  try {
                    dynamic viewerFieldDynamic = viewerField;
                    dynamic saveFieldDynamic = saveField;
                    final viewerSignature = viewerFieldDynamic.signature;
                    if (viewerSignature != null) {
                      saveFieldDynamic.signature = viewerSignature;
                      saveField.flatten();
                    }
                  } catch (e) {
                    debugPrint('⚠ 处理签名字段 $fieldName 时出错: $e');
                  }
                }
              } catch (e) {
                debugPrint('复制字段 $fieldName 的值失败: $e');
              }
            }
            
            savedBytes = await saveDocument.save();
            saveDocument.dispose();
          } catch (e) {
            savedBytes = _originalPdfBytes!.toList();
          }
        } else {
          savedBytes = _originalPdfBytes!.toList();
        }
      }

      // 将保存的PDF字节写入文件
      final savedFile = File(savedFilePath);
      await savedFile.writeAsBytes(savedBytes);

      // 4. 保存到数据库
      final accountFile = CustomerAccountFile(
        accountFileUid: widget.accountFileUid!,
        customerUid: widget.customerUid!,
        accountFileName: widget.fileName!,
        fileVersion: newFileVersion,
        filePath: savedFilePath,
        templateName: widget.templateName,
        templateSignCode: widget.templateSignCode,
        fileSrcType: widget.fileSrcType ?? '模板生成',
        createBy: loginUser?.userName,
        createTime: now,
        updateBy: loginUser?.userName,
        updateTime: now,
      );

      await _repository.addAccountFile(accountFile);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('开户文件保存成功')),
      );

      // 保存成功后返回上一页
      Navigator.of(context).pop(true); // 传递 true 表示保存成功，可以用于刷新列表
    } catch (e, stackTrace) {
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
      debugPrint('保存PDF失败: $e');
    }
  }

  /// 在新文档上下文中创建字体对象
  /// 这很重要，因为字体对象必须绑定到正确的文档上下文才能正确保存
  PdfTrueTypeFont? _createChineseFont() {
    if (_chineseFontBytes == null) {
      debugPrint('⚠ 警告: 字体字节数据为空，无法创建字体对象');
      return _chineseFont;
    }
    
    try {
      // 在文档上下文中重新创建字体对象（避免 _tableDirectory 不存在的问题）
      PdfTrueTypeFont documentFont = PdfTrueTypeFont(
        List<int>.from(_chineseFontBytes!),
        10, // 使用与原始字体相同的大小
      );
      return documentFont;
    } catch (e) {
      debugPrint('⚠ 警告: 重新创建字体对象失败: $e，使用原始字体对象');
      return _chineseFont;
    }
  }

  /// 打印所有表单域的所有属性
  void _printAllFormFieldsProperties(PdfDocument document) {
    try {
      final PdfForm form = document.form;
      if (form.fields.count == 0) {
        debugPrint('═══════════════════════════════════════════════════════');
        debugPrint('📋 PDF表单字段信息: PDF中没有表单字段');
        debugPrint('═══════════════════════════════════════════════════════');
        return;
      }

      debugPrint('═══════════════════════════════════════════════════════');
      debugPrint('📋 PDF表单字段信息: 共 ${form.fields.count} 个字段');
      debugPrint('═══════════════════════════════════════════════════════');

      for (int i = 0; i < form.fields.count; i++) {
        final PdfField field = form.fields[i];
        final String fieldName = field.name ?? '未知字段$i';
        final String fieldType = field.runtimeType.toString();

        debugPrint('');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        debugPrint('字段 #${i + 1}: $fieldName');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

        // 公共属性
        try {
          debugPrint('  📝 字段名称 (name): ${field.name}');
        } catch (e) {
          debugPrint('  📝 字段名称 (name): 访问失败 - $e');
        }

        try {
          debugPrint('  📦 字段类型 (runtimeType): $fieldType');
        } catch (e) {
          debugPrint('  📦 字段类型 (runtimeType): 访问失败 - $e');
        }

        try {
          final bounds = field.bounds;
          debugPrint('  📐 边界信息 (bounds):');
          debugPrint('    - left: ${bounds.left}');
          debugPrint('    - top: ${bounds.top}');
          debugPrint('    - right: ${bounds.right}');
          debugPrint('    - bottom: ${bounds.bottom}');
          debugPrint('    - width: ${bounds.width}');
          debugPrint('    - height: ${bounds.height}');
        } catch (e) {
          debugPrint('  📐 边界信息 (bounds): 访问失败 - $e');
        }

        try {
          debugPrint('  🔒 是否只读 (readOnly): ${field.readOnly}');
        } catch (e) {
          debugPrint('  🔒 是否只读 (readOnly): 访问失败 - $e');
        }

        // 尝试通过 dynamic 访问可能存在的属性
        try {
          dynamic fieldDynamic = field;
          try {
            if (fieldDynamic.backgroundColor != null) {
              debugPrint('  🎨 背景色 (backgroundColor): ${fieldDynamic.backgroundColor}');
            }
          } catch (e) {}

          try {
            if (fieldDynamic.borderColor != null) {
              debugPrint('  ✏️  边框色 (borderColor): ${fieldDynamic.borderColor}');
            }
          } catch (e) {}

          try {
            if (fieldDynamic.borderWidth != null) {
              debugPrint('  📏 边框宽度 (borderWidth): ${fieldDynamic.borderWidth}');
            }
          } catch (e) {}

          try {
            if (fieldDynamic.borderStyle != null) {
              debugPrint('  🔠 边框样式 (borderStyle): ${fieldDynamic.borderStyle}');
            }
          } catch (e) {}

          try {
            if (fieldDynamic.toolTip != null) {
              debugPrint('  📄 工具提示 (toolTip): ${fieldDynamic.toolTip}');
            }
          } catch (e) {}

          try {
            if (fieldDynamic.visible != null) {
              debugPrint('  👁️  是否可见 (visible): ${fieldDynamic.visible}');
            }
          } catch (e) {}
        } catch (e) {}

        try {
          debugPrint('  📋 toString(): ${field.toString()}');
        } catch (e) {
          debugPrint('  📋 toString(): 访问失败 - $e');
        }

        // 特定类型的属性
        if (field is PdfTextBoxField) {
          debugPrint('  ───────────────────────────────────────────────────');
          debugPrint('  📝 TextBox 特定属性:');
          try {
            final textValue = field.text;
            debugPrint('    - 当前表单值 (text): ${textValue ?? "(空)"}');
            if (textValue != null && textValue.isNotEmpty) {
              debugPrint('    - 当前表单值长度: ${textValue.length} 字符');
              debugPrint('    - 当前表单值内容: "$textValue"');
            } else {
              debugPrint('    - 当前表单值: (空字符串)');
            }
          } catch (e) {
            debugPrint('    - 当前表单值 (text): 访问失败 - $e');
          }

          try {
            debugPrint('    - 最大长度 (maxLength): ${field.maxLength}');
          } catch (e) {
            debugPrint('    - 最大长度 (maxLength): 访问失败 - $e');
          }

          try {
            debugPrint('    - 多行 (multiline): ${field.multiline}');
          } catch (e) {
            debugPrint('    - 多行 (multiline): 访问失败 - $e');
          }

          // 尝试通过 dynamic 访问可能存在的属性
          try {
            dynamic fieldDynamic = field;
            try {
              if (fieldDynamic.defaultText != null) {
                debugPrint('    - 默认文本 (defaultText): ${fieldDynamic.defaultText}');
              }
            } catch (e) {}

            try {
              if (fieldDynamic.password != null) {
                debugPrint('    - 密码 (password): ${fieldDynamic.password}');
              }
            } catch (e) {}

            try {
              if (fieldDynamic.textAlign != null) {
                debugPrint('    - 文本对齐 (textAlign): ${fieldDynamic.textAlign}');
              }
            } catch (e) {}

            try {
              if (fieldDynamic.textColor != null) {
                debugPrint('    - 文本颜色 (textColor): ${fieldDynamic.textColor}');
              }
            } catch (e) {}
          } catch (e) {}

          try {
            final font = field.font;
            if (font != null) {
              debugPrint('    - 字体 (font):');
              try {
                debugPrint('      - 字体名称: ${font.name}');
              } catch (e) {}
              try {
                debugPrint('      - 字体大小: ${font.size}');
              } catch (e) {}
              try {
                debugPrint('      - 字体样式: ${font.style}');
              } catch (e) {}
            } else {
              debugPrint('    - 字体 (font): null');
            }
          } catch (e) {
            debugPrint('    - 字体 (font): 访问失败 - $e');
          }
        } else if (field is PdfComboBoxField) {
          debugPrint('  ───────────────────────────────────────────────────');
          debugPrint('  📋 ComboBox 特定属性:');
          try {
            debugPrint('    - 选中值 (selectedValue): ${field.selectedValue}');
          } catch (e) {
            debugPrint('    - 选中值 (selectedValue): 访问失败 - $e');
          }

          try {
            debugPrint('    - 选中索引 (selectedIndex): ${field.selectedIndex}');
          } catch (e) {
            debugPrint('    - 选中索引 (selectedIndex): 访问失败 - $e');
          }

          try {
            final items = field.items;
            debugPrint('    - 选项列表 (items): 共 ${items.count} 项');
            for (int j = 0; j < items.count; j++) {
              try {
                debugPrint('      [${j}] ${items[j]}');
              } catch (e) {
                debugPrint('      [${j}] 访问失败 - $e');
              }
            }
          } catch (e) {
            debugPrint('    - 选项列表 (items): 访问失败 - $e');
          }

          try {
            final font = field.font;
            if (font != null) {
              debugPrint('    - 字体 (font):');
              try {
                debugPrint('      - 字体名称: ${font.name}');
              } catch (e) {}
              try {
                debugPrint('      - 字体大小: ${font.size}');
              } catch (e) {}
              try {
                debugPrint('      - 字体样式: ${font.style}');
              } catch (e) {}
            } else {
              debugPrint('    - 字体 (font): null');
            }
          } catch (e) {
            debugPrint('    - 字体 (font): 访问失败 - $e');
          }

          // 尝试通过 dynamic 访问可能存在的属性
          try {
            dynamic fieldDynamic = field;
            try {
              if (fieldDynamic.textColor != null) {
                debugPrint('    - 文本颜色 (textColor): ${fieldDynamic.textColor}');
              }
            } catch (e) {}
          } catch (e) {}
        } else if (field is PdfListBoxField) {
          debugPrint('  ───────────────────────────────────────────────────');
          debugPrint('  📋 ListBox 特定属性:');
          try {
            final selectedValues = field.selectedValues;
            debugPrint('    - 选中值列表 (selectedValues): 共 ${selectedValues.length} 项');
            for (int j = 0; j < selectedValues.length; j++) {
              debugPrint('      [${j}] ${selectedValues[j]}');
            }
          } catch (e) {
            debugPrint('    - 选中值列表 (selectedValues): 访问失败 - $e');
          }

          try {
            final items = field.items;
            debugPrint('    - 选项列表 (items): 共 ${items.count} 项');
            for (int j = 0; j < items.count; j++) {
              try {
                debugPrint('      [${j}] ${items[j]}');
              } catch (e) {
                debugPrint('      [${j}] 访问失败 - $e');
              }
            }
          } catch (e) {
            debugPrint('    - 选项列表 (items): 访问失败 - $e');
          }

          try {
            debugPrint('    - 多选 (multiSelect): ${field.multiSelect}');
          } catch (e) {
            debugPrint('    - 多选 (multiSelect): 访问失败 - $e');
          }

          try {
            final font = field.font;
            if (font != null) {
              debugPrint('    - 字体 (font):');
              try {
                debugPrint('      - 字体名称: ${font.name}');
              } catch (e) {}
              try {
                debugPrint('      - 字体大小: ${font.size}');
              } catch (e) {}
              try {
                debugPrint('      - 字体样式: ${font.style}');
              } catch (e) {}
            } else {
              debugPrint('    - 字体 (font): null');
            }
          } catch (e) {
            debugPrint('    - 字体 (font): 访问失败 - $e');
          }

          // 尝试通过 dynamic 访问可能存在的属性
          try {
            dynamic fieldDynamic = field;
            try {
              if (fieldDynamic.textColor != null) {
                debugPrint('    - 文本颜色 (textColor): ${fieldDynamic.textColor}');
              }
            } catch (e) {}
          } catch (e) {}
        } else if (field is PdfCheckBoxField) {
          debugPrint('  ───────────────────────────────────────────────────');
          debugPrint('  ☑️  CheckBox 特定属性:');
          try {
            debugPrint('    - 是否选中 (isChecked): ${field.isChecked}');
          } catch (e) {
            debugPrint('    - 是否选中 (isChecked): 访问失败 - $e');
          }

          // 尝试通过 dynamic 访问可能存在的属性
          try {
            dynamic fieldDynamic = field;
            try {
              if (fieldDynamic.defaultChecked != null) {
                debugPrint('    - 默认选中状态 (defaultChecked): ${fieldDynamic.defaultChecked}');
              }
            } catch (e) {}

            try {
              if (fieldDynamic.checkBoxStyle != null) {
                debugPrint('    - 复选框样式 (checkBoxStyle): ${fieldDynamic.checkBoxStyle}');
              }
            } catch (e) {}
          } catch (e) {}
        } else if (field is PdfRadioButtonListField) {
          debugPrint('  ───────────────────────────────────────────────────');
          debugPrint('  🔘 RadioButtonList 特定属性:');
          try {
            debugPrint('    - 选中索引 (selectedIndex): ${field.selectedIndex}');
          } catch (e) {
            debugPrint('    - 选中索引 (selectedIndex): 访问失败 - $e');
          }

          try {
            final items = field.items;
            debugPrint('    - 选项列表 (items): 共 ${items.count} 项');
            for (int j = 0; j < items.count; j++) {
              try {
                debugPrint('      [${j}] ${items[j]}');
              } catch (e) {
                debugPrint('      [${j}] 访问失败 - $e');
              }
            }
          } catch (e) {
            debugPrint('    - 选项列表 (items): 访问失败 - $e');
          }
        } else if (field is PdfSignatureField) {
          debugPrint('  ───────────────────────────────────────────────────');
          debugPrint('  ✍️  SignatureField 特定属性:');
          
          // 判断是否已经有签名
          try {
            dynamic fieldDynamic = field;
            final signature = fieldDynamic.signature;
            if (signature != null) {
              debugPrint('    - 签名状态: ✅ 已签名');
              try {
                debugPrint('    - 签名对象 (signature): $signature');
                debugPrint('    - 签名对象类型: ${signature.runtimeType}');
              } catch (e) {
                debugPrint('    - 签名对象 (signature): 访问失败 - $e');
              }
            } else {
              debugPrint('    - 签名状态: ❌ 未签名');
            }
          } catch (e) {
            debugPrint('    - 签名状态: ⚠️  无法确定（属性访问失败: $e）');
          }
          
          // 尝试通过 dynamic 访问可能存在的其他属性
          try {
            dynamic fieldDynamic = field;
            try {
              if (fieldDynamic.signerName != null) {
                debugPrint('    - 签名者名称 (signerName): ${fieldDynamic.signerName}');
              }
            } catch (e) {}

            try {
              if (fieldDynamic.reason != null) {
                debugPrint('    - 签名原因 (reason): ${fieldDynamic.reason}');
              }
            } catch (e) {}

            try {
              if (fieldDynamic.location != null) {
                debugPrint('    - 签名位置 (location): ${fieldDynamic.location}');
              }
            } catch (e) {}

            try {
              if (fieldDynamic.date != null) {
                debugPrint('    - 签名日期 (date): ${fieldDynamic.date}');
              }
            } catch (e) {}

            try {
              if (fieldDynamic.contactInfo != null) {
                debugPrint('    - 联系信息 (contactInfo): ${fieldDynamic.contactInfo}');
              }
            } catch (e) {}
          } catch (e) {}
        }

        // 尝试通过 dynamic 访问可能的其他属性
        try {
          dynamic fieldDynamic = field;
          try {
            if (fieldDynamic.page != null) {
              debugPrint('  📄 所在页面 (page): ${fieldDynamic.page}');
            }
          } catch (e) {}

          try {
            if (fieldDynamic.alignment != null) {
              debugPrint('  📐 对齐方式 (alignment): ${fieldDynamic.alignment}');
            }
          } catch (e) {}

          try {
            if (fieldDynamic.required != null) {
              debugPrint('  ⚠️  是否必填 (required): ${fieldDynamic.required}');
            }
          } catch (e) {}
        } catch (e) {
          // 忽略 dynamic 访问错误
        }
      }

      debugPrint('');
      debugPrint('═══════════════════════════════════════════════════════');
      debugPrint('📋 PDF表单字段信息打印完成');
      debugPrint('═══════════════════════════════════════════════════════');
    } catch (e, stackTrace) {
      debugPrint('❌ 打印PDF表单字段信息失败: $e');
      debugPrint('堆栈跟踪: $stackTrace');
    }
  }

  /// 获取字段所在的页面
  PdfPage? _getFieldPage(PdfSignatureField field) {
    try {
      // 尝试通过 dynamic 访问 page 属性
      dynamic fieldDynamic = field;
      final page = fieldDynamic.page;
      if (page != null && page is PdfPage) {
        return page;
      }
      
      // 如果直接访问失败，尝试通过文档查找
      if (_currentDocument != null) {
        // 获取字段的边界和可能的页面索引
        final Rect bounds = field.bounds;
        
        // 遍历所有页面，查找包含该字段边界的页面
        for (int i = 0; i < _currentDocument!.pages.count; i++) {
          final PdfPage currentPage = _currentDocument!.pages[i];
          final Size pageSize = currentPage.size;
          
          // 检查字段边界是否在该页面范围内
          if (bounds.top >= 0 && bounds.top < pageSize.height &&
              bounds.left >= 0 && bounds.left < pageSize.width) {
            return currentPage;
          }
        }
      }
    } catch (e) {
      debugPrint('⚠ 获取字段页面失败: $e');
    }
    return null;
  }

  /// 显示自定义签名对话框（全屏幕的80%大小）
  Future<void> _showCustomSignatureDialog(PdfSignatureField signatureField) async {
    if (_currentDocument == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('文档未加载完成')),
        );
      }
      return;
    }

    // 获取屏幕尺寸
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final double screenWidth = mediaQuery.size.width;
    final double screenHeight = mediaQuery.size.height;
    
    // 计算签名对话框大小（屏幕的80%）
    final double dialogWidth = screenWidth * 0.8;
    final double dialogHeight = screenHeight * 0.8;
    
    // 创建新的签名板控制器
    final GlobalKey<SfSignaturePadState> signaturePadKey = GlobalKey<SfSignaturePadState>();
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: (screenWidth - dialogWidth) / 2,
            vertical: (screenHeight - dialogHeight) / 2,
          ),
          child: Container(
            width: dialogWidth,
            height: dialogHeight,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                // 标题栏
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '手写签名 - ${signatureField.name ?? "签名字段"}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                      ),
                    ],
                  ),
                ),
                
                // 签名区域
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      border: Border.all(color: Colors.grey.shade300, width: 2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: SfSignaturePad(
                      key: signaturePadKey,
                      backgroundColor: Colors.white,
                      strokeColor: Colors.black,
                      minimumStrokeWidth: 3.0,
                      maximumStrokeWidth: 10.0,
                    ),
                  ),
                ),
                
                // 按钮栏
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // 清除按钮
                      ElevatedButton.icon(
                        onPressed: () {
                          signaturePadKey.currentState?.clear();
                        },
                        icon: const Icon(Icons.clear),
                        label: const Text('清除'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      
                      // 取消按钮
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                        },
                        icon: const Icon(Icons.cancel),
                        label: const Text('取消'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      
                      // 保存按钮
                      ElevatedButton.icon(
                        onPressed: () async {
                          try {
                            // 获取签名图像
                            final ui.Image signatureImage = await signaturePadKey.currentState!.toImage(pixelRatio: 2.0);
                            final ByteData? byteData = await signatureImage.toByteData(format: ui.ImageByteFormat.png);
                            
                            if (byteData == null) {
                              throw Exception('无法获取签名图像数据');
                            }
                            
                            // 转换为 Uint8List
                            final Uint8List imageBytes = byteData.buffer.asUint8List();
                            
                            // 创建 PDF 位图图像
                            final PdfBitmap bitmap = PdfBitmap(imageBytes);
                            
                            // 获取签名字段的边界
                            final Rect bounds = signatureField.bounds;
                            
                            // 获取位图的原始尺寸
                            final double imageWidth = bitmap.width.toDouble();
                            final double imageHeight = bitmap.height.toDouble();
                            
                            // 计算缩放比例以适应签名字段的边界，保持宽高比
                            final double scaleX = bounds.width / imageWidth;
                            final double scaleY = bounds.height / imageHeight;
                            final double scale = scaleX < scaleY ? scaleX : scaleY;
                            
                            // 计算缩放后的尺寸
                            final double scaledWidth = imageWidth * scale;
                            final double scaledHeight = imageHeight * scale;
                            
                            // 居中绘制图像的坐标
                            final double x = bounds.left + (bounds.width - scaledWidth) / 2;
                            final double y = bounds.top + (bounds.height - scaledHeight) / 2;
                            
                            // 创建签名对象并设置外观
                            // 根据 Syncfusion 文档，对于 AcroForm 签名字段，可以直接在字段所在的页面绘制图像
                            try {
                              // 方法1: 尝试直接在字段所在的页面绘制图像（推荐方法）
                              try {
                                // 获取字段所在的页面
                                final PdfPage? page = _getFieldPage(signatureField);
                                if (page != null) {
                                  final PdfGraphics graphics = page.graphics;
                                  // 在字段边界内绘制签名图像
                                  graphics.drawImage(
                                    bitmap,
                                    Rect.fromLTWH(
                                      bounds.left,
                                      bounds.top,
                                      bounds.width,
                                      bounds.height,
                                    ),
                                  );
                                  
                                  debugPrint('✓ 通过页面图形绘制签名图像到字段 ${signatureField.name}');
                                  
                                  // 创建签名对象并关联到字段（用于保存时识别）
                                  try {
                                    final PdfSignature pdfSignature = PdfSignature();
                                    signatureField.signature = pdfSignature;
                                    debugPrint('✓ 创建签名对象并关联到字段');
                                  } catch (e) {
                                    debugPrint('⚠ 创建签名对象失败，但图像已绘制: $e');
                                  }
                                } else {
                                  throw Exception('无法获取字段所在的页面');
                                }
                              } catch (e) {
                                debugPrint('⚠ 方法1失败: $e，尝试方法2');
                                
                                // 方法2: 尝试通过 PdfSignature 的外观设置
                                try {
                                  final PdfSignature pdfSignature = PdfSignature();
                                  
                                  // 尝试通过 dynamic 访问 appearance
                                  dynamic pdfSignatureDynamic = pdfSignature;
                                  final appearance = pdfSignatureDynamic.appearance;
                                  if (appearance != null) {
                                    final PdfGraphics graphics = appearance.graphics;
                                    graphics.drawImage(
                                      bitmap,
                                      Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                                    );
                                    signatureField.signature = pdfSignature;
                                    debugPrint('✓ 通过 signature.appearance 设置签名');
                                  } else {
                                    throw Exception('appearance 为 null');
                                  }
                                } catch (e2) {
                                  debugPrint('⚠ 方法2也失败: $e2');
                                  throw Exception('所有设置签名的方法都失败了');
                                }
                              }
                              
                              debugPrint('✓ 签名已保存到字段 ${signatureField.name}');
                              
                              // 关闭对话框
                              Navigator.of(dialogContext).pop();
                              
                              // 刷新 PDF viewer 以显示签名
                              // Syncfusion PDF Viewer 应该能够自动检测签名字段的变化
                              // 但为了确保签名显示，我们触发一个状态更新
                              if (mounted) {
                                setState(() {
                                  // 触发 viewer 刷新
                                  // 通过跳转到当前页面来刷新显示
                                  final currentPage = _pdfViewerController?.pageNumber ?? 1;
                                  _pdfViewerController?.jumpToPage(currentPage);
                                });
                              }
                              
                              // 显示成功提示
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('签名已保存'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            } catch (e) {
                              debugPrint('⚠ 设置签名失败: $e');
                              if (mounted && dialogContext.mounted) {
                                ScaffoldMessenger.of(dialogContext).showSnackBar(
                                  SnackBar(content: Text('保存签名失败: $e')),
                                );
                              }
                            }
                          } catch (e) {
                            debugPrint('⚠ 保存签名时出错: $e');
                            if (mounted && dialogContext.mounted) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(content: Text('保存签名失败: $e')),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('保存'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 在文档加载后为表单字段设置字体
  Future<void> _setFormFieldsFontAfterLoad(PdfDocument document) async {
    if (_chineseFont == null) {
      debugPrint('未加载中文字体，跳过字体设置');
      return;
    }

    try {
      final PdfForm form = document.form;
      if (form.fields.count == 0) {
        debugPrint('PDF中没有表单字段');
        return;
      }

      int fontSetCount = 0;
      int fontSetFailedCount = 0;

      for (int i = 0; i < form.fields.count; i++) {
        final PdfField field = form.fields[i];
        final String fieldName = field.name ?? '未知字段$i';

        try {
          if (field is PdfTextBoxField) {
            try {
              field.font = _chineseFont!;
              fontSetCount++;
              debugPrint('✓ [preview] 为 TextBox 字段 $fieldName 设置字体成功');
            } catch (e) {
              fontSetFailedCount++;
              debugPrint('× [preview] 为 TextBox 字段 $fieldName 设置字体失败: $e');
            }
          } else if (field is PdfComboBoxField) {
            try {
              field.font = _chineseFont!;
              fontSetCount++;
              debugPrint('✓ [preview] 为 ComboBox 字段 $fieldName 设置字体成功');
            } catch (e) {
              fontSetFailedCount++;
              debugPrint('× [preview] 为 ComboBox 字段 $fieldName 设置字体失败: $e');
            }
          } else if (field is PdfListBoxField) {
            try {
              field.font = _chineseFont!;
              fontSetCount++;
              debugPrint('✓ [preview] 为 ListBox 字段 $fieldName 设置字体成功');
            } catch (e) {
              fontSetFailedCount++;
              debugPrint('× [preview] 为 ListBox 字段 $fieldName 设置字体失败: $e');
            }
          }
        } catch (e) {
          fontSetFailedCount++;
          debugPrint('× [preview] 为字段 $fieldName 设置字体失败: $e');
        }
      }

      debugPrint('[preview] 字体设置完成: 成功 $fontSetCount 个, 失败 $fontSetFailedCount 个');
    } catch (e) {
      debugPrint('[preview] 设置表单字段字体失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isEditMode ? '编辑开户文件' : '预览开户文件',
              style: const TextStyle(fontSize: 18),
            ),
            Text(
              widget.fileName ?? widget.templateAssetPath!,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        actions: [
          if (_pdfViewerController != null && _pdfBytes != null) ...[
            // IconButton(
            //   icon: const Icon(Icons.first_page),
            //   tooltip: '第一页',
            //   onPressed: () {
            //     _pdfViewerController!.jumpToPage(1);
            //   },
            // ),
            // IconButton(
            //   icon: const Icon(Icons.last_page),
            //   tooltip: '最后一页',
            //   onPressed: () {
            //     _pdfViewerController!.jumpToPage(
            //       _pdfViewerController!.pageCount,
            //     );
            //   },
            // ),
            // IconButton(
            //   icon: const Icon(Icons.zoom_in),
            //   tooltip: '放大',
            //   onPressed: () {
            //     _pdfViewerController!.zoomLevel += 0.25;
            //   },
            // ),
            // IconButton(
            //   icon: const Icon(Icons.zoom_out),
            //   tooltip: '缩小',
            //   onPressed: () {
            //     if (_pdfViewerController!.zoomLevel > 0.25) {
            //       _pdfViewerController!.zoomLevel -= 0.25;
            //     }
            //   },
            // ),
              // 编辑模式下显示保存按钮
              if (widget.isEditMode)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: ElevatedButton(
                    onPressed: _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 0,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: const Text('保存'),
                  ),
                ),
          ],
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在加载PDF...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(
                fontSize: 16,
                color: Colors.red.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadPdf,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    if (_pdfBytes != null) {
      final bool showInfoBar = widget.customerName != null;

      return Column(
        children: [
          // 顶部信息栏
          if (showInfoBar) Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.person, size: 20, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  '客户：${widget.customerName}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(width: 24),
                Icon(Icons.description, size: 20, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  '模板：${widget.templateName}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
          
          // PDF查看器
          Expanded(
            child: SfPdfViewer.memory(
              _pdfBytes!,
              controller: _pdfViewerController,
              enableDoubleTapZooming: false,
              enableTextSelection: false,
              canShowScrollHead: false,
              canShowScrollStatus: false,
              canShowSignaturePadDialog: true,
              onDocumentLoaded: (PdfDocumentLoadedDetails details) async {
                debugPrint('PDF文档已加载，共 ${details.document.pages.count} 页');
                // 保存文档引用，用于保存时复制表单字段值
                _currentDocument = details.document;
                // 打印所有表单域的所有属性
                _printAllFormFieldsProperties(details.document);
                // 文档加载后，再次为所有表单字段设置中文字体
                await _setFormFieldsFontAfterLoad(details.document);
              },
              onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details)  {
                debugPrint('PDF文档加载出错，error= ${details.error}, description= ${details.description}');
              },
              onPageChanged: (details) {
                debugPrint('当前页面: ${details.newPageNumber}');
              },
            ),
          ),
        ],
      );
    }

    return const Center(
      child: Text('PDF数据为空'),
    );
  }
}

