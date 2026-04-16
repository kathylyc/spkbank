# 故障排除指南

## 添加新插件后遇到 MissingPluginException

如果你看到了类似以下的错误：

```
MissingPluginException(No implementation found for method getTemporaryDirectory on channel plugins.flutter.io/path_provider)
```

这是正常现象！新添加的原生插件需要**完全重启**应用才能生效。

### 解决方法

1. **完全停止当前的 Flutter 应用**
   - 不要只按 "r" (hot reload)
   - 按 "q" 退出当前运行的 Flutter 应用
   - 或者在模拟器/设备上完全关闭应用

2. **重新编译和运行**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

### 为什么需要完全重启？

Flutter 的 **hot reload** 只能更新 Dart 代码，不能加载新的原生插件代码。当你添加了像 `path_provider`、`webview_flutter` 这样有原生代码的插件时，需要重新编译原生代码，这只能通过完全重启应用来实现。

### 验证插件是否安装成功

运行以下命令检查：
```bash
cat .flutter-plugins-dependencies
```

你应该看到 `path_provider` 和 `webview_flutter` 的条目。

### iOS 特殊说明

如果是 iOS 项目，可能还需要：
```bash
cd ios
pod install
```

然后重新运行：
```bash
cd ..
flutter run
```
