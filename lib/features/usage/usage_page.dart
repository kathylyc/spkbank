import 'package:bank_flutter/utils/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 使用说明页面
class UsagePage extends StatefulWidget {
  const UsagePage({super.key});

  @override
  State<UsagePage> createState() => _UsagePageState();
}

class _UsagePageState extends State<UsagePage> {
  PdfViewerController? _pdfViewerController;
  bool _isLoading = true;
  String? _error;
  Uint8List? _pdfBytes;
  String _version = '加载中...';

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    _loadAppVersion();
    _loadPdf();
  }

  /// 获取应用版本号
  Future<void> _loadAppVersion() async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String version = packageInfo.version;
      final String buildNumber = packageInfo.buildNumber;

      if (mounted) {
        setState(() {
          _version = version;
        });
      }
    } catch (e) {
      debugPrint('获取应用版本信息失败: $e');
      if (mounted) {
        setState(() {
          _version = '未知';
        });
      }
    }
  }

  @override
  void dispose() {
    try {
      _pdfViewerController?.dispose();
    } catch (e) {
      debugPrint('释放PDF资源时出错: $e');
    }
    super.dispose();
  }

  /// 加载PDF文件
  Future<void> _loadPdf() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // 从 assets 加载 PDF 文件
      final ByteData data = await rootBundle.load('assets/usage/usage.pdf');
      final bytes = data.buffer.asUint8List();

      setState(() {
        _pdfBytes = bytes;
        _isLoading = false;
      });
      debugPrint('✓ 使用说明PDF加载成功');
    } catch (e) {
      setState(() {
        _error = '加载PDF失败: $e';
        _isLoading = false;
      });
      debugPrint('加载使用说明PDF失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '软件版本 V$_version',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
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
            Text('正在加载使用说明...'),
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
      return Builder(
        builder: (context) {
          try {
            return SfPdfViewer.memory(
              _pdfBytes!,
              controller: _pdfViewerController,
              enableDoubleTapZooming: true,
              enableTextSelection: true,
              canShowScrollHead: true,
              canShowScrollStatus: true,
              canShowSignaturePadDialog: false, // 禁用签名功能
              onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                debugPrint('使用说明PDF已加载，共 ${details.document.pages.count} 页');
              },
              onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                debugPrint('使用说明PDF加载出错: ${details.description}');
                if (mounted) {
                  SnackbarUtils.error('PDF加载失败: ${details.description}', context);
                }
              },
              onPageChanged: (details) {
                debugPrint('当前页面: ${details.newPageNumber}');
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
        },
      );
    }

    return const Center(
      child: Text('PDF数据为空'),
    );
  }
}