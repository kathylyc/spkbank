import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../../pdfviewer.dart';
import 'pdf_checkbox.dart';
import 'pdf_combo_box.dart';
import 'pdf_form_field.dart';
import 'pdf_list_box.dart';
import 'pdf_radio_button.dart';
import 'pdf_signature.dart';
import 'pdf_text_box.dart';
import 'pdf_image_field.dart';
import '../utils/image_field_utils.dart';

class FormFieldContainer extends StatefulWidget {
  const FormFieldContainer({
    super.key,
    required this.formFields,
    this.onTap,
    this.heightPercentage = 1,
    this.canShowSignaturePadDialog = true,
    required this.pdfViewerController,
    this.imageFieldConfig,
  });

  final List<PdfFormField> formFields;

  final void Function(Offset)? onTap;

  final PdfViewerController pdfViewerController;

  final double heightPercentage;

  final bool canShowSignaturePadDialog;

  /// 图像域配置
  final ImageFieldConfig? imageFieldConfig;

  @override
  State<FormFieldContainer> createState() => _FormFieldContainerState();
}

class _FormFieldContainerState extends State<FormFieldContainer> {
  /// 图像域管理器
  late final ImageFieldManager _imageFieldManager;

  @override
  void initState() {
    super.initState();
    _imageFieldManager = ImageFieldManager(config: widget.imageFieldConfig);
  }

  @override
  void dispose() {
    _imageFieldManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerUp: (PointerUpEvent event) {
        widget.onTap?.call(event.localPosition);
      },
      child: RepaintBoundary(child: Stack(children: _buildFormFields())),
    );
  }

  List<Widget> _buildFormFields() {
    final List<Widget> formFields = <Widget>[];
    if (widget.formFields.isNotEmpty) {
      for (final PdfFormField formField in widget.formFields) {
        final PdfFormFieldHelper helper = PdfFormFieldHelper.getHelper(
          formField,
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateGlobalRect(helper);
        });
        helper.onChanged = () {
          if (mounted) {
            setState(() {});
          }
        };

        if (formField is PdfTextFormField) {
          formFields.add(
            (helper as PdfTextFormFieldHelper).build(
              context,
              widget.heightPercentage,
            ),
          );
        } else if (formField is PdfCheckboxFormField) {
          formFields.add(
            (helper as PdfCheckboxFormFieldHelper).build(
              context,
              widget.heightPercentage,
            ),
          );
        } else if (formField is PdfComboBoxFormField) {
          formFields.add(
            (helper as PdfComboBoxFormFieldHelper).build(
              context,
              widget.heightPercentage,
            ),
          );
        } else if (formField is PdfRadioFormField) {
          formFields.addAll(
            (helper as PdfRadioFormFieldHelper).build(
              context,
              widget.heightPercentage,
            ),
          );
        } else if (formField is PdfListBoxFormField) {
          formFields.add(
            (helper as PdfListBoxFormFieldHelper).build(
              context,
              widget.heightPercentage,
            ),
          );
        } else if (formField is PdfSignatureFormField) {
          if (helper is PdfSignatureFormFieldHelper) {
            helper.pdfViewerController = widget.pdfViewerController;
            helper.canShowSignaturePadDialog = widget.canShowSignaturePadDialog;
            formFields.add(helper.build(context, widget.heightPercentage));
          }
        }
        // 检查是否为图像域
        else if (ImageFieldUtils.isImageField(formField, widget.imageFieldConfig?.imageFieldNames)) {
          // 为图像域创建自定义Widget
          formFields.add(_buildImageFieldWidget(formField, helper));
        }
        // 注意：PdfButtonField 默认不渲染，但图像域会特殊处理
      }
    }
    return formFields;
  }

  /// 创建图像域数据存储
  Uint8List? _getFormFieldImageData(String formFieldName) {
    final Uint8List? imageData = _imageFieldManager.getImageData(formFieldName);
    return imageData;
  }
  
  /// 构建图像域Widget
  Widget _buildImageFieldWidget(PdfFormField formField, PdfFormFieldHelper helper) {
    final Rect originalBounds = helper.bounds;
    final Rect fieldBounds = Rect.fromLTWH(
      originalBounds.left / widget.heightPercentage,
      originalBounds.top / widget.heightPercentage,
      originalBounds.width / widget.heightPercentage,
      originalBounds.height / widget.heightPercentage,
    );

    return Positioned(
      left: fieldBounds.left,
      top: fieldBounds.top,
      width: fieldBounds.width,
      height: fieldBounds.height,
      child: GestureDetector(
        onTap: () {
          if (!formField.readOnly) {
            _handleImageFieldClick(formField, helper);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(2),
            color: _getFormFieldImageData(formField.name) != null
                ? (widget.imageFieldConfig?.uploadedColor ?? const Color(0xFFE8F5E8))
                : Colors.white,
          ),
          child: Center(
            child: _getFormFieldImageData(formField.name) != null
                ? _buildImagePreview(_getFormFieldImageData(formField.name)!)
                : _buildUploadButton(),
          ),
        ),
      ),
    );
  }

  /// 处理图像域点击
  Future<void> _handleImageFieldClick(PdfFormField formField, PdfFormFieldHelper helper) async {
    try {
      // 创建或获取 PdfImageFormField 实例
      PdfImageFormField imageField;
      // if (formField is PdfImageFormField) {
      //   imageField = formField;
      //   // 使用现有的表单字段数据
      //   final existingImageData = _imageFieldManager.getImageData(formField.name);
      //   if (existingImageData != null) {
      //     imageField.imageData = existingImageData;
      //   }
      // } else {
      //   // 如果不是 PdfImageFormField，创建一个新的实例
      //   imageField = PdfImageFormField(config: widget.imageFieldConfig);
      //
      //   // 获取原始字段的helper来访问PdfField
      //   final originalHelper = PdfFormFieldHelper.getHelper(formField);
      //
      //   // 创建并初始化 helper，使用原始的PdfField
      //   final helper = PdfImageFormFieldHelper(
      //     originalHelper.pdfField,
      //     originalHelper.pageIndex,
      //     config: widget.imageFieldConfig,
      //     pdfViewerController: _pdfViewerController,
      //     imageFieldManager: _imageFieldManager,
      //   );
      //   imageField.initializeHelper(helper);
      //
      //   // 使用现有的表单字段数据
      //   final existingImageData = _imageFieldManager.getImageData(formField.name);
      //   if (existingImageData != null) {
      //     imageField.imageData = existingImageData;
      //   }
      // }
      if (formField is PdfImageFormField) {
        debugPrint('form_field_container._handleImageFieldClick()==>');
        imageField = formField;
        await _imageFieldManager.handleImageFieldClick(context, imageField);
      }
    } catch (e) {
      debugPrint('Error handling image field click: $e');
    }
  }

  /// 构建图像预览
  Widget _buildImagePreview(Uint8List imageData) {
    return Image.memory(
      imageData,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
  }

  /// 构建上传按钮
  Widget _buildUploadButton() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.cloud_upload,
          color: widget.imageFieldConfig?.iconColor ?? Colors.grey,
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          widget.imageFieldConfig?.uploadText ?? '点击上传图片',
          style: TextStyle(
            color: widget.imageFieldConfig?.textColor ?? Colors.grey,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  
  /// Updates the global rect of the form field.
  void _updateGlobalRect(PdfFormFieldHelper helper) {
    if (!mounted) {
      return;
    }
    final renderObject = context.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      helper.globalRect = Rect.fromPoints(
        renderObject.localToGlobal(
          helper.bounds.topLeft / widget.heightPercentage,
        ),
        renderObject.localToGlobal(
          helper.bounds.bottomRight / widget.heightPercentage,
        ),
      );
    }
  }
}
