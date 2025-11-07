import 'dart:ui';
import 'package:bank_flutter/utils/context_extensions.dart';
import 'package:bank_flutter/utils/storage_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'pdf_preview_page.dart';
import 'pdf_webview_page.dart';
import 'pdf_form_reader.dart';
import 'pdf_form_overlay_page.dart';
import 'pdf_syncfusion_viewer_page.dart';
import 'features/admin_user/login_page.dart';
import 'features/router/router_page.dart';
import 'l10n/app_localizations.dart';
import '../utils/page_transition_animations.dart';

void main() {
  // 设置全局错误处理，确保所有错误都被打印到终端
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('========== FlutterError 捕获 ==========');
    debugPrint('错误: ${details.exception}');
    debugPrint('堆栈: ${details.stack}');
    debugPrint('上下文: ${details.context}');
    debugPrint('================================');
  };
  
  // 捕获异步错误
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('========== PlatformDispatcher 错误捕获 ==========');
    debugPrint('错误: $error');
    debugPrint('堆栈: $stack');
    debugPrint('================================');
    return true;
  };
  
  // 设置全屏模式
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
    overlays: [],
  );
  
  // 设置首选屏幕方向（可选，根据需求调整）
  // SystemChrome.setPreferredOrientations([
  //   DeviceOrientation.landscapeLeft,
  //   DeviceOrientation.landscapeRight,
  // ]);
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bank Flutter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      // 配置本地化支持（使用生成的代码）
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      // 支持的语言列表（使用生成的列表，确保一致性）
      supportedLocales: AppLocalizations.supportedLocales,
      // 不设置 locale，让系统自动根据设备语言选择
      // 如果系统语言是英文，会显示英文；否则显示中文
      home: const AuthWrapper(),
    );
  }
}

/// 认证包装器
/// 根据登录状态显示不同的页面
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoggedIn = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  /// 检查登录状态
  Future<void> _checkLoginStatus() async {
    final isLoggedIn = await StorageUtils.isLoggedIn.get();
    if (mounted) {
      setState(() {
        _isLoggedIn = isLoggedIn!;
        _isLoading = false;
      });
    }
  }

  /// 处理登录成功
  void _onLoginSuccess() {
    setState(() {
      _isLoggedIn = true;
    });
  }

  /// 处理退出登录
  void _onLogout() {
    setState(() {
      _isLoggedIn = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 加载中显示加载指示器
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // 使用 AnimatedSwitcher 实现页面切换动画
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500), // 动画持续时间
      transitionBuilder: PageTransitionAnimations.fadeScale,
      child: _isLoggedIn
          ? RouterPage(
              key: const ValueKey('router'), // 关键：不同的 key 才会触发动画
              onLogout: _onLogout,
            )
          : LoginPage(
              key: const ValueKey('login'), // 关键：不同的 key 才会触发动画
              onLoginSuccess: _onLoginSuccess,
            ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<PdfFormField> _formFields = [];
  bool _isLoading = false;
  String? _error;

  final String _pdfAssetPath =
      'assets/pdf/Application Form for CorporateAccount_202212_clean (FINAL VERSION).pdf';
  // final String _pdfAssetPath =
  //     'assets/pdf/测试表单.pdf';

  @override
  void initState() {
    super.initState();
    _loadFormFields();
  }

  Future<void> _loadFormFields() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final fields = await PdfFormReader.readFormFieldsFromAsset(_pdfAssetPath);
      setState(() {
        _formFields = fields;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '加载表单字段失败: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateCheckbox1() async {
    try {
      final filePath = await PdfFormReader.updateFieldValueAndSave(
        _pdfAssetPath,
        'Last Name or Surname_2',
        '哈哈哈嘿嘿嘿',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF已保存到: $filePath'),
            duration: const Duration(seconds: 3),
          ),
        );
        
        // 重新加载表单字段以显示更新后的值
        _loadFormFields();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('更新失败: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bank Flutter'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新表单字段',
            onPressed: _loadFormFields,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                '欢迎使用 Bank Flutter',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '这是一个针对平板设备优化的应用',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  ElevatedButton.icon(
                    onPressed: _updateCheckbox1,
                    icon: const Icon(Icons.edit),
                    label: const Text('更新checkbox1'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      minimumSize: const Size(160, 48),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PdfPreviewPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.visibility),
                    label: const Text('预览PDF (静态)'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      minimumSize: const Size(180, 48),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PdfWebViewPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit_document),
                    label: const Text('编辑PDF (可交互)'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      minimumSize: const Size(180, 48),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PdfFormOverlayPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.article),
                    label: const Text('PDF表单编辑'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      minimumSize: const Size(180, 48),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PdfSyncfusionViewerPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Syncfusion PDF查看'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      minimumSize: const Size(180, 48),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'PDF表单字段列表',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_error != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                )
              else if (_formFields.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.grey),
                      SizedBox(width: 12),
                      Text(
                        '该PDF文件没有找到表单字段',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle,
                              color: Colors.blue.shade700),
                          const SizedBox(width: 12),
                          Text(
                            '找到 ${_formFields.length} 个表单字段',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // ...(_formFields.map((field) => _buildFormFieldCard(field))),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormFieldCard(PdfFormField field) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getTypeColor(field.type),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    field.type,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (field.isReadOnly) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '只读',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '字段名称:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              field.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (field.value != null && field.value!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '字段值:',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  field.value!,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
            // 显示位置和尺寸信息
            if (field.x != null || field.y != null || field.width != null || field.height != null) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Text(
                '位置和尺寸:',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  if (field.x != null)
                    _buildInfoChip('X', field.x!.toStringAsFixed(2)),
                  if (field.y != null)
                    _buildInfoChip('Y', field.y!.toStringAsFixed(2)),
                  if (field.width != null)
                    _buildInfoChip('宽度', field.width!.toStringAsFixed(2)),
                  if (field.height != null)
                    _buildInfoChip('高度', field.height!.toStringAsFixed(2)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'TextBox':
        return Colors.blue;
      case 'CheckBox':
        return Colors.green;
      case 'ComboBox':
        return Colors.purple;
      case 'RadioButton':
        return Colors.orange;
      case 'ListBox':
        return Colors.teal;
      case 'Signature':
        return Colors.red;
      case 'Button':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  Widget _buildInfoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue.shade900,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

