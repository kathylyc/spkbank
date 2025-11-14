import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../data/models/customer_account_file.dart';
import '../../data/repositories/customer_repository.dart';
import '../../utils/file_manager.dart';
import '../../utils/storage_utils.dart';

/// 开户文件预览页面
class CustomerFilePreviewPage extends StatefulWidget {
  final String customerName;
  final String fileName;
  final String templateName;
  final String? templateAssetPath; // PDF 模板的 asset 路径（可选）
  final String? filePath; // PDF 文件的实际路径（可选，优先使用此路径）
  final bool isEditMode; // 是否为编辑模式
  final String? accountFileUid; // 账户文件 UID（用于保存）
  final String? customerUid; // 客户 UID（用于保存）
  final String? fileVersion; // 文件版本（用于保存）
  final String? fileSrcType; // 文件来源类型（用于保存）

  const CustomerFilePreviewPage({
    super.key,
    required this.customerName,
    required this.fileName,
    required this.templateName,
    this.templateAssetPath,
    this.filePath,
    this.isEditMode = false,
    this.accountFileUid,
    this.customerUid,
    this.fileVersion,
    this.fileSrcType,
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
      List<int> savedBytes;
      
      if (_currentDocument != null && _chineseFontBytes != null && _originalPdfBytes != null) {
        try {
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
                // 使用文档上下文中的字体对象
                if (font != null) {
                  saveField.font = font;
                }
              } else if (viewerField is PdfComboBoxField && saveField is PdfComboBoxField) {
                saveField.selectedValue = viewerField.selectedValue;
                // 使用文档上下文中的字体对象
                if (font != null) {
                  saveField.font = font;
                }
              } else if (viewerField is PdfListBoxField && saveField is PdfListBoxField) {
                saveField.selectedValues = viewerField.selectedValues;
                // 使用文档上下文中的字体对象
                if (font != null) {
                  saveField.font = font;
                }
              } else if (viewerField is PdfCheckBoxField && saveField is PdfCheckBoxField) {
                saveField.isChecked = viewerField.isChecked;
              }
            } catch (e) {
              debugPrint('复制字段 $fieldName 的值失败: $e');
            }
          }
          
          // 保存文档
          savedBytes = await saveDocument.save();
          saveDocument.dispose();
        } catch (e, stackTrace) {
          debugPrint('使用文档对象保存失败: $e');
          debugPrint('堆栈跟踪: $stackTrace');
          // 如果失败，尝试直接使用原始 PDF 字节（可能会丢失表单数据）
          savedBytes = _originalPdfBytes!.toList();
        }
      } else {
        // 如果没有文档引用或中文字体，直接使用原始 PDF 字节
        savedBytes = _originalPdfBytes!.toList();
      }

      // 将保存的PDF字节写入文件
      final savedFile = File(savedFilePath);
      await savedFile.writeAsBytes(savedBytes);

      // 4. 保存到数据库
      final accountFile = CustomerAccountFile(
        accountFileUid: widget.accountFileUid!,
        customerUid: widget.customerUid!,
        accountFileName: widget.fileName,
        fileVersion: newFileVersion,
        filePath: savedFilePath,
        templateName: widget.templateName,
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
              widget.fileName,
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
      return Column(
        children: [
          // 顶部信息栏
          Container(
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
              enableDoubleTapZooming: true,
              enableTextSelection: true,
              canShowScrollHead: true,
              canShowScrollStatus: true,
              onDocumentLoaded: (PdfDocumentLoadedDetails details) async {
                debugPrint('PDF文档已加载，共 ${details.document.pages.count} 页');
                // 保存文档引用，用于保存时复制表单字段值
                _currentDocument = details.document;
                // 文档加载后，再次为所有表单字段设置中文字体
                await _setFormFieldsFontAfterLoad(details.document);
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

