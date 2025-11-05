import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final ByteData data = await rootBundle.load(_pdfAssetPath);
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

  @override
  void dispose() {
    _pdfViewerController?.dispose();
    super.dispose();
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
                      onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                        debugPrint('PDF文档已加载，共 ${details.document.pages.count} 页');
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

