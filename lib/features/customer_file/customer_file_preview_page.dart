import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

/// 开户文件预览页面
class CustomerFilePreviewPage extends StatefulWidget {
  final String customerName;
  final String fileName;
  final String templateName;

  const CustomerFilePreviewPage({
    super.key,
    required this.customerName,
    required this.fileName,
    required this.templateName,
  });

  @override
  State<CustomerFilePreviewPage> createState() => _CustomerFilePreviewPageState();
}

class _CustomerFilePreviewPageState extends State<CustomerFilePreviewPage> {
  PdfViewerController? _pdfViewerController;
  bool _isLoading = true;
  String? _error;
  Uint8List? _pdfBytes;
  
  // 字体相关
  PdfTrueTypeFont? _chineseFont;
  List<int>? _chineseFontBytes;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    _initializePdf();
  }

  @override
  void dispose() {
    _pdfViewerController?.dispose();
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

      // 根据模板名称加载对应的PDF文件
      // TODO: 这里可以根据 widget.templateName 来选择不同的模板
      // const String pdfAssetPath =
      //     'assets/pdf/Application Form for CorporateAccount_202212_clean (FINAL VERSION).pdf';
      const String pdfAssetPath =
          'assets/pdf/WqA2kX4FeEAM5Tq9.pdf';

      final ByteData data = await rootBundle.load(pdfAssetPath);
      final Uint8List bytes = data.buffer.asUint8List();

      setState(() {
        _pdfBytes = bytes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '加载PDF失败: $e';
        _isLoading = false;
      });
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
            const Text('预览开户文件', style: TextStyle(fontSize: 18)),
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

