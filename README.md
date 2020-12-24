# SJCVersion
一句代码检测APP是否有新版本，可自定义弹框UI，可设置强制更新，跳过此版本，下一次打开再提醒更新

```objective-c
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    ...
    [[SJCVersion sharedInstance] checkVersion];
    return YES;
}
