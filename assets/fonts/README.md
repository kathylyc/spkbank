# 字体文件说明

## 如何添加中文字体

为了支持在PDF中保存中文字符，你需要下载支持中文的字体文件并放到此目录。

### 推荐的免费中文字体

1. **Noto Sans SC (简体中文)**
   - 下载地址: https://fonts.google.com/noto/specimen/Noto+Sans+SC
   - 文件名: `NotoSansSC-Regular.ttf`
   - 优点: 开源免费，支持简体中文

2. **Source Han Sans (思源黑体)**
   - 下载地址: https://github.com/adobe-fonts/source-han-sans
   - 文件名: `SourceHanSansSC-Regular.otf` 或 `.ttf`
   - 优点: Adobe开源，支持中日韩文字

3. **SimSun (宋体)**
   - 如果有合法授权，可以使用系统自带的宋体
   - 文件名: `simsun.ttf`

### 使用步骤

1. 下载字体文件（推荐使用 Noto Sans SC）
2. 将字体文件重命名为 `chinese_font.ttf`（或保持原名）
3. 将字体文件放到此目录：`assets/fonts/`
4. 运行 `flutter pub get` 更新资源
5. 重新运行应用

### 注意事项

- 字体文件通常较大（1-5MB），会增加应用体积
- 确保字体文件支持你需要的字符集（简体中文、繁体中文等）
- 字体文件必须放在 `assets/fonts/` 目录下

