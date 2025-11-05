# PDF文件目录

此目录用于存放PDF文件资源。

## 使用说明

### 方式1：使用Python脚本生成示例PDF

如果您的系统已安装Python和reportlab库：

```bash
# 安装reportlab（如果未安装）
pip3 install reportlab

# 运行生成脚本
python3 create_sample_pdf.py
```

### 方式2：手动添加PDF文件

直接将您的PDF文件重命名为 `sample.pdf` 并放在此目录下即可。

## 注意事项

- PDF文件名必须是 `sample.pdf`（与代码中的文件名一致）
- 确保PDF文件在 `pubspec.yaml` 的assets配置中
- 如果PDF文件不存在，应用会显示错误提示

