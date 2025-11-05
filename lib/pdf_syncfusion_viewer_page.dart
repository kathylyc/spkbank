import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PdfSyncfusionViewerPage extends StatefulWidget {
  const PdfSyncfusionViewerPage({super.key});

  @override
  State<PdfSyncfusionViewerPage> createState() => _PdfSyncfusionViewerPageState();
}

class _PdfSyncfusionViewerPageState extends State<PdfSyncfusionViewerPage> {
  final String _pdfAssetPath =
      'assets/pdf/Application Form for CorporateAccount_202212_clean (FINAL VERSION).pdf';
  // final String _pdfAssetPath =
  //     'assets/pdf/测试表单.pdf';
  
  PdfViewerController? _pdfViewerController;
  bool _isLoading = true;
  String? _error;
  Uint8List? _pdfBytes;
  PdfTrueTypeFont? _chineseFont;
  PdfDocument? _currentDocument; // 保存当前文档的引用
  List<int>? _chineseFontBytes; // 保存字体字节数据，用于在不同文档中重新创建字体

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    _initializePdf();
  }

  /// 初始化PDF：先加载字体，再加载PDF
  Future<void> _initializePdf() async {
    await _loadChineseFont();
    await _loadPdf();
  }

  /// 加载支持中文的字体
  Future<void> _loadChineseFont() async {
    // 尝试加载不同的字体文件名
    final List<String> fontPaths = [
      'assets/fonts/SourceHanSerifSC-VF.ttf',
      // 'assets/fonts/SourceHanSerifSC-Regular.otf',
      // 'assets/fonts/SourceHanSerifTC-Regular.otf',
      // 'assets/fonts/chinese_font.ttf',
      // 'assets/fonts/SourceHanSansSC-Regular.ttf',
      // 'assets/fonts/SourceHanSansTC-Regular.ttf',
      // 'assets/fonts/NotoSansSC-Regular.ttf',
      // 'assets/fonts/NotoSansSC-Regular.otf',
      // 'assets/fonts/simsun.ttf',
      // 'assets/fonts/SimSun.ttf',
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
          _chineseFontBytes = List<int>.from(fontBytes); // 保存字体字节数据
          debugPrint('✓ 成功加载中文字体: $fontPath');
          // 打印加载的中文字体属性
          _printFontProperties(_chineseFont, '中文字体', 'Loaded');
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

  /// 打印字体对象的所有属性
  void _printFontProperties(PdfFont? font, String fieldName, String fieldType) {
    if (font == null) {
      debugPrint('📝 [viewer] $fieldType 字段 $fieldName 原始字体: null');
      return;
    }

    debugPrint('📝 [viewer] $fieldType 字段 $fieldName 原始字体属性:');
    
    // 打印 toString() 信息
    try {
      debugPrint('  - toString(): ${font.toString()}');
    } catch (e) {
      debugPrint('  - toString(): 访问失败 - $e');
    }

    // 尝试访问常见属性
    try {
      debugPrint('  - name: ${font.name}');
    } catch (e) {
      debugPrint('  - name: 访问失败 - $e');
    }

    try {
      debugPrint('  - size: ${font.size}');
    } catch (e) {
      debugPrint('  - size: 访问失败 - $e');
    }

    try {
      debugPrint('  - height: ${font.height}');
    } catch (e) {
      debugPrint('  - height: 访问失败 - $e');
    }

    try {
      debugPrint('  - style: ${font.style}');
    } catch (e) {
      debugPrint('  - style: 访问失败 - $e');
    }

    // 如果是 PdfStandardFont，尝试访问更多属性
    if (font is PdfStandardFont) {
      try {
        debugPrint('  - (PdfStandardFont) fontFamily: ${font.fontFamily}');
      } catch (e) {
        debugPrint('  - (PdfStandardFont) fontFamily: 访问失败 - $e');
      }
    }
  }

  /// 在文档加载后为表单字段设置字体（在viewer渲染时调用）
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

      // 为所有表单字段设置字体
      for (int i = 0; i < form.fields.count; i++) {
        final PdfField field = form.fields[i];
        final String fieldName = field.name ?? '未知字段$i';

        try {
          if (field is PdfTextBoxField) {
            try {
              // 先打印原始字体信息
              try {
                final originalFont = field.font;
                _printFontProperties(originalFont, fieldName, 'TextBox');
              } catch (e) {
                debugPrint('⚠ [viewer] TextBox 字段 $fieldName 读取原始字体失败: $e');
              }
              
              // 直接设置字体，不读取值（避免触发渲染错误）
              field.font = _chineseFont!;
              fontSetCount++;
              debugPrint('✓ [viewer] 为 TextBox 字段 $fieldName 设置字体成功');
            } catch (e) {
              fontSetFailedCount++;
              debugPrint('× [viewer] 为 TextBox 字段 $fieldName 设置字体失败: $e');
            }
          } else if (field is PdfComboBoxField) {
            try {
              // 先打印原始字体信息
              try {
                final originalFont = field.font;
                _printFontProperties(originalFont, fieldName, 'ComboBox');
              } catch (e) {
                debugPrint('⚠ [viewer] ComboBox 字段 $fieldName 读取原始字体失败: $e');
              }
              
              field.font = _chineseFont!;
              fontSetCount++;
              debugPrint('✓ [viewer] 为 ComboBox 字段 $fieldName 设置字体成功');
            } catch (e) {
              fontSetFailedCount++;
              debugPrint('× [viewer] 为 ComboBox 字段 $fieldName 设置字体失败: $e');
            }
          } else if (field is PdfListBoxField) {
            try {
              // 先打印原始字体信息
              try {
                final originalFont = field.font;
                _printFontProperties(originalFont, fieldName, 'ListBox');
              } catch (e) {
                debugPrint('⚠ [viewer] ListBox 字段 $fieldName 读取原始字体失败: $e');
              }
              
              field.font = _chineseFont!;
              fontSetCount++;
              debugPrint('✓ [viewer] 为 ListBox 字段 $fieldName 设置字体成功');
            } catch (e) {
              fontSetFailedCount++;
              debugPrint('× [viewer] 为 ListBox 字段 $fieldName 设置字体失败: $e');
            }
          }
        } catch (e) {
          fontSetFailedCount++;
          debugPrint('× [viewer] 为字段 $fieldName 设置字体失败: $e');
        }
      }

      debugPrint('[viewer] 字体设置完成: 成功 $fontSetCount 个, 失败 $fontSetFailedCount 个');

      // 注意：这里不保存文档，因为文档已经在viewer中加载
      // 字体设置会立即生效，viewer会使用新字体渲染表单字段
    } catch (e) {
      debugPrint('[viewer] 设置表单字段字体失败: $e');
    }
  }

  /// 为PDF表单字段设置支持中文的字体（在加载PDF时调用）
  Future<Uint8List> _processPdfFonts(Uint8List pdfBytes) async {
    return pdfBytes;
    // if (!kEnableProcessChinese) {
    //   debugPrint('不开启字体处理');
    //   return pdfBytes;
    // }
    // if (_chineseFont == null) {
    //   debugPrint('未加载中文字体，跳过字体处理');
    //   return pdfBytes;
    // }
    //
    // try {
    //   // 打开PDF文档
    //   final PdfDocument document = PdfDocument(inputBytes: pdfBytes);
    //
    //   // 获取表单
    //   final PdfForm form = document.form;
    //   if (form.fields.count == 0) {
    //     debugPrint('PDF中没有表单字段');
    //     final List<int> result = await document.save();
    //     document.dispose();
    //     return Uint8List.fromList(result);
    //   }
    //
    //   int fontSetCount = 0;
    //   int fontSetFailedCount = 0;
    //
    //   // 为所有表单字段设置字体
    //   for (int i = 0; i < form.fields.count; i++) {
    //     final PdfField field = form.fields[i];
    //     final String fieldName = field.name ?? '未知字段$i';
    //
    //     try {
    //       if (field is PdfTextBoxField) {
    //         // 先尝试访问字段属性，如果失败说明字段有问题，跳过
    //         try {
    //           // 检查字段是否可访问
    //           final _ = field.bounds;
    //           final _ = field.readOnly;
    //         } catch (e) {
    //           debugPrint('× 字段 $fieldName 属性访问失败，跳过: $e');
    //           fontSetFailedCount++;
    //           continue;
    //         }
    //
    //         // 先尝试清空字段值，避免字体不支持的错误
    //         // 注意：如果字段值包含不支持的字符，访问text属性可能会触发错误
    //         // 所以我们需要先清空，再设置字体
    //         bool shouldClearValue = false;
    //         try {
    //           // 尝试读取字段值，如果成功且有值，标记需要清空
    //           final currentText = field.text;
    //           if (currentText.isNotEmpty) {
    //             shouldClearValue = true;
    //             field.text = ''; // 先清空
    //           }
    //         } catch (e) {
    //           // 如果读取失败（可能包含不支持的字符），尝试直接清空
    //           debugPrint('⚠ 字段 $fieldName 读取值失败，尝试清空: $e');
    //           try {
    //             field.text = '';
    //             shouldClearValue = true;
    //           } catch (e2) {
    //             // 如果清空也失败，说明字段有问题，跳过
    //             debugPrint('× 字段 $fieldName 清空值失败，跳过: $e2');
    //             fontSetFailedCount++;
    //             continue;
    //           }
    //         }
    //
    //         // 设置字体
    //         try {
    //           field.font = _chineseFont!;
    //           fontSetCount++;
    //           debugPrint('✓ 为 TextBox 字段 $fieldName 设置字体成功');
    //           // 注意：我们不恢复原始值，因为原始值可能包含不支持的字符
    //           // 用户输入中文时，新字体会支持，所以不会有问题
    //         } catch (e) {
    //           debugPrint('× 为 TextBox 字段 $fieldName 设置字体失败: $e');
    //           fontSetFailedCount++;
    //           continue;
    //         }
    //       } else if (field is PdfComboBoxField) {
    //         // ComboBox 字段处理
    //         try {
    //           field.font = _chineseFont!;
    //           fontSetCount++;
    //           debugPrint('✓ 为 ComboBox 字段 $fieldName 设置字体成功');
    //         } catch (e) {
    //           fontSetFailedCount++;
    //           debugPrint('× 为 ComboBox 字段 $fieldName 设置字体失败: $e');
    //         }
    //       } else if (field is PdfListBoxField) {
    //         // ListBox 字段处理
    //         try {
    //           field.font = _chineseFont!;
    //           fontSetCount++;
    //           debugPrint('✓ 为 ListBox 字段 $fieldName 设置字体成功');
    //         } catch (e) {
    //           fontSetFailedCount++;
    //           debugPrint('× 为 ListBox 字段 $fieldName 设置字体失败: $e');
    //         }
    //       }
    //     } catch (e, stackTrace) {
    //       fontSetFailedCount++;
    //       debugPrint('× 为字段 $fieldName 设置字体失败: $e');
    //       debugPrint('堆栈跟踪: $stackTrace');
    //     }
    //   }
    //
    //   debugPrint('字体设置完成: 成功 $fontSetCount 个, 失败 $fontSetFailedCount 个');
    //
    //   // 保存修改后的PDF
    //   final List<int> result = await document.save();
    //   document.dispose();
    //
    //   return Uint8List.fromList(result);
    // } catch (e) {
    //   debugPrint('处理PDF字体失败: $e');
    //   return pdfBytes; // 如果处理失败，返回原始PDF
    // }
  }
  static final bool kEnableProcessChinese = false;
  Future<void> _loadPdf() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final ByteData data = await rootBundle.load(_pdfAssetPath);
      final Uint8List bytes = data.buffer.asUint8List();

      // 处理PDF表单字段字体，确保支持中文
      final Uint8List processedBytes = await _processPdfFonts(bytes);

      setState(() {
        _pdfBytes = processedBytes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '加载PDF失败: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _pdfViewerController?.dispose();
    super.dispose();
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

  /// 保存PDF文件到应用缓存目录
  Future<void> _savePdf() async {
    if (_pdfViewerController == null) {
      return;
    }

    try {
      // 显示加载提示
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 16),
              Text('正在保存PDF...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      // 保存策略：由于在 viewer 中设置字体后保存会报错，我们需要：
      // 1. 如果当前文档存在，先从原始数据重新创建文档
      // 2. 应用表单字段的值（从 viewer 获取）
      // 3. 设置字体
      // 4. 保存
      
      List<int> savedBytes;
      
      if (_currentDocument != null && _chineseFontBytes != null) {
        try {
          // 从原始 PDF 字节重新创建文档
          final PdfDocument saveDocument = PdfDocument(inputBytes: _pdfBytes!);

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
          // 如果失败，尝试直接使用 viewer 保存（可能会失败）
          savedBytes = await _pdfViewerController!.saveDocument();
        }
      } else {
        // 如果没有文档引用或中文字体，直接使用 viewer 保存
        savedBytes = await _pdfViewerController!.saveDocument();
      }

      // 获取应用缓存目录
      final Directory cacheDir = await getApplicationCacheDirectory();
      final String fileName = 'saved_form_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final String filePath = '${cacheDir.path}${Platform.pathSeparator}$fileName';

      // 保存文件
      final File file = File(filePath);
      await file.writeAsBytes(savedBytes);

      if (!mounted) return;

      // 隐藏加载提示并显示成功消息
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('PDF保存成功！'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: '确定',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );

      debugPrint('PDF已保存到: $filePath');
    } catch (e, stackTrace) {
      debugPrint('PDF保存失败: $e');
      debugPrint('堆栈跟踪: $stackTrace');
      if (!mounted) return;

      // 显示错误提示
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('保存失败: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: '确定',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );

      debugPrint('保存PDF失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Syncfusion PDF 查看器'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_pdfViewerController != null && _pdfBytes != null) ...[
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: '保存PDF',
              onPressed: _savePdf,
            ),
            IconButton(
              icon: const Icon(Icons.first_page),
              tooltip: '第一页',
              onPressed: () {
                _pdfViewerController!.jumpToPage(1);
              },
            ),
            IconButton(
              icon: const Icon(Icons.last_page),
              tooltip: '最后一页',
              onPressed: () {
                _pdfViewerController!.jumpToPage(
                  _pdfViewerController!.pageCount,
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.zoom_in),
              tooltip: '放大',
              onPressed: () {
                _pdfViewerController!.zoomLevel += 0.25;
              },
            ),
            IconButton(
              icon: const Icon(Icons.zoom_out),
              tooltip: '缩小',
              onPressed: () {
                if (_pdfViewerController!.zoomLevel > 0.25) {
                  _pdfViewerController!.zoomLevel -= 0.25;
                }
              },
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _error != null
              ? Center(
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
                      ),
                    ],
                  ),
                )
              : _pdfBytes != null
                  ? SfPdfViewer.memory(
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
                      onPageChanged: (PdfPageChangedDetails details) {
                        debugPrint('当前页面: ${details.newPageNumber}');
                      },
                    )
                  : const Center(
                      child: Text('PDF数据为空'),
                    ),
    );
  }
}

