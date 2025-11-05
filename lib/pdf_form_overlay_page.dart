import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusion;
import 'pdf_form_reader.dart';

class PdfFormOverlayPage extends StatefulWidget {
  const PdfFormOverlayPage({super.key});

  @override
  State<PdfFormOverlayPage> createState() => _PdfFormOverlayPageState();
}

class _PdfFormOverlayPageState extends State<PdfFormOverlayPage> {
  PdfControllerPinch? _pdfController;
  bool _isLoading = true;
  String _error = '';
  List<PdfFormField> _formFields = [];
  Map<String, dynamic> _fieldValues = {}; // 存储字段值的映射
  Map<String, TextEditingController> _textControllers = {}; // 存储TextField的controller
  double _pdfPageWidth = 0;
  double _pdfPageHeight = 0;
  List<double> _pageHeights = []; // 存储每一页的高度
  double _totalPdfHeight = 0; // PDF文档总高度（所有页面累加）
  
  // PDF文件路径
  final String pdfFilePath = 
      'assets/pdf/Application Form for CorporateAccount_202212_clean (FINAL VERSION).pdf';

  @override
  void initState() {
    super.initState();
    _loadPdfAndFormFields();
  }

  Future<void> _loadPdfAndFormFields() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      // 并行加载PDF和表单字段
      final results = await Future.wait([
        _loadPdf(),
        PdfFormReader.readFormFieldsFromAsset(pdfFilePath),
      ]);

      final fields = results[1] as List<PdfFormField>;
      
      // 初始化字段值
      final Map<String, dynamic> fieldValues = {};
      for (final field in fields) {
        if (field.value != null && field.value!.isNotEmpty) {
          fieldValues[field.name] = field.value;
        } else {
          // 根据字段类型设置默认值
          switch (field.type) {
            case 'CheckBox':
              fieldValues[field.name] = false;
              break;
            case 'TextBox':
              fieldValues[field.name] = '';
              break;
            case 'ComboBox':
              fieldValues[field.name] = null;
              break;
            default:
              fieldValues[field.name] = '';
          }
        }
      }

      if (mounted) {
        setState(() {
          _formFields = fields;
          _fieldValues = fieldValues;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '加载失败: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadPdf() async {
    try {
      final ByteData data = await rootBundle.load(pdfFilePath);
      final Uint8List bytes = data.buffer.asUint8List();
      
      // 使用 syncfusion_flutter_pdf 获取PDF页面尺寸
      try {
        final syncDocument = syncfusion.PdfDocument(inputBytes: bytes);
        if (syncDocument.pages.count > 0) {
          final firstPage = syncDocument.pages[0];
          final firstPageSize = firstPage.size;
          _pdfPageWidth = firstPageSize.width;
          _pdfPageHeight = firstPageSize.height;
          
          // 获取所有页面的高度信息
          _pageHeights.clear();
          _totalPdfHeight = 0;
          for (int i = 0; i < syncDocument.pages.count; i++) {
            final page = syncDocument.pages[i];
            final pageHeight = page.size.height;
            _pageHeights.add(pageHeight);
            _totalPdfHeight += pageHeight;
          }
          
          debugPrint('PDF总页数: ${syncDocument.pages.count}');
          debugPrint('PDF总高度: $_totalPdfHeight');
        }
        syncDocument.dispose();
      } catch (e) {
        debugPrint('获取PDF页面尺寸失败，使用默认值: $e');
        // 使用标准A4尺寸作为默认值（单位：点）
        _pdfPageWidth = 595.0;  // A4宽度
        _pdfPageHeight = 842.0;  // A4高度
        _pageHeights = [_pdfPageHeight];
        _totalPdfHeight = _pdfPageHeight;
      }
      
      // 创建 pdfx 控制器用于预览
      _pdfController = PdfControllerPinch(
        document: PdfDocument.openData(bytes),
      );
    } catch (e) {
      throw Exception('加载PDF失败: $e');
    }
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    // 注意：PdfDocument 不需要 dispose，pdfx 会自动管理
    // 释放所有TextField的controller
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    _textControllers.clear();
    super.dispose();
  }

  // 将PDF坐标转换为屏幕坐标
  // 注意：PDF坐标系使用左下角为原点(0,0)，而Flutter使用左上角为原点
  // pdfX, pdfY: PDF中的坐标（以PDF页面左下角为原点）
  // pageIndex: 字段所在的页码（从0开始），用于计算多页PDF的累计高度
  // screenWidth, screenHeight: 屏幕显示区域的宽度和高度
  // 返回: 屏幕坐标（相对于PDF显示区域左上角）
  Offset _convertPdfToScreenCoordinates(
    double pdfX,
    double pdfY,
    int? pageIndex,
    double screenWidth,
    double screenHeight,
  ) {
    if (_pdfPageWidth == 0 || _pdfPageHeight == 0) {
      return Offset(0, 0);
    }
    
    // 如果没有提供页码，默认使用第一页（索引0）
    final fieldPageIndex = pageIndex ?? 0;
    
    // 获取字段所在页面的高度
    double fieldPageHeight;
    if (fieldPageIndex < _pageHeights.length) {
      fieldPageHeight = _pageHeights[fieldPageIndex];
    } else {
      // 如果页码超出范围，使用第一页的高度
      fieldPageHeight = _pdfPageHeight;
    }
    
    // 计算字段所在页面之前所有页面的累计高度
    double accumulatedHeightBeforePage = 0;
    for (int i = 0; i < fieldPageIndex && i < _pageHeights.length; i++) {
      accumulatedHeightBeforePage += _pageHeights[i];
    }
    
    // 使用PDF总高度来计算缩放比例（多页PDF）
    final totalHeight = _totalPdfHeight > 0 ? _totalPdfHeight : _pdfPageHeight;
    
    // 计算缩放比例（保持纵横比，基于总高度）
    final scaleX = (screenWidth - 0) / _pdfPageWidth;
    final scaleY = (screenHeight - 0) / _pdfPageHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY;
    
    // 计算实际显示的PDF尺寸
    final actualPdfWidth = _pdfPageWidth * scale;
    final actualPdfHeight = totalHeight * scale;
    
    // 计算居中偏移
    final offsetX = (screenWidth - actualPdfWidth) / 2;
    final offsetY = (screenHeight - actualPdfHeight) / 2;
    
    // PDF坐标系：左下角为原点，Y轴向上
    // Flutter坐标系：左上角为原点，Y轴向下
    // 对于多页PDF，需要：
    // 1. 将字段的Y坐标转换为相对于页面顶部的坐标：fieldPageHeight - pdfY
    // 2. 加上前面页面的累计高度：accumulatedHeightBeforePage + (fieldPageHeight - pdfY)
    // 3. 应用缩放和偏移
    final screenX = pdfX * scale + offsetX;
    // final screenY = offsetY + (accumulatedHeightBeforePage + (fieldPageHeight - pdfY)) * scale;
    final screenY = offsetY + (accumulatedHeightBeforePage + pdfY) * scale;
    
    return Offset(screenX, screenY);
  }

  // 将PDF尺寸转换为屏幕尺寸
  Size _convertPdfToScreenSize(
    double pdfWidth,
    double pdfHeight,
    double screenWidth,
    double screenHeight,
  ) {
    if (_pdfPageWidth == 0 || _pdfPageHeight == 0) {
      return Size(pdfWidth, pdfHeight);
    }
    
    final scaleX = screenWidth / _pdfPageWidth;
    final scaleY = screenHeight / _pdfPageHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY;
    
    return Size(pdfWidth * scale, pdfHeight * scale);
  }

  // 构建表单字段控件
  Widget? _buildFormFieldWidget(PdfFormField field, Size screenSize) {
    // 如果字段没有位置信息，无法显示
    if (field.x == null || field.y == null || 
        field.width == null || field.height == null) {
      return null;
    }

    // 转换坐标和尺寸，使用字段的pageIndex进行真实高度的计算
    final position = _convertPdfToScreenCoordinates(
      field.x!,
      field.y!,
      field.pageIndex, // 传入字段所在的页码，用于计算多页PDF的累计高度
      screenSize.width,
      screenSize.height,
    );
    
    final size = _convertPdfToScreenSize(
      field.width!,
      field.height!,
      screenSize.width,
      screenSize.height,
    );

    // 根据字段类型构建不同的控件
    Widget? widget;
    
    switch (field.type) {
      case 'TextBox':
        widget = _buildTextBox(field, size);
        break;
      case 'CheckBox':
        widget = _buildCheckBox(field, size);
        break;
      case 'ComboBox':
        widget = _buildComboBox(field, size);
        break;
      case 'RadioButton':
        widget = _buildRadioButton(field, size);
        break;
      default:
        // 其他类型暂时显示为文本框
        widget = _buildTextBox(field, size);
    }

    if (widget == null) return null;

    // 如果字段是只读的，禁用控件
    if (field.isReadOnly) {
      widget = IgnorePointer(
        child: Opacity(
          opacity: 0.6,
          child: widget,
        ),
      );
    }

    // 使用Positioned定位控件
    // 注意：position.dy已经是相对于PDF显示区域左上角的坐标
    // 但需要减去size.height，因为字段的Y坐标是字段底部的Y坐标
    return Positioned(
      left: position.dx,
      top: position.dy - size.height,
      width: size.width,
      height: size.height,
      child: widget,
    );
  }

  Widget _buildTextBox(PdfFormField field, Size size) {
    // 获取或创建controller
    if (!_textControllers.containsKey(field.name)) {
      _textControllers[field.name] = TextEditingController(
        text: _fieldValues[field.name]?.toString() ?? '',
      );
    }
    
    final controller = _textControllers[field.name]!;
    
    // 如果字段值已更新，同步到controller
    final currentValue = _fieldValues[field.name]?.toString() ?? '';
    if (controller.text != currentValue) {
      controller.text = currentValue;
    }
    
    return TextField(
      controller: controller,
      onChanged: (value) {
        setState(() {
          _fieldValues[field.name] = value;
        });
      },
      enabled: !field.isReadOnly,
      style: TextStyle(
        fontSize: size.height * 0.4, // 根据高度调整字体大小
      ),
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.blue, width: 1),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: size.width * 0.05,
          vertical: size.height * 0.1,
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.9),
      ),
    );
  }

  Widget _buildCheckBox(PdfFormField field, Size size) {
    final isChecked = _fieldValues[field.name] == true || 
                     _fieldValues[field.name]?.toString().toLowerCase() == 'yes';
    
    return GestureDetector(
      onTap: field.isReadOnly ? null : () {
        setState(() {
          _fieldValues[field.name] = !isChecked;
        });
      },
      child: Container(
        width: size.width,
        height: size.height,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          border: Border.all(color: Colors.blue, width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: isChecked
              ? Icon(
                  Icons.check,
                  size: size.height * 0.7,
                  color: Colors.blue,
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildComboBox(PdfFormField field, Size size) {
    // 注意：ComboBox的选项需要从PDF中获取，这里简化处理
    // 实际应用中可能需要从PdfFormReader中获取选项列表
    final currentValue = _fieldValues[field.name]?.toString();
    
    return Container(
      width: size.width,
      height: size.height,
      padding: EdgeInsets.symmetric(horizontal: size.width * 0.05),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        border: Border.all(color: Colors.blue, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButton<String>(
        value: currentValue,
        isExpanded: true,
        items: [
          // 这里应该从PDF字段中获取选项，暂时使用占位符
          DropdownMenuItem(value: currentValue, child: Text(currentValue ?? '')),
        ],
        onChanged: field.isReadOnly ? null : (value) {
          setState(() {
            _fieldValues[field.name] = value;
          });
        },
        style: TextStyle(fontSize: size.height * 0.4),
      ),
    );
  }

  Widget _buildRadioButton(PdfFormField field, Size size) {
    // RadioButton通常需要一组选项，这里简化处理
    final isSelected = _fieldValues[field.name] != null && 
                       _fieldValues[field.name].toString().isNotEmpty;
    
    return GestureDetector(
      onTap: field.isReadOnly ? null : () {
        setState(() {
          _fieldValues[field.name] = !isSelected;
        });
      },
      child: Container(
        width: size.width,
        height: size.height,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          border: Border.all(color: Colors.blue, width: 1),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: isSelected
              ? Container(
                  width: size.width * 0.5,
                  height: size.height * 0.5,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  // 保存表单字段值到PDF
  Future<void> _saveFormFields() async {
    try {
      // 注意：updateFieldValueAndSave每次调用都会保存一个新的PDF文件
      // 为了简化，这里只保存第一个有值的字段作为演示
      // 实际应用中，应该创建一个批量更新函数来一次性更新所有字段
      bool hasSaved = false;
      for (final field in _formFields) {
        final value = _fieldValues[field.name];
        if (value != null && value.toString().isNotEmpty) {
          final filePath = await PdfFormReader.updateFieldValueAndSave(
            pdfFilePath,
            field.name,
            value,
          );
          hasSaved = true;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('表单已保存到: $filePath\n（仅保存了字段: ${field.name}）'),
                duration: const Duration(seconds: 3),
              ),
            );
          }
          break; // 只保存第一个字段作为演示
        }
      }
      
      if (!hasSaved) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('没有可保存的字段值'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
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
      resizeToAvoidBottomInset: false, // 键盘弹起时不要缩放页面
      appBar: AppBar(
        title: const Text('PDF表单编辑'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: '保存表单',
            onPressed: _formFields.isEmpty ? null : _saveFormFields,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: _loadPdfAndFormFields,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_error, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadPdfAndFormFields,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    // 计算PDF总高度（用于设置可滚动区域的大小）
                    final scaleX = constraints.maxWidth / _pdfPageWidth;
                    final scaleY = constraints.maxHeight / _pdfPageHeight;
                    final scale = scaleX < scaleY ? scaleX : scaleY;
                    final actualPdfWidth = _pdfPageWidth * scale;
                    final totalPdfHeight = _totalPdfHeight > 0 ? _totalPdfHeight : _pdfPageHeight;
                    final actualPdfHeight = totalPdfHeight * scale;
                    
                    // 将所有动态渲染的原生组件放在可滚动容器中
                    return SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: actualPdfWidth,
                          height: actualPdfHeight,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // PDF预览层
                              if (_pdfController != null)
                                Positioned.fill(
                                  child: PdfViewPinch(
                                    controller: _pdfController!,
                                    scrollDirection: Axis.vertical,
                                  ),
                                ),
                              // 表单字段控件层（可滚动）
                              ..._formFields
                                  .map((field) => _buildFormFieldWidget(
                                        field,
                                        Size(actualPdfWidth, actualPdfHeight),
                                      ))
                                  .whereType<Widget>()
                                  .toList(),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

