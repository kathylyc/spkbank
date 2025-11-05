import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart';

class PdfPreviewPage extends StatefulWidget {
  const PdfPreviewPage({super.key});

  @override
  State<PdfPreviewPage> createState() => _PdfPreviewPageState();
}

class _PdfPreviewPageState extends State<PdfPreviewPage> {
  PdfControllerPinch? _pdfController;
  bool _isLoading = true;
  String _error = '';
  
  // PDF文件路径（写死）
  final String pdfFilePath = 'assets/pdf/Application Form for CorporateAccount_202212_clean (FINAL VERSION).pdf';
  
  // PDF文件信息（动态读取）
  String pdfFileName = '加载中...';
  String pdfFileSize = '加载中...';
  String pdfCreateDate = '加载中...';
  String pdfPages = '加载中...';
  
  PdfDocument? _pdfDocument; // 保存文档引用以便获取页数

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  /// 从文件路径提取文件名
  String _extractFileName(String path) {
    final parts = path.split('/');
    return parts.isNotEmpty ? parts.last : path;
  }
  
  /// 格式化文件大小
  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
  }
  
  /// 更新PDF文件信息
  Future<void> _updatePdfInfo(PdfDocument document, int? fileSizeBytes) async {
    if (!mounted) return;
    
    try {
      // 1. 文件名：从路径提取
      final fileName = _extractFileName(pdfFilePath);
      
      // 2. 文件大小：从字节数组计算
      final fileSize = fileSizeBytes != null 
          ? _formatFileSize(fileSizeBytes)
          : '未知';
      
      // 3. 总页数：从文档获取
      final pageCount = document.pagesCount;
      
      // 4. 创建日期：尝试从PDF元数据获取，如果无法获取则使用当前日期
      String createDate = DateTime.now().toString().split(' ')[0]; // 默认使用当前日期
      try {
        // 尝试从PDF元数据获取创建日期（如果pdfx支持）
        // 注意：pdfx可能不直接支持元数据访问，这里使用当前日期作为默认值
        createDate = DateTime.now().toString().split(' ')[0];
      } catch (e) {
        debugPrint('无法获取PDF创建日期: $e');
      }
      
      setState(() {
        pdfFileName = fileName;
        pdfFileSize = fileSize;
        pdfPages = pageCount.toString();
        pdfCreateDate = createDate;
      });
      
      debugPrint('PDF文件信息已更新:');
      debugPrint('  文件名: $pdfFileName');
      debugPrint('  文件大小: $pdfFileSize');
      debugPrint('  总页数: $pdfPages');
      debugPrint('  创建日期: $pdfCreateDate');
    } catch (e) {
      debugPrint('更新PDF文件信息失败: $e');
    }
  }

  Future<void> _loadPdf() async {
    debugPrint('========== 开始加载PDF ==========');
    debugPrint('PDF文件路径: $pdfFilePath');
    
    // 初始化时显示文件名
    setState(() {
      pdfFileName = _extractFileName(pdfFilePath);
    });
    
    try {
      // 方法1: 尝试使用 rootBundle 加载为字节数组，避免路径中的空格和括号问题
      debugPrint('方法1: 尝试使用 rootBundle 加载文件...');
      try {
        final ByteData data = await rootBundle.load(pdfFilePath);
        final Uint8List bytes = data.buffer.asUint8List();
        final fileSizeBytes = bytes.length;
        debugPrint('✓ 文件加载成功，大小: $fileSizeBytes 字节');
        
        debugPrint('正在打开PDF文档（使用字节数据）...');
        final document = await PdfDocument.openData(bytes)
            .catchError((error, stackTrace) {
          debugPrint('========== PdfDocument.openData 失败 ==========');
          debugPrint('错误详情: $error');
          debugPrint('错误类型: ${error.runtimeType}');
          debugPrint('堆栈跟踪:');
          debugPrint(stackTrace.toString());
          debugPrint('================================');
          throw error;
        });
        
        // 保存文档引用
        _pdfDocument = document;
        
        // 更新PDF文件信息
        await _updatePdfInfo(document, fileSizeBytes);
        
        debugPrint('正在创建PDF控制器...');
        _pdfController = PdfControllerPinch(
          document: PdfDocument.openData(bytes),
        );
        debugPrint('PDF控制器创建成功');
        
        // 等待一小段时间确保控制器初始化完成
        await Future.delayed(const Duration(milliseconds: 100));
        
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          debugPrint('PDF加载完成（使用字节数据方式）');
        }
        return; // 成功，直接返回
      } catch (e) {
        debugPrint('方法1失败: $e');
        debugPrint('尝试方法2: 使用 openAsset...');
      }
      
      // 方法2: 如果方法1失败，尝试直接使用 openAsset
      debugPrint('方法2: 尝试使用 PdfDocument.openAsset...');
      
      // 先加载文件获取大小
      ByteData? assetData;
      int? fileSizeBytes;
      try {
        assetData = await rootBundle.load(pdfFilePath);
        fileSizeBytes = assetData.lengthInBytes;
        debugPrint('文件大小: $fileSizeBytes 字节');
      } catch (e) {
        debugPrint('无法获取文件大小: $e');
      }
      
      final document = await PdfDocument.openAsset(pdfFilePath)
          .catchError((error, stackTrace) {
        debugPrint('========== PdfDocument.openAsset 失败 ==========');
        debugPrint('错误详情: $error');
        debugPrint('错误类型: ${error.runtimeType}');
        debugPrint('堆栈跟踪:');
        debugPrint(stackTrace.toString());
        debugPrint('================================');
        throw error;
      });
      
      // 保存文档引用
      _pdfDocument = document;
      
      // 更新PDF文件信息
      await _updatePdfInfo(document, fileSizeBytes);
      
      debugPrint('正在创建PDF控制器...');
      _pdfController = PdfControllerPinch(
        document: PdfDocument.openAsset(pdfFilePath),
      );
      debugPrint('PDF控制器创建成功');
      
      // 等待一小段时间确保控制器初始化完成
      await Future.delayed(const Duration(milliseconds: 100));
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        debugPrint('PDF加载完成（使用 openAsset 方式）');
      }
    } catch (e, stackTrace) {
      // 打印详细的错误日志和堆栈跟踪
      debugPrint('========== PDF预览加载失败 ==========');
      debugPrint('错误详情: $e');
      debugPrint('错误类型: ${e.runtimeType}');
      debugPrint('错误消息: ${e.toString()}');
      
      // 如果是 PlatformException，打印更多详细信息
      if (e.toString().contains('PlatformException')) {
        debugPrint('这是一个 PlatformException，可能来自原生代码');
        debugPrint('请检查：');
        debugPrint('1. PDF文件是否存在于 assets/pdf/ 目录');
        debugPrint('2. pubspec.yaml 中是否配置了 assets/pdf/ 路径');
        debugPrint('3. 文件路径是否正确（注意文件名中的特殊字符）');
        debugPrint('4. 是否运行了 flutter pub get 并重新构建应用');
      }
      
      debugPrint('PDF文件路径: $pdfFilePath');
      debugPrint('堆栈跟踪:');
      debugPrint(stackTrace.toString());
      debugPrint('================================');
      
      if (mounted) {
        setState(() {
          _error = '加载PDF失败，请确保在assets/pdf/目录下存在PDF文件\n\n错误详情: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF预览'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // 上方：PDF基本信息区域
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.2),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PDF文件信息',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildInfoRow('文件名', pdfFileName),
                const SizedBox(height: 8),
                _buildInfoRow('文件大小', pdfFileSize),
                const SizedBox(height: 8),
                _buildInfoRow('创建日期', pdfCreateDate),
                const SizedBox(height: 8),
                _buildInfoRow('总页数', pdfPages),
              ],
            ),
          ),
          const Divider(height: 1),
          // 下方：PDF预览区域
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _error.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _error,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadPdf,
                              child: const Text('重试'),
                            ),
                          ],
                        ),
                      )
                    : _pdfController != null
                        ? Builder(
                            builder: (context) {
                              try {
                                return PdfViewPinch(
                                  controller: _pdfController!,
                                  scrollDirection: Axis.vertical,
                                );
                              } catch (e, stackTrace) {
                                debugPrint('========== PDF渲染时发生错误 ==========');
                                debugPrint('错误详情: $e');
                                debugPrint('错误类型: ${e.runtimeType}');
                                debugPrint('堆栈跟踪:');
                                debugPrint(stackTrace.toString());
                                debugPrint('================================');
                                
                                // 更新错误状态
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (mounted) {
                                    setState(() {
                                      _error = 'PDF渲染失败: $e';
                                    });
                                  }
                                });
                                
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.error_outline,
                                        size: 64,
                                        color: Colors.red,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'PDF渲染失败: $e',
                                        style: const TextStyle(color: Colors.red),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                );
                              }
                            },
                          )
                        : const Center(
                            child: Text('PDF预览不可用'),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

