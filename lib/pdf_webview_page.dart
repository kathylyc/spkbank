import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:path_provider/path_provider.dart';

class PdfWebViewPage extends StatefulWidget {
  const PdfWebViewPage({super.key});

  @override
  State<PdfWebViewPage> createState() => _PdfWebViewPageState();
}

class _PdfWebViewPageState extends State<PdfWebViewPage> {
  WebViewController? _webViewController;
  bool _isLoading = true;
  String _error = '';

  // PDF文件信息
  final String pdfFileName = 'Application Form for CorporateAccount_202212_clean (FINAL VERSION).pdf';
  final String pdfAssetPath = 'assets/pdf/Application Form for CorporateAccount_202212_clean (FINAL VERSION).pdf';

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      // Web平台不支持path_provider和webview_flutter
      if (kIsWeb) {
        setState(() {
          _error = 'Web平台暂不支持PDF编辑功能\n请使用iOS或Android平台';
          _isLoading = false;
        });
        return;
      }
      
      // 将assets中的PDF文件复制到应用的临时目录
      final ByteData data = await rootBundle.load(pdfAssetPath);
      final Uint8List bytes = data.buffer.asUint8List();
      
      final Directory tempDir = await getTemporaryDirectory();
      final String tempPath = '${tempDir.path}/$pdfFileName';
      final File tempFile = File(tempPath);
      
      await tempFile.writeAsBytes(bytes);
      
      // 使用WebView加载PDF文件
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white)
        ..addJavaScriptChannel(
          'FormDataChannel',
          onMessageReceived: (JavaScriptMessage message) {
            _handleFormData(message.message);
          },
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              setState(() {
                _isLoading = true;
              });
            },
            onPageFinished: (String url) {
              setState(() {
                _isLoading = false;
              });
              // 页面加载完成后注入JavaScript
              _injectJavaScript();
            },
            onWebResourceError: (WebResourceError error) {
              setState(() {
                _error = '加载PDF失败: ${error.description}';
                _isLoading = false;
              });
            },
          ),
        );

      // 加载PDF文件
      // 使用file://协议加载本地文件
      final Uri fileUri = Uri.file(tempPath);
      
      if (Platform.isIOS) {
        // iOS可以直接加载本地PDF文件
        await _webViewController!.loadRequest(fileUri);
      } else if (Platform.isAndroid) {
        // Android需要特殊的URL编码和处理
        // 尝试使用file://协议
        await _webViewController!.loadRequest(fileUri);
      } else {
        throw UnsupportedError('不支持的平台');
      }

      setState(() {
        _error = '';
      });
    } catch (e) {
      setState(() {
        _error = '加载PDF失败: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF编辑'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_error.isEmpty) ...[
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: '保存FDF数据',
              onPressed: _saveFdfData,
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '刷新',
              onPressed: _loadPdf,
            ),
          ],
        ],
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
                _buildInfoRow('状态', _error.isEmpty ? '可编辑' : '加载失败'),
              ],
            ),
          ),
          const Divider(height: 1),
          // 下方：PDF预览区域
          Expanded(
            child: _error.isNotEmpty
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
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            _error,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadPdf,
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  )
                : Stack(
                    children: [
                      _webViewController != null
                          ? WebViewWidget(controller: _webViewController!)
                          : const Center(
                              child: Text('WebView未初始化'),
                            ),
                      if (_isLoading)
                        Container(
                          color: Colors.white.withValues(alpha: 0.9),
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                    ],
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

  // 注入JavaScript来获取PDF表单数据
  Future<void> _injectJavaScript() async {
    if (_webViewController == null) return;
    
    const String javascript = '''
      (function() {
        // 尝试访问PDF.js API
        if (typeof PDFViewerApplication !== 'undefined') {
          // PDF.js 已加载，可以直接访问表单
          console.log('PDF.js found');
          
          // 添加消息监听以便从外部触发
          window.getFormData = function() {
            try {
              const formData = {};
              
              // 尝试获取PDF文档
              if (PDFViewerApplication && PDFViewerApplication.pdfDocument) {
                const pdfDoc = PDFViewerApplication.pdfDocument;
                
                // 遍历所有页面获取表单字段
                pdfDoc.getFieldObjects().then(function(fields) {
                  if (fields) {
                    for (let field in fields) {
                      const fieldObj = pdfDoc.getField(field);
                      if (fieldObj && fieldObj.value !== undefined) {
                        formData[field] = fieldObj.value;
                      }
                    }
                  }
                  
                  // 通过通道发送数据到Flutter
                  if (window.FormDataChannel) {
                    window.FormDataChannel.postMessage(JSON.stringify(formData));
                  }
                });
              }
            } catch(e) {
              console.error('Error getting form data:', e);
              if (window.FormDataChannel) {
                window.FormDataChannel.postMessage(JSON.stringify({error: e.toString()}));
              }
            }
          };
        } else {
          console.log('PDF.js not found, using fallback method');
          
          // 备用方法：使用HTML5的iframe检测
          window.getFormData = function() {
            const formData = {};
            
            // 尝试找到PDF查看器中的表单元素
            const iframes = document.querySelectorAll('iframe');
            if (iframes.length > 0) {
              try {
                // 如果PDF是在iframe中加载的，尝试访问其内容
                const pdfFrame = iframes[0];
                if (pdfFrame.contentWindow && pdfFrame.contentDocument) {
                  console.log('Found PDF iframe');
                }
              } catch (e) {
                console.log('Cannot access iframe content:', e);
              }
            }
            
            // 通过通道发送数据到Flutter
            if (window.FormDataChannel) {
              window.FormDataChannel.postMessage(JSON.stringify(formData));
            }
          };
        }
      })();
    ''';
    
    try {
      await _webViewController!.runJavaScript(javascript);
    } catch (e) {
      debugPrint('Error injecting JavaScript: $e');
    }
  }

  // 保存FDF数据
  Future<void> _saveFdfData() async {
    if (_webViewController == null) {
      _showMessage('WebView未初始化');
      return;
    }
    
    try {
      // 调用JavaScript函数获取表单数据
      await _webViewController!.runJavaScript('window.getFormData();');
    } catch (e) {
      _showMessage('获取表单数据失败: $e');
    }
  }

  // 处理从JavaScript接收到的表单数据
  void _handleFormData(String data) {
    try {
      final Map<String, dynamic> formData = Map<String, dynamic>.from(
        jsonDecode(data),
      );
      
      if (formData.containsKey('error')) {
        _showMessage('获取表单数据出错: ${formData['error']}');
        return;
      }
      
      // 生成FDF文件
      _generateAndSaveFdf(formData);
    } catch (e) {
      _showMessage('解析表单数据失败: $e');
    }
  }

  // 生成并保存FDF文件
  Future<void> _generateAndSaveFdf(Map<String, dynamic> formData) async {
    try {
      // 生成FDF文件内容
      final String fdfContent = _generateFdfContent(formData);
      
      // 保存到临时目录
      final Directory tempDir = await getTemporaryDirectory();
      final String fdfFileName = pdfFileName.replaceAll('.pdf', '.fdf');
      final String fdfPath = '${tempDir.path}/$fdfFileName';
      final File fdfFile = File(fdfPath);
      
      await fdfFile.writeAsString(fdfContent);
      
      _showMessage('FDF数据已保存到: $fdfPath');
    } catch (e) {
      _showMessage('保存FDF文件失败: $e');
    }
  }

  // 生成FDF文件内容
  String _generateFdfContent(Map<String, dynamic> formData) {
    final StringBuffer buffer = StringBuffer();
    
    // FDF头部
    buffer.writeln('%FDF-1.2');
    buffer.writeln('1 0 obj');
    buffer.writeln('<<');
    buffer.writeln('/FDF');
    buffer.writeln('<<');
    buffer.writeln('/F ($pdfFileName)');
    buffer.writeln('/Fields [');
    
    // 添加表单字段
    bool firstField = true;
    formData.forEach((key, value) {
      if (!firstField) {
        buffer.writeln();
      }
      firstField = false;
      
      buffer.write('<<');
      buffer.write('/T ($key)');
      
      if (value is String) {
        // 转义特殊字符
        String escapedValue = value
            .replaceAll('\\', '\\\\')
            .replaceAll('(', '\\(')
            .replaceAll(')', '\\)');
        buffer.write('/V ($escapedValue)');
      } else if (value is bool) {
        buffer.write('/V /${value ? 'Yes' : 'Off'}');
      } else if (value is int || value is double) {
        buffer.write('/V ($value)');
      }
      
      buffer.write('>>');
    });
    
    // FDF尾部
    buffer.writeln(']');
    buffer.writeln('>>');
    buffer.writeln('>>');
    buffer.writeln('endobj');
    buffer.writeln('trailer');
    buffer.writeln('<<');
    buffer.writeln('/Root 1 0 R');
    buffer.writeln('>>');
    buffer.writeln('%%EOF');
    
    return buffer.toString();
  }

  // 显示消息
  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
