import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui show Image, ImageByteFormat;
import 'package:bank_flutter/utils/snackbar_utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_signaturepad/signaturepad.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import '../../data/models/customer_account_file.dart';
import '../../data/repositories/customer_repository.dart';
import '../../utils/file_manager.dart';
import '../../utils/storage_utils.dart';
import '../../utils/common_const.dart';
import '../../utils/version_utils.dart';

/// 用于在 isolate 中传递表单字段数据的数据类
class FormFieldData {
  final String name;
  final String type; // 'TextBox', 'ComboBox', 'ListBox', 'CheckBox', 'Signature'
  final String? textValue;
  final String? selectedValue;
  final List<String>? selectedValues;
  final bool? isChecked;
  final bool isSignature; // 标识是否为签名字段

  final bool kIsPrintPdfFields = false;

  FormFieldData({
    required this.name,
    required this.type,
    this.textValue,
    this.selectedValue,
    this.selectedValues,
    this.isChecked,
    this.isSignature = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'textValue': textValue,
      'selectedValue': selectedValue,
      'selectedValues': selectedValues,
      'isChecked': isChecked,
      'isSignature': isSignature,
    };
  }

  factory FormFieldData.fromMap(Map<String, dynamic> map) {
    return FormFieldData(
      name: map['name'],
      type: map['type'],
      textValue: map['textValue'],
      selectedValue: map['selectedValue'],
      selectedValues: map['selectedValues']?.cast<String>(),
      isChecked: map['isChecked'],
      isSignature: map['isSignature'] ?? false,
    );
  }
}

/// 用于在 isolate 中传递 PDF 处理数据的数据类
class UnsignedPdfData {
  final Uint8List originalPdfBytes;
  final List<FormFieldData> formFields;
  final List<int>? chineseFontBytes;

  UnsignedPdfData({
    required this.originalPdfBytes,
    required this.formFields,
    this.chineseFontBytes,
  });

  Map<String, dynamic> toMap() {
    return {
      'originalPdfBytes': originalPdfBytes,
      'formFields': formFields.map((f) => f.toMap()).toList(),
      'chineseFontBytes': chineseFontBytes,
    };
  }

  factory UnsignedPdfData.fromMap(Map<String, dynamic> map) {
    return UnsignedPdfData(
      originalPdfBytes: map['originalPdfBytes'],
      formFields: (map['formFields'] as List)
          .map((f) => FormFieldData.fromMap(f))
          .toList(),
      chineseFontBytes: map['chineseFontBytes'],
    );
  }
}

/// PDF扁平化配置枚举
enum PdfFlattenConfig {
  /// 不扁平化任何表单域（默认，保留所有可编辑性）
  none,

  /// 仅扁平化非签名字段，保留签名字段的可编辑性
  nonSignatureOnly,

  /// 仅扁平化已签名的签名字段，保留其他字段可编辑
  signedOnly,

  /// 扁平化所有表单域，生成正式不可修改PDF
  all,
}

/// PdfFlattenConfig扩展方法
extension PdfFlattenConfigExtension on PdfFlattenConfig {
  /// 获取对应的Syncfusion PdfFlattenOption字符串名称
  String get toSyncfusionFlattenOptionName {
    switch (this) {
      case PdfFlattenConfig.none:
        return 'none';
      case PdfFlattenConfig.nonSignatureOnly:
      case PdfFlattenConfig.signedOnly:
      case PdfFlattenConfig.all:
        // 对于需要部分扁平化的情况，我们使用formFields然后手动处理
        return 'formFields';
    }
  }

  /// 是否需要手动处理扁平化逻辑
  bool get requiresCustomFlattening {
    switch (this) {
      case PdfFlattenConfig.none:
        return false;
      case PdfFlattenConfig.all:
        return false; // 使用全部扁平化
      case PdfFlattenConfig.nonSignatureOnly:
      case PdfFlattenConfig.signedOnly:
        return true; // 需要自定义扁平化逻辑
    }
  }
}

/// PDF扁平化配置扩展方法（原有扩展）
extension PdfFlattenConfigDescriptionExtension on PdfFlattenConfig {
  /// 获取配置的中文描述
  String get description {
    switch (this) {
      case PdfFlattenConfig.none:
        return '保存草稿（保留表单可编辑）';
      case PdfFlattenConfig.nonSignatureOnly:
        return '保存（仅保留签名可编辑）';
      case PdfFlattenConfig.signedOnly:
        return '保存（仅扁平化已签名）';
      case PdfFlattenConfig.all:
        return '保存正式文档（全部扁平化）';
    }
  }

  /// 获取配置的简短描述
  String get shortDescription {
    switch (this) {
      case PdfFlattenConfig.none:
        return '草稿保存';
      case PdfFlattenConfig.nonSignatureOnly:
        return '保留签名';
      case PdfFlattenConfig.signedOnly:
        return '扁平化签名';
      case PdfFlattenConfig.all:
        return '正式文档';
    }
  }
}

/// 在 isolate 中生成未签署版本 PDF 的顶级函数
/// 这个函数必须在 isolate 上下文中运行，不能访问类成员变量
Future<List<int>> _createUnsignedPdfBytesInIsolate(UnsignedPdfData data) async {
  try {
    debugPrint('=== [Isolate] 开始生成未签署版本PDF ===');

    // 1. 检查必要的数据
    if (data.originalPdfBytes.isEmpty) {
      throw Exception('原始PDF数据为空');
    }

    // 2. 从原始模板创建新文档
    final PdfDocument unsignedDocument = PdfDocument(inputBytes: data.originalPdfBytes);
    final PdfForm saveForm = unsignedDocument.form;

    // 3. 创建字体（如果提供了字体字节数据）
    PdfTrueTypeFont? font;
    if (data.chineseFontBytes != null && data.chineseFontBytes!.isNotEmpty) {
      try {
        font = PdfTrueTypeFont(data.chineseFontBytes!, 10);
        debugPrint('✓ [Isolate] 成功创建中文字体');
      } catch (e) {
        debugPrint('⚠ [Isolate] 创建中文字体失败: $e');
      }
    }

    int copyCount = 0;
    int skipCount = 0;

    // 4. 复制表单字段值（跳过签名字段）
    for (final fieldData in data.formFields) {
      try {
        // 在保存文档中查找同名字段
        PdfField? saveField;
        for (int j = 0; j < saveForm.fields.count; j++) {
          if (saveForm.fields[j].name == fieldData.name) {
            saveField = saveForm.fields[j];
            break;
          }
        }

        if (saveField == null) {
          debugPrint('⚠ [Isolate] 未找到保存文档中的字段: ${fieldData.name}');
          skipCount++;
          continue;
        }

        // 根据字段类型复制值
        switch (fieldData.type) {
          case 'TextBox':
            if (saveField is PdfTextBoxField) {
              saveField.text = fieldData.textValue ?? '';
              if (font != null) saveField.font = font;
              copyCount++;
            }
            break;
          case 'ComboBox':
            if (saveField is PdfComboBoxField) {
              saveField.selectedValue = fieldData.selectedValue ?? '';
              if (font != null) saveField.font = font;
              copyCount++;
            }
            break;
          case 'ListBox':
            if (saveField is PdfListBoxField) {
              saveField.selectedValues = fieldData.selectedValues ?? [];
              if (font != null) saveField.font = font;
              copyCount++;
            }
            break;
          case 'CheckBox':
            if (saveField is PdfCheckBoxField) {
              saveField.isChecked = fieldData.isChecked ?? false;
              copyCount++;
            }
            break;
          case 'Signature':
            // 跳过签名字段，不复制签名数据
            debugPrint('⏭ [Isolate] 跳过签名字段: ${fieldData.name}');
            skipCount++;
            break;
          default:
            debugPrint('⚠ [Isolate] 不支持的字段类型: ${fieldData.type} - ${fieldData.name}');
            skipCount++;
        }
      } catch (e) {
        debugPrint('⚠ [Isolate] 复制字段 ${fieldData.name} 失败: $e');
        skipCount++;
      }
    }

    // 5. 保存处理后的文档
    final List<int> unsignedBytes = await unsignedDocument.save();
    unsignedDocument.dispose();

    debugPrint('✓ [Isolate] 未签署版本PDF生成完成: 复制了 $copyCount 个非签名字段，跳过 $skipCount 个字段');
    return unsignedBytes;
  } catch (e) {
    debugPrint('⚠ [Isolate] 生成未签署版本PDF失败: $e');
    // 如果生成失败，返回原始模板
    if (data.originalPdfBytes.isNotEmpty) {
      return data.originalPdfBytes.toList();
    } else {
      throw Exception('无法生成未签署版本PDF：缺少原始数据');
    }
  }
}

/// 开户文件预览页面
class CustomerFilePreviewPage extends StatefulWidget {
  final String? customerName;
  final String? fileName;
  final String? templateName;
  final String? templateAssetPath; // PDF 模板的 asset 路径（可选）
  final String? filePath; // PDF 文件的实际路径（可选，优先使用此路径）
  final bool isEditMode; // 是否为编辑模式
  final bool isNewMode; // 是否为新建模式（从开户文件-生成预览 进入）
  final String? accountFileUid; // 账户文件 UID（用于保存）
  final String? customerUid; // 客户 UID（用于保存）
  final int? fileVersion; // 文件版本（用于保存）
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
    this.isNewMode = false,
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

  // 临时文件相关
  String? _tempPdfPath; // 临时PDF文件路径
  File? _currentTempFile; // 当前临时文件引用

  // 字体相关
  PdfTrueTypeFont? _chineseFont;
  List<int>? _chineseFontBytes;

  // Repository
  final CustomerRepository _repository = CustomerRepository();

  // UUID生成器
  static const _uuid = Uuid();

  // 签署状态缓存相关
  bool _isCalcPreviousSignStatus = false;
  int? _cachedPreviousSignStatus;  // 缓存历史签署状态

  // 按钮状态管理
  bool _isProcessing = false;

  bool get kIsPrintPdfFields => false;  // 是否正在处理（保存或上传）

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    _initializePdf();
  }

  @override
  void dispose() {
    try {
      // 清理临时文件
      _cleanupTempFiles();

      // 现有的清理逻辑 - 按顺序释放资源，避免native崩溃
      _pdfViewerController?.dispose();
      _currentDocument?.dispose();

      // 清理字体资源
      _chineseFont = null;
      _chineseFontBytes = null;
    } catch (e) {
      debugPrint('释放PDF资源时出错: $e');
    }
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
          debugPrint('字体文件为空: $fontPath');
          continue;
        }

        final List<int> fontBytes = fontData.buffer.asUint8List();

        if (fontBytes.length < 1000) {
          debugPrint('字体文件太小: $fontPath, 大小: ${fontBytes.length}');
          continue;
        }

        try {
          // 添加额外的字体验证
          if (_isValidFontData(fontBytes)) {
            _chineseFont = PdfTrueTypeFont(fontBytes, 10);
            _chineseFontBytes = List<int>.from(fontBytes);
            debugPrint('✓ 成功加载中文字体: $fontPath, 大小: ${fontBytes.length}');
            return;
          } else {
            debugPrint('字体数据无效: $fontPath');
            continue;
          }
        } catch (e) {
          debugPrint('创建 PdfTrueTypeFont 失败: $e, 字体路径: $fontPath');
          continue;
        }
      } catch (e) {
        debugPrint('加载字体文件失败: $e, 字体路径: $fontPath');
        // 字体文件不存在，尝试下一个
      }
    }

    debugPrint('⚠ 警告: 未找到可用的中文字体文件，将使用默认字体');
    // 不抛出异常，允许使用默认字体
  }

  /// 验证字体数据是否有效
  bool _isValidFontData(List<int> fontBytes) {
    try {
      // 检查基本的字体文件头
      if (fontBytes.length < 4) return false;

      // 检查常见字体格式的魔数
      final firstFourBytes = fontBytes.take(4).toList();

      // TrueType/OpenType字体 (0x00010000 或 'OTTO')
      if (firstFourBytes[0] == 0x00 && firstFourBytes[1] == 0x01 &&
          firstFourBytes[2] == 0x00 && firstFourBytes[3] == 0x00) {
        return true;
      }

      // CFF字体 ('OTTO')
      if (firstFourBytes[0] == 0x4F && firstFourBytes[1] == 0x54 &&
          firstFourBytes[2] == 0x54 && firstFourBytes[3] == 0x4F) {
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('验证字体数据时出错: $e');
      return false;
    }
  }

  /// 加载PDF文件
  Future<void> _loadPdf({Uint8List? forceBytes}) async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      Uint8List bytes;

      if (forceBytes != null) {
        // 重新加载pdf时使用
        bytes = forceBytes;
      }
      else {
        // 优先使用文件路径加载
        if (widget.filePath != null && widget.filePath!.isNotEmpty) {
          try {
            // 使用FileManager处理相对路径
            final fullPath = await FileManager.getFullPath(widget.filePath!);
            final file = File(fullPath);
            if (await file.exists()) {
              bytes = await file.readAsBytes();
              debugPrint('从文件路径加载PDF成功: ${widget.filePath}');
            } else {
              throw Exception('文件不存在: ${widget.filePath}');
            }
          } catch (e) {
            debugPrint('从文件路径加载PDF失败: $e');
            // 如果文件路径加载失败，尝试使用 asset 路径
            if (widget.templateAssetPath != null &&
                widget.templateAssetPath!.isNotEmpty) {
              final ByteData data = await rootBundle.load(
                  widget.templateAssetPath!);
              bytes = data.buffer.asUint8List();
              debugPrint(
                  '回退到 asset 路径加载PDF: ${widget.templateAssetPath}');
            } else {
              throw Exception('文件路径不存在且未提供 asset 路径');
            }
          }
        } else if (widget.templateAssetPath != null &&
            widget.templateAssetPath!.isNotEmpty) {
          // 使用 asset 路径加载
          final ByteData data = await rootBundle.load(
              widget.templateAssetPath!);
          bytes = data.buffer.asUint8List();
          debugPrint('从 asset 路径加载PDF成功: ${widget.templateAssetPath}');
        } else {
          throw Exception('未提供有效的 PDF 文件路径或 asset 路径');
        }
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

  /// 使用指定扁平化配置保存PDF文件
  /// [flattenConfig] 扁平化配置，默认为不扁平化
  /// 返回保存后的PDF字节数据
  Future<List<int>> _savePdfWithFlattenConfig({
    PdfFlattenConfig flattenConfig = PdfFlattenConfig.none,
  }) async {
    debugPrint('=== 开始保存PDF，扁平化配置: ${flattenConfig.description} ===');

    List<int> savedBytes;

    // 优先使用 PdfViewerController.saveDocument() 保存，这样可以确保手写签名正确保存
    if (_pdfViewerController != null) {
      try {
        // 设置正确的扁平化选项
        if (flattenConfig.requiresCustomFlattening) {
          // 对于需要自定义扁平化的配置，先不扁平化保存，然后手动处理
          debugPrint('使用 PdfViewerController.saveDocument() 保存（先保留表单域，后续手动扁平化）...');
          savedBytes = await _pdfViewerController!.saveDocument();
          debugPrint('✓ 使用 PdfViewerController.saveDocument() 保存成功（保留表单域）');
        } else {
          // 对于简单配置，直接使用Syncfusion的扁平化选项
          debugPrint('使用 PdfViewerController.saveDocument() 保存，flattenOption: ${flattenConfig.toSyncfusionFlattenOptionName}...');

          // 根据字符串名称获取对应的枚举值
          PdfFlattenOption flattenOption = PdfFlattenOption.values.firstWhere(
            (option) => option.name == flattenConfig.toSyncfusionFlattenOptionName,
            orElse: () => PdfFlattenOption.none,
          );

          savedBytes = await _pdfViewerController!.saveDocument(
            flattenOption: flattenOption,
          );
          debugPrint('✓ 使用 PdfViewerController.saveDocument() 保存成功（${flattenConfig.description}）');
        }

        // 根据扁平化配置进行后续处理（仅对需要自定义扁平化的配置）
        if (flattenConfig.requiresCustomFlattening) {
          try {
            final PdfDocument flattenDocument = PdfDocument(inputBytes: savedBytes);
            final PdfForm flattenForm = flattenDocument.form;
            int flattenCount = 0;
            int skipCount = 0;

            for (int i = 0; i < flattenForm.fields.count; i++) {
              final PdfField field = flattenForm.fields[i];
              bool shouldFlatten = false;
              String reason = '';

              try {
                if (field is PdfSignatureField) {
                  dynamic fieldDynamic = field;
                  final signature = fieldDynamic.signature;
                  final isSigned = signature != null;

                  switch (flattenConfig) {
                    case PdfFlattenConfig.nonSignatureOnly:
                      shouldFlatten = false; // 不扁平化签名字段
                      reason = '签名字段，配置为不扁平化签名';
                      break;
                    case PdfFlattenConfig.signedOnly:
                      shouldFlatten = isSigned; // 仅扁平化已签名的字段
                      reason = isSigned ? '已签名字段，配置为扁平化已签名' : '未签名字段，配置为跳过未签名';
                      break;
                    case PdfFlattenConfig.all:
                      shouldFlatten = true; // 扁平化所有签名字段（无论是否已签名）
                      reason = isSigned ? '已签名字段，配置为扁平化所有' : '未签名字段，配置为扁平化所有';
                      break;
                    case PdfFlattenConfig.none:
                    default:
                      shouldFlatten = false;
                      reason = '配置为不扁平化';
                      break;
                  }
                } else {
                  // 非签名字段
                  switch (flattenConfig) {
                    case PdfFlattenConfig.nonSignatureOnly:
                    case PdfFlattenConfig.all:
                      shouldFlatten = true;
                      reason = '非签名字段，配置为扁平化';
                      break;
                    case PdfFlattenConfig.signedOnly:
                    case PdfFlattenConfig.none:
                    default:
                      shouldFlatten = false;
                      reason = '非签名字段，配置为不扁平化';
                      break;
                  }
                }

                if (shouldFlatten) {
                  try {
                    field.flatten();
                    flattenCount++;
                    debugPrint('✓ 扁平化字段 ${field.name} - $reason');
                  } catch (e) {
                    skipCount++;
                    debugPrint('⚠ 扁平化字段 ${field.name} 失败: $e');
                  }
                } else {
                  skipCount++;
                  debugPrint('⏭ 跳过字段 ${field.name} - $reason');
                }
              } catch (e) {
                skipCount++;
                debugPrint('⚠ 处理字段 ${field.name} 时出错: $e');
              }
            }

            // 重新保存处理后的文档
            savedBytes = await flattenDocument.save();
            flattenDocument.dispose();

            debugPrint('✓ PDF扁平化完成: 扁平化 $flattenCount 个字段，跳过 $skipCount 个字段');
          } catch (e) {
            debugPrint('⚠ 扁平化PDF时出错: $e，使用原始保存结果');
          }
        }

        debugPrint('=== PDF保存完成 ===');
        return savedBytes;
      } catch (e, stackTrace) {
        debugPrint('⚠ 使用 PdfViewerController.saveDocument() 失败: $e');
        debugPrint('堆栈跟踪: $stackTrace');
      }
    }

    // 如果 PdfViewerController.saveDocument() 失败，回退到手动复制字段值的方法
    debugPrint('回退到手动复制字段值的方法...');
    if (_currentDocument != null && _chineseFontBytes != null && _originalPdfBytes != null) {
      try {
        // 从原始 PDF 字节重新创建文档
        final PdfDocument saveDocument = PdfDocument(inputBytes: _originalPdfBytes!);

        // 从 viewer 文档中获取表单字段的值
        final PdfForm viewerForm = _currentDocument!.form;
        final PdfForm saveForm = saveDocument.form;

        // 在循环外创建字体对象（在新文档上下文中），避免重复创建
        final font = _createChineseFont();

        int copyCount = 0;
        int flattenCount = 0;

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

          bool shouldFlatten = false;
          String reason = '';

          try {
            if (viewerField is PdfTextBoxField && saveField is PdfTextBoxField) {
              saveField.text = viewerField.text;
              if (font != null) {
                saveField.font = font;
              }
              copyCount++;

              // 根据扁平化配置决定是否扁平化
              if (flattenConfig == PdfFlattenConfig.nonSignatureOnly ||
                  flattenConfig == PdfFlattenConfig.all) {
                shouldFlatten = true;
                reason = '文本字段，配置要求扁平化';
              }
            } else if (viewerField is PdfComboBoxField && saveField is PdfComboBoxField) {
              saveField.selectedValue = viewerField.selectedValue;
              if (font != null) {
                saveField.font = font;
              }
              copyCount++;

              if (flattenConfig == PdfFlattenConfig.nonSignatureOnly ||
                  flattenConfig == PdfFlattenConfig.all) {
                shouldFlatten = true;
                reason = '下拉字段，配置要求扁平化';
              }
            } else if (viewerField is PdfListBoxField && saveField is PdfListBoxField) {
              saveField.selectedValues = viewerField.selectedValues;
              if (font != null) {
                saveField.font = font;
              }
              copyCount++;

              if (flattenConfig == PdfFlattenConfig.nonSignatureOnly ||
                  flattenConfig == PdfFlattenConfig.all) {
                shouldFlatten = true;
                reason = '列表字段，配置要求扁平化';
              }
            } else if (viewerField is PdfCheckBoxField && saveField is PdfCheckBoxField) {
              saveField.isChecked = viewerField.isChecked;
              copyCount++;

              if (flattenConfig == PdfFlattenConfig.nonSignatureOnly ||
                  flattenConfig == PdfFlattenConfig.all) {
                shouldFlatten = true;
                reason = '复选框字段，配置要求扁平化';
              }
            } else if (viewerField is PdfSignatureField && saveField is PdfSignatureField) {
              // 处理签名字段：尝试复制签名数据
              try {
                dynamic viewerFieldDynamic = viewerField;
                dynamic saveFieldDynamic = saveField;

                final viewerSignature = viewerFieldDynamic.signature;
                if (viewerSignature != null) {
                  saveFieldDynamic.signature = viewerSignature;
                  copyCount++;
                  debugPrint('✓ 复制签名字段 $fieldName 的签名数据成功');

                  // 根据扁平化配置决定是否扁平化签名字段
                  switch (flattenConfig) {
                    case PdfFlattenConfig.signedOnly:
                    case PdfFlattenConfig.all:
                      shouldFlatten = true;
                      reason = '已签名字段，配置要求扁平化';
                      break;
                    case PdfFlattenConfig.nonSignatureOnly:
                    case PdfFlattenConfig.none:
                    default:
                      shouldFlatten = false;
                      reason = '已签名字段，配置要求保留可编辑性';
                      break;
                  }
                } else {
                  debugPrint('⏭ 签名字段 $fieldName 未签名，跳过');
                }
              } catch (e) {
                debugPrint('⚠ 处理签名字段 $fieldName 时出错: $e');
              }
            }

            // 执行扁平化（如果需要）
            if (shouldFlatten) {
              try {
                saveField.flatten();
                flattenCount++;
                debugPrint('✓ 扁平化字段 $fieldName - $reason');
              } catch (e) {
                debugPrint('⚠ 扁平化字段 $fieldName 失败: $e');
              }
            }
          } catch (e) {
            debugPrint('复制字段 $fieldName 的值失败: $e');
          }
        }

        // 保存文档
        savedBytes = await saveDocument.save();
        saveDocument.dispose();

        debugPrint('✓ 手动复制字段值保存成功: 复制 $copyCount 个字段，扁平化 $flattenCount 个字段');
        return savedBytes;
      } catch (e2, stackTrace2) {
        debugPrint('⚠ 手动复制字段值也失败: $e2');
        debugPrint('堆栈跟踪: $stackTrace2');
      }
    }

    // 如果所有方法都失败，使用原始 PDF 字节（会丢失表单数据和签名）
    if (_originalPdfBytes != null) {
      debugPrint('⚠ 使用原始 PDF 字节（可能丢失表单数据和签名）');
      return _originalPdfBytes!.toList();
    } else {
      throw Exception('无法保存PDF：缺少原始数据');
    }
  }

  /// 计算文档签署状态
  Future<int?> _calculateSigningStatus() async {
    try {
      // 1. 获取当前文档的signCode
      final currentSignCode = widget.templateSignCode;
      if (currentSignCode == null || currentSignCode.isEmpty) {
        debugPrint('⚠ 无法计算签署状态：signCode为空');
        return 0;
      }

      debugPrint('🔍 开始计算签署状态，当前signCode: $currentSignCode');

      // 2. 在ConstPdfTemplateMap中查找匹配的模板
      PdfTemplateInfo? matchingTemplate;
      for (final entry in ConstPdfTemplateMap.entries) {
        if (entry.value.signCode == currentSignCode) {
          matchingTemplate = entry.value;
          debugPrint('📋 找到匹配模板: ID=${entry.key}, signCode=${entry.value.signCode}');
          break;
        }
      }

      if (matchingTemplate == null) {
        debugPrint('⚠ 无法计算签署状态：未找到匹配的模板，signCode=$currentSignCode');
        return 0;
      }

      // 3. 从模板获取期望的签名字段
      final expectedSignFields = matchingTemplate.signFields;
      if (expectedSignFields == null || expectedSignFields.isEmpty) {
        debugPrint('ℹ 模板未定义签名字段，视为无需签署，sign_status=1');
        return 0; // 无签名域，视为未签署
      }

      debugPrint('📝 期望签名数量: ${expectedSignFields.length} 个');

      // 4. 检查当前文档中的实际签名字段
      if (_currentDocument == null) {
        debugPrint('⚠ 无法计算签署状态：当前文档为空');
        return 0;
      }

      final pdfForm = _currentDocument!.form;

      // 获取文档中所有的签名字段
      List<PdfSignatureField> signatureFields = [];
      for (int i = 0; i < pdfForm.fields.count; i++) {
        final field = pdfForm.fields[i];
        if (field is PdfSignatureField) {
          signatureFields.add(field);
        }
      }

      int signedFieldCount = 0;
      for (int i = 0; i < expectedSignFields.length; i++) {
        final fieldName = expectedSignFields[i];

        bool isSigned = false;
        bool isFoundField = false;

        for (int j = 0; j < signatureFields.length; j++) {
          final field = signatureFields[j];
          debugPrint('遍历签名域：i=${i}, fieldName=${fieldName}, j=${j}, field.name=${field.name}, isFoundField=${field.name == fieldName}');
          if (field.name == fieldName) {
            isFoundField = true;

            dynamic fieldDynamic = field;
            final signature = fieldDynamic.signature;
            if (signature != null && signature.isNotEmpty) {
              isSigned = true;debugPrint('遍历签名域：isSigned=true');
              break;
            }
          }
        }

        if (isFoundField) {
          if (isSigned) {
            signedFieldCount++;
          }
        } else {
          // 字段未找到，说明是当前文档之前已经签过了一个字段的签名，视为成功
          signedFieldCount++;
        }
      }
      // 5. 确定签署状态，已签的数量==常量定义的签名域的数量，视为已签署
      if (signedFieldCount == expectedSignFields.length) {
        debugPrint('===已签名');
        return 1;
      } else {
        debugPrint('===未签名');
        return 0;
      }
    } catch (e) {
      debugPrint('💥 计算签署状态时发生异常: $e');
      return 0; // 异常情况下返回未签署状态
    }
  }

  /// 保存PDF文件（支持选择扁平化配置）
  Future<void> _handleSave({PdfFlattenConfig flattenConfig = PdfFlattenConfig.none}) async {
    // 防止重复操作
    if (_isProcessing) return;

    // 设置处理状态，禁用按钮
    setState(() {
      _isProcessing = true;
    });

    await Future.delayed(const Duration(seconds: 1));

    // 验证必要参数
    String? targetAccountFileUid = widget.accountFileUid;
    String? targetCustomerUid = widget.customerUid;
    if (widget.isNewMode) {
      // 1. 判断当前表中是否存在使用了当前选中模板的数据
      final existingFile = await _repository.findLatestByCustomerUidAndTemplate(
        targetCustomerUid!,
        widget.templateName!,
      );

      if (existingFile != null) {
        // 如果存在，先做一个Dialog确认，如果用户点击确定，则继续往下走，否则退出该流程；Dialog的空白区域不可关闭
        final shouldContinue = await showDialog<bool>(
          context: context,
          barrierDismissible: false, // Dialog的空白区域不可关闭
          builder: (context) => AlertDialog(
            title: const Text('提示'),
            content: const Text('该开户文件已存在，是否生成最新版本？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.blue),
                child: const Text('确定'),
              ),
            ],
          ),
        );

        // 如果用户取消或点击取消，退出该流程
        if (shouldContinue != true) {
          // 设置处理状态，禁用按钮
          setState(() {
            _isProcessing = false;
          });
          return;
        }

        // 如果存在，使用现有的 account_file_uid，查询该 account_file_uid 的最大版本号并加一
        targetAccountFileUid = existingFile.accountFileUid;
      } else {
        // 如果不存在，使用 UUID 生成 account_file_uid，file_version 设为 1
        targetAccountFileUid = _uuid.v4().replaceAll('-', '');
      }
    }


    if (targetAccountFileUid == null ||
        targetCustomerUid == null ||
        _originalPdfBytes == null) {
      if (mounted) {
        SnackbarUtils.error('无法保存：缺少必要的信息', context);
      }
      return;
    }

    try {
      // 显示保存提示
      if (mounted) {
        SnackbarUtils.normal('正在保存开户文件...', context);
      }

      // 获取登录用户
      final loginUser = await StorageUtils.getLoginUser();
      final now = DateTime.now();

      // 1. 查询该 account_file_uid 的最大版本号并加一
      int newFileVersion;
      final maxVersion = await _repository.findMaxVersionByAccountFileUid(targetAccountFileUid);
      if (maxVersion != null) {
        newFileVersion = VersionUtils.incrementMajorIntVersion(maxVersion);
      } else {
        newFileVersion = VersionUtils.baseVersion;
      }

      // 2. 构建目标文件路径
      // 使用 FileManager 的方式构建路径，但我们需要先创建一个临时文件
      final tempDir = await getTemporaryDirectory();
      final tempOriginalPath = '${tempDir.path}/temp_original_$targetAccountFileUid.pdf';
      final tempOriginalFile = File(tempOriginalPath);
      await tempOriginalFile.writeAsBytes(_originalPdfBytes!);

      // 使用 FileManager 创建目标路径（它会复制文件）
      final savedFilePath = await FileManager.saveAccountFileWithName(
        sourcePath: tempOriginalPath,
        accountFileUid: targetAccountFileUid,
        fileVersion: newFileVersion,
      );

      // 清理临时文件
      if (await tempOriginalFile.exists()) {
        await tempOriginalFile.delete();
      }

      // 3. 将页面上的表单数据保存到新的PDF中
      // 使用传入的扁平化配置
      final List<int> savedBytes = await _savePdfWithFlattenConfig(
        flattenConfig: flattenConfig,
      );

      await Future.delayed(const Duration(seconds: 1));

      // 将保存的PDF字节写入文件
      final savedFile = File(await FileManager.getFullPath(savedFilePath));
      await savedFile.writeAsBytes(savedBytes);

      // 0. 检测签署状态变更
      final int? previousSignStatus = _cachedPreviousSignStatus;
      final int? currentSignStatus = await _calculateSigningStatus();
      // 判断是否从未签署变为已签署
      final bool isSigningStatusChanged =
          (previousSignStatus == null || previousSignStatus == 0) &&
              (currentSignStatus == 1);
      debugPrint('📊 签署状态检测: 之前=$previousSignStatus, 当前=$currentSignStatus, 变更=$isSigningStatusChanged');

      // 4. 保存到数据库（已签署版本）
      final accountFile = CustomerAccountFile(
        accountFileUid: targetAccountFileUid,
        customerUid: targetCustomerUid,
        accountFileName: widget.fileName!,
        fileVersion: newFileVersion,
        filePath: savedFilePath,
        signStatus: currentSignStatus,
        templateName: widget.templateName,
        templateSignCode: widget.templateSignCode,
        fileSrcType: widget.fileSrcType ?? '模板生成',
        createBy: loginUser?.userName,
        createTime: now,
        updateBy: loginUser?.userName,
        updateTime: now,
      );

      await _repository.addAccountFile(accountFile);

      // 5. 如果签署状态从未签署变为已签署，创建未签署备份版本
      if (isSigningStatusChanged) {
        debugPrint('🔄 检测到签署状态变更，创建未签署备份版本...');

        try {
          // 创建备份版本号（大版本+1后中版本-1）
          final int backupVersion = VersionUtils.createBackupVersion(newFileVersion);

          // 生成未签署PDF（保留当前用户编辑的表单数据，清除签名）
          final List<int> unsignedBytes = await _createUnsignedPdfBytes();

          // 创建临时文件保存未签署PDF
          final tempDir = await getTemporaryDirectory();
          final tempUnsignedPath = '${tempDir.path}/temp_unsigned_backup_${targetAccountFileUid}_$backupVersion.pdf';
          final tempUnsignedFile = File(tempUnsignedPath);
          await tempUnsignedFile.writeAsBytes(unsignedBytes);

          // 使用临时未签署文件创建备份版本
          final backupFilePath = await FileManager.saveAccountFileWithName(
            sourcePath: tempUnsignedPath,
            accountFileUid: targetAccountFileUid!,
            fileVersion: backupVersion,
          );

          // 清理临时文件
          if (await tempUnsignedFile.exists()) {
            await tempUnsignedFile.delete();
          }

          // 保存备份版本到数据库（signStatus=0）
          final backupAccountFile = CustomerAccountFile(
            accountFileUid: targetAccountFileUid,
            customerUid: targetCustomerUid,
            accountFileName: widget.fileName!,
            fileVersion: backupVersion,
            filePath: backupFilePath,
            signStatus: 0, // 未签署状态
            templateName: widget.templateName,
            templateSignCode: widget.templateSignCode,
            fileSrcType: widget.fileSrcType ?? '模板生成',
            createBy: loginUser?.userName,
            createTime: now,
            updateBy: loginUser?.userName,
            updateTime: now,
          );

          await _repository.addAccountFile(backupAccountFile);

          debugPrint('✓ 未签署备份版本创建成功: ${VersionUtils.intToString(backupVersion)}');
        } catch (e) {
          debugPrint('⚠ 创建未签署备份版本失败: $e');
          // 备份版本创建失败不影响主版本保存
        }
      }

      if (!mounted) return;

      String successMessage = '开户文件保存成功';
      if (isSigningStatusChanged) {
        successMessage += '，已自动创建未签署备份版本';
      }

      SnackbarUtils.success(successMessage, context);

      // 保存成功后返回上一页
      Navigator.of(context).pop(true); // 传递 true 表示保存成功，可以用于刷新列表
    } catch (e, stackTrace) {
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        SnackbarUtils.error('保存失败: $e', context);
      }
      debugPrint('保存PDF失败: $e');
    } finally {
      // 恢复按钮状态
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
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
    if (!kIsPrintPdfFields) {
      return;
    }
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
        SnackbarUtils.normal('文档未加载完成', context);
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
                                SnackbarUtils.success('签名已保存', context);
                              }
                            } catch (e) {
                              debugPrint('⚠ 设置签名失败: $e');
                              if (mounted && dialogContext.mounted) {
                                SnackbarUtils.error('保存签名失败: $e', dialogContext);
                              }
                            }
                          } catch (e) {
                            debugPrint('⚠ 保存签名时出错: $e');
                            if (mounted && dialogContext.mounted) {
                              SnackbarUtils.error('保存签名失败: $e', dialogContext);
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
            // 编辑模式下显示保存选项
            if (widget.isEditMode || widget.isNewMode) ...[
              // // 保存选项菜单
              // Padding(
              //   padding: const EdgeInsets.only(left: 8),
              //   child: PopupMenuButton<PdfFlattenConfig>(
              //     icon: const Icon(Icons.save),
              //     tooltip: '保存选项',
              //     itemBuilder: (BuildContext context) => [
              //       PopupMenuItem<PdfFlattenConfig>(
              //         value: PdfFlattenConfig.none,
              //         child: Row(
              //           children: [
              //             const Icon(Icons.edit_document, size: 16),
              //             const SizedBox(width: 8),
              //             Text(PdfFlattenConfig.none.description),
              //           ],
              //         ),
              //       ),
              //       PopupMenuItem<PdfFlattenConfig>(
              //         value: PdfFlattenConfig.nonSignatureOnly,
              //         child: Row(
              //           children: [
              //             const Icon(Icons.text_snippet, size: 16),
              //             const SizedBox(width: 8),
              //             Text(PdfFlattenConfig.nonSignatureOnly.description),
              //           ],
              //         ),
              //       ),
              //       PopupMenuItem<PdfFlattenConfig>(
              //         value: PdfFlattenConfig.signedOnly,
              //         child: Row(
              //           children: [
              //             const Icon(Icons.draw, size: 16),
              //             const SizedBox(width: 8),
              //             Text(PdfFlattenConfig.signedOnly.description),
              //           ],
              //         ),
              //       ),
              //       PopupMenuItem<PdfFlattenConfig>(
              //         value: PdfFlattenConfig.all,
              //         child: Row(
              //           children: [
              //             const Icon(Icons.picture_as_pdf, size: 16),
              //             const SizedBox(width: 8),
              //             Text(PdfFlattenConfig.all.description),
              //           ],
              //         ),
              //       ),
              //     ],
              //     onSelected: (PdfFlattenConfig config) {
              //       _handleSave(flattenConfig: config);
              //     },
              //   ),
              // ),

              // 上传PDF按钮
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _pickAndValidatePdf,
                  icon: const Icon(Icons.upload, size: 16),
                  label: const Text('上传PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 0,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),

              // 快速保存按钮（默认不扁平化）
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : () => _handleSave(flattenConfig: PdfFlattenConfig.none),
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.save, size: 16),
                  label: const Text('保存'),
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
                ),
              ),
            ],
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
      final bool showInfoBar = widget.customerName != null || widget.fileVersion != null;

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
                if (widget.customerName != null) ...[
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
                  if ( widget.fileVersion != null) ...[
                    const SizedBox(width: 24),
                    Icon(Icons.info, size: 20, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Text(
                      '版本：${VersionUtils.intToString(widget.fileVersion!)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ]
                ],
              ],
            ),
          ),
          
          // PDF查看器
          Expanded(
            child: Builder(
              builder: (context) {
                try {
                  return SfPdfViewer.memory(
                    _pdfBytes!,
                    controller: _pdfViewerController,
                    enableDoubleTapZooming: false,
                    enableTextSelection: false,
                    canShowScrollHead: false,
                    canShowScrollStatus: false,
                    canShowSignaturePadDialog: true,
                    onDocumentLoaded: (PdfDocumentLoadedDetails details) async {
                      try {
                        debugPrint('PDF文档已加载，共 ${details.document.pages.count} 页');
                        // 保存文档引用，用于保存时复制表单字段值
                        _currentDocument = details.document;

                        // 当前签署状态通过PDF表单直接获取，无需数据库查询；仅在首次加载时计算 上一次的签名状态
                        if (!_isCalcPreviousSignStatus) {
                          _cachedPreviousSignStatus = await _calculateSigningStatus();
                          _isCalcPreviousSignStatus = true;
                        }

                        // 打印所有表单域的所有属性
                        _printAllFormFieldsProperties(details.document);
                        // 文档加载后，再次为所有表单字段设置中文字体
                        await _setFormFieldsFontAfterLoad(details.document);
                      } catch (e, stackTrace) {
                        debugPrint('PDF文档加载后处理失败: $e');
                        debugPrint('堆栈跟踪: $stackTrace');
                        // 不抛出异常，允许继续使用PDF查看器
                      }
                    },
                    onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details)  {
                      debugPrint('PDF文档加载出错，error= ${details.error}, description= ${details.description}');
                      // 显示错误提示
                      if (mounted) {
                        SnackbarUtils.error('PDF加载失败: ${details.description}', context);
                      }
                    },
                    onPageChanged: (details) {
                      try {
                        debugPrint('当前页面: ${details.newPageNumber}');
                      } catch (e) {
                        debugPrint('页面变化处理失败: $e');
                      }
                    },
                  );
                } catch (e) {
                  debugPrint('创建PDF查看器失败: $e');
                  // 显示错误界面
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
                          'PDF查看器初始化失败',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.red.shade700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              // 重新创建PDF查看器
                            });
                          },
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  );
                }
              }
            ),
          ),
        ],
      );
    }

    return const Center(
      child: Text('PDF数据为空'),
    );
  }

  /// 选择并验证PDF文件
  Future<void> _pickAndValidatePdf() async {
    try {
      // 1. 文件选择
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final selectedFile = result.files.single;
      final String? filePath = selectedFile.path;

      if (filePath == null || !await File(filePath).exists()) {
        _showValidationDialog(false, '选择的文件不存在');
        return;
      }

      // 2. 显示加载对话框
      _showLoadingDialog('正在验证PDF文件...');

      // 3. 读取PDF并提取signCode
      String? uploadedSignCode = await _extractSignCodeFromPdf(filePath);

      if (uploadedSignCode == null || uploadedSignCode.isEmpty) {
        _hideLoadingDialog();
        _showValidationDialog(false, 'PDF文件中未找到signCode表单域');
        return;
      }

      // 4. 获取当前文件的signCode
      final currentSignCode = widget.templateSignCode;

      if (currentSignCode == null || currentSignCode.isEmpty) {
        _hideLoadingDialog();
        _showValidationDialog(false, '当前预览文件的signCode为空');
        return;
      }

      // 5. 验证signCode一致性
      await Future.delayed(const Duration(milliseconds: 500)); // 用户体验

      if (uploadedSignCode == currentSignCode) {
        try {
          // 1. 复制文件到临时目录
          _tempPdfPath = await FileManager.createTempPdfFileFromSource(filePath);
          _currentTempFile = File(_tempPdfPath!);

          // 2. 重新加载PDF到内存
          await _reloadPdfFromTempFile();

          // 3. 隐藏加载对话框
          _hideLoadingDialog();

          // 4. 显示成功提示
          _showValidationDialog(true, 'PDF文件已成功加载');

        } catch (e) {
          _hideLoadingDialog();
          _showValidationDialog(false, '加载PDF文件失败：$e');
        }
      } else {
        _hideLoadingDialog();
        _showValidationDialog(false, '验证失败：上传文件的signCode与当前文件不一致\n\n上传文件：$uploadedSignCode\n当前文件：$currentSignCode');
      }

    } catch (e) {
      _hideLoadingDialog();
      _showValidationDialog(false, '验证过程中发生错误：$e');
    } finally {

    }
  }

  /// 从PDF文件中提取signCode
  Future<String?> _extractSignCodeFromPdf(String filePath) async {
    try {
      // 使用FileManager处理相对路径
      final fullPath = await FileManager.getFullPath(filePath);
      final pdfFile = File(fullPath);
      final pdfBytes = await pdfFile.readAsBytes();

      final PdfDocument document = PdfDocument(inputBytes: pdfBytes);
      final PdfForm form = document.form;

      for (int i = 0; i < form.fields.count; i++) {
        final PdfField field = form.fields[i];
        if (field.name == 'signCode') {
          if (field is PdfTextBoxField) {
            final result = field.text.trim();
            document.dispose();
            return result;
          } else if (field is PdfComboBoxField) {
            final result = field.selectedValue?.toString().trim();
            document.dispose();
            return result;
          }
        }
      }

      document.dispose();
      return null;
    } catch (e) {
      debugPrint('提取signCode失败: $e');
      return null;
    }
  }

  /// 显示加载对话框
  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Text(message),
            ],
          ),
        ),
      ),
    );
  }

  /// 隐藏加载对话框
  void _hideLoadingDialog() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  /// 显示验证结果对话框
  void _showValidationDialog(bool isSuccess, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isSuccess ? '验证成功' : '验证失败',
          style: TextStyle(
            color: isSuccess ? Colors.green : Colors.red,
          ),
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 从临时文件重新加载PDF
  Future<void> _reloadPdfFromTempFile() async {
    if (_tempPdfPath == null) return;

    try {
      // 读取临时文件到内存
      final tempFile = File(_tempPdfPath!);
      final newPdfBytes = await tempFile.readAsBytes();

      // 重新加载PDF
      await _loadPdf(forceBytes: newPdfBytes);

    } catch (e) {
      setState(() {
        _error = '重新加载PDF失败: $e';
        _isLoading = false;
      });
    }
  }

  /// 清理临时文件
  Future<void> _cleanupTempFiles() async {
    if (_tempPdfPath != null) {
      await FileManager.deleteTempFile(_tempPdfPath!);
      _tempPdfPath = null;
      _currentTempFile = null;
    }
  }

  /// 生成未签署版本的PDF字节数据（原始版本备份）
  /// 从原始模板复制当前表单值，但跳过签名字段
  Future<List<int>> _createUnsignedPdfBytesOriginal() async {
    debugPrint('=== 开始生成未签署版本PDF（原始版本） ===');

    try {
      // 1. 检查必要的数据
      if (_originalPdfBytes == null || _currentDocument == null) {
        throw Exception('缺少原始PDF数据或当前文档');
      }

      // 2. 从原始模板创建新文档
      final PdfDocument unsignedDocument = PdfDocument(inputBytes: _originalPdfBytes!);
      final PdfForm viewerForm = _currentDocument!.form;
      final PdfForm saveForm = unsignedDocument.form;

      // 3. 创建字体
      final font = _createChineseFont();
      int copyCount = 0;

      // 4. 复制表单字段值（跳过签名字段）
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
            if (font != null) saveField.font = font;
            copyCount++;
          } else if (viewerField is PdfComboBoxField && saveField is PdfComboBoxField) {
            saveField.selectedValue = viewerField.selectedValue;
            if (font != null) saveField.font = font;
            copyCount++;
          } else if (viewerField is PdfListBoxField && saveField is PdfListBoxField) {
            saveField.selectedValues = viewerField.selectedValues;
            if (font != null) saveField.font = font;
            copyCount++;
          } else if (viewerField is PdfCheckBoxField && saveField is PdfCheckBoxField) {
            saveField.isChecked = viewerField.isChecked;
            copyCount++;
          } else if (viewerField is PdfSignatureField && saveField is PdfSignatureField) {
            // 跳过签名字段，不复制签名数据
            debugPrint('⚠ 跳过签名字段: $fieldName');
          } else {
            debugPrint('⚠ 不支持的字段类型: $fieldName');
          }
        } catch (e) {
          debugPrint('⚠ 复制字段 $fieldName 失败: $e');
        }
      }

      // 5. 保存处理后的文档
      final List<int> unsignedBytes = await unsignedDocument.save();
      unsignedDocument.dispose();

      debugPrint('✓ 未签署版本PDF生成完成: 复制了 $copyCount 个非签名字段');
      return unsignedBytes;
    } catch (e) {
      debugPrint('⚠ 生成未签署版本PDF失败: $e');
      // 如果生成失败，返回原始模板
      if (_originalPdfBytes != null) {
        return _originalPdfBytes!.toList();
      } else {
        throw Exception('无法生成未签署版本PDF：缺少原始数据');
      }
    }
  }

  /// 生成未签署版本的PDF字节数据（使用Isolate compute版本）
  /// 从原始模板复制当前表单值，但跳过签名字段
  Future<List<int>> _createUnsignedPdfBytes() async {
    debugPrint('=== 开始生成未签署版本PDF（使用Isolate） ===');

    try {
      // 1. 检查必要的数据
      if (_originalPdfBytes == null || _currentDocument == null) {
        throw Exception('缺少原始PDF数据或当前文档');
      }

      // 2. 提取当前文档的表单字段数据
      final PdfForm viewerForm = _currentDocument!.form;
      final List<FormFieldData> formFields = [];

      for (int i = 0; i < viewerForm.fields.count; i++) {
        final PdfField viewerField = viewerForm.fields[i];
        final String? fieldName = viewerField.name;

        if (fieldName == null) continue;

        FormFieldData? fieldData;

        try {
          if (viewerField is PdfTextBoxField) {
            fieldData = FormFieldData(
              name: fieldName,
              type: 'TextBox',
              textValue: viewerField.text,
            );
          } else if (viewerField is PdfComboBoxField) {
            fieldData = FormFieldData(
              name: fieldName,
              type: 'ComboBox',
              selectedValue: viewerField.selectedValue,
            );
          } else if (viewerField is PdfListBoxField) {
            fieldData = FormFieldData(
              name: fieldName,
              type: 'ListBox',
              selectedValues: viewerField.selectedValues.cast<String>(),
            );
          } else if (viewerField is PdfCheckBoxField) {
            fieldData = FormFieldData(
              name: fieldName,
              type: 'CheckBox',
              isChecked: viewerField.isChecked,
            );
          } else if (viewerField is PdfSignatureField) {
            fieldData = FormFieldData(
              name: fieldName,
              type: 'Signature',
              isSignature: true,
            );
          } else {
            debugPrint('⚠ 不支持的字段类型: $fieldName');
            continue;
          }

          formFields.add(fieldData);
        } catch (e) {
          debugPrint('⚠ 提取字段 $fieldName 数据失败: $e');
        }
      }

      // 3. 准备传递给 isolate 的数据
      final data = UnsignedPdfData(
        originalPdfBytes: _originalPdfBytes!,
        formFields: formFields,
        chineseFontBytes: _chineseFontBytes,
      );

      // 4. 使用 compute 在 isolate 中处理 PDF
      debugPrint('🚀 启动 Isolate 处理未签署PDF生成...');
      final List<int> unsignedBytes = await compute(_createUnsignedPdfBytesInIsolate, data);
      debugPrint('✅ Isolate 处理完成');

      return unsignedBytes;
    } catch (e) {
      debugPrint('⚠ 使用 Isolate 生成未签署版本PDF失败: $e');
      // 如果 isolate 处理失败，回退到原始方法
      debugPrint('🔄 回退到原始方法处理...');
      return await _createUnsignedPdfBytesOriginal();
    }
  }
}

