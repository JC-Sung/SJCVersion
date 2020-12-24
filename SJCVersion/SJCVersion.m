//
//  SJCVersion.m
//  版本更新
//
//  Created by 时光与你 on 2019/8/20.
//  Copyright © 2019 Yehwang. All rights reserved.
//

#import "SJCVersion.h"

NSString * const SJCVersionDefaultSkippedVersion = @"SJCVersion User Decided To Skip Version Update Boolean";
NSString * const SJCVersionDefaultStoredVersionCheckDate = @"SJCVersion Stored Date From Last Version Check";

NSString * const SJCVersionDidShowNotification = @"SJCVersionDidShowNotification";
NSString * const SJCVersionDidLaunchAppStoreNotification = @"SJCVersionDidLaunchAppStoreNotification";
NSString * const SJCVersionDidSkipVersionNotification = @"SJCVersionDidSkipVersionNotification";
NSString * const SJCVersionDidCancelNotification = @"SJCVersionDidCancelNotification";
NSString * const SJCVersionDidDetectNewVersionWithoutAlertNotification = @"SJCVersionDidDetectNewVersionWithoutAlertNotification";

@interface SJCVersion ()
@property (nonatomic, strong) NSDictionary <NSString *, id> *appData;
@property (nonatomic, strong) NSDate *lastVersionCheckPerformedOnDate;
@property (nonatomic, copy) NSString *appID;
@property (nonatomic, copy) NSString *currentInstalledVersion;
@property (nonatomic, copy) NSString *currentAppStoreVersion;
@end

@implementation SJCVersion

+ (SJCVersion *)sharedInstance {
    static id sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (id)init {
    if (self = [super init]) {
        _alertType = SJCVersionAlertTypeSkip;
        _lastVersionCheckPerformedOnDate = [[NSUserDefaults standardUserDefaults] objectForKey:SJCVersionDefaultStoredVersionCheckDate];
        _currentInstalledVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    }
    return self;
}

- (void)checkVersion {
    [self performSelectorInBackground:@selector(startCheck) withObject:nil];
}

- (void)checkVersionDaily {
    if (![self lastVersionCheckPerformedOnDate]) {
        self.lastVersionCheckPerformedOnDate = [NSDate date];
        [self checkVersion];
    }
    if ([self numberOfDaysElapsedBetweenLastVersionCheckDate] >= 1) {
        [self checkVersion];
    }
}

- (void)checkVersionWeekly {
    if (![self lastVersionCheckPerformedOnDate]) {
        self.lastVersionCheckPerformedOnDate = [NSDate date];
        [self checkVersion];
    }
    if ([self numberOfDaysElapsedBetweenLastVersionCheckDate] >= 7) {
        [self checkVersion];
    }
}

- (void)startCheck {
    NSURL *storeURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://itunes.apple.com/lookup?bundleId=%@",[NSBundle mainBundle].bundleIdentifier]];
    NSURLRequest *request = [NSMutableURLRequest requestWithURL:storeURL cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:10.0];
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if ([data length] > 0 && !error) {
            [self handelResults:data];
        }
    }];
    [task resume];
}

- (void)handelResults:(NSData *)data {
    _appData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
    __typeof__(self) __weak weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        weakSelf.lastVersionCheckPerformedOnDate = [NSDate date];
        [[NSUserDefaults standardUserDefaults] setObject:self.lastVersionCheckPerformedOnDate forKey:SJCVersionDefaultStoredVersionCheckDate];
        [[NSUserDefaults standardUserDefaults] synchronize];
        NSDictionary<NSString *, id> *results = [self.appData valueForKey:@"results"];
        NSArray *versionsInAppStore = [results valueForKey:@"version"];
        if (versionsInAppStore != nil) {
            if ([versionsInAppStore count]) {
                weakSelf.currentAppStoreVersion = [versionsInAppStore objectAtIndex:0];
                if ([weakSelf.currentInstalledVersion compare:weakSelf.currentAppStoreVersion options:NSNumericSearch] == NSOrderedAscending) {
                    [weakSelf appStoreVersionIsNewer:weakSelf.currentAppStoreVersion];
                }
            }
        }
    });
}

- (void)appStoreVersionIsNewer:(NSString *)currentAppStoreVersion {
    _appID = _appData[@"results"][0][@"trackId"];
    if (_appID != nil) {
        [self showAlertIfCurrentAppStoreVersionNotSkipped:currentAppStoreVersion];
    }
}

- (void)showAlertIfCurrentAppStoreVersionNotSkipped:(NSString *)currentAppStoreVersion {
    NSString *storedSkippedVersion = [[NSUserDefaults standardUserDefaults] objectForKey:SJCVersionDefaultSkippedVersion];
    if (![storedSkippedVersion isEqualToString:currentAppStoreVersion]) {
        [self showAlertWithAppStoreVersion:currentAppStoreVersion];
    }
}

- (void)showAlertWithAppStoreVersion:(NSString *)currentAppStoreVersion {
    switch (self.alertType) {
        case SJCVersionAlertTypeForce: {
            UIAlertController *alertController = [self createAlertController];
            [alertController addAction:[self updateAlertAction]];
            [self showAlertController:alertController];
        }break;
        case SJCVersionAlertTypeOption: {
            UIAlertController *alertController = [self createAlertController];
            [alertController addAction:[self nextTimeAlertAction]];
            [alertController addAction:[self updateAlertAction]];
            [self showAlertController:alertController];
        }break;
        case SJCVersionAlertTypeSkip: {
            UIAlertController *alertController = [self createAlertController];
            [alertController addAction:[self updateAlertAction]];
            [alertController addAction:[self nextTimeAlertAction]];
            [alertController addAction:[self skipAlertAction]];
            [self showAlertController:alertController];
        }break;
        case SJCVersionAlertTypeNone: {
            [[NSNotificationCenter defaultCenter] postNotificationName:SJCVersionDidDetectNewVersionWithoutAlertNotification
                                                                object:self
                                                              userInfo:nil];
        }break;
    }
}

- (void)showAlertController:(UIAlertController *)alertController {
    if ([self presentingViewController] != nil) {
        [[self presentingViewController] presentViewController:alertController animated:YES completion:nil];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:SJCVersionDidShowNotification
                                                        object:self
                                                      userInfo:nil];
}


- (NSUInteger)numberOfDaysElapsedBetweenLastVersionCheckDate {
    NSCalendar *currentCalendar = [NSCalendar currentCalendar];
    NSDateComponents *components = [currentCalendar components:NSCalendarUnitDay
                                                      fromDate:self.lastVersionCheckPerformedOnDate
                                                        toDate:[NSDate date]
                                                       options:0];
    return [components day];
}

- (UIViewController *)presentingViewController{
    UIViewController *root = [[UIApplication sharedApplication] delegate].window.rootViewController;
    if ([root isKindOfClass:[UINavigationController class]]){
        UINavigationController *navRoot = (UINavigationController *)root;
        return navRoot.topViewController;
    }
    else if ([root isKindOfClass:[UITabBarController class]]){
        UITabBarController *tabRoot = (UITabBarController *)root;
        UIViewController *tabSelect = tabRoot.selectedViewController;
        if ([tabSelect isKindOfClass:[UINavigationController class]]){
            UINavigationController *tabSelectNav = (UINavigationController *)tabSelect;
            return tabSelectNav.topViewController;
        }
        else{
            return tabSelect;
        }
    }else{
        return root;
    }
    return nil;
}

- (UIAlertController *)createAlertController {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"有新版本可用"
                                                                             message:[NSString stringWithFormat:@"你的应用%@有新的版本%@，快去App Store更新吧！",[[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString *)kCFBundleNameKey],self.currentAppStoreVersion]
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    
    return alertController;
}

- (UIAlertAction *)updateAlertAction {
    UIAlertAction *updateAlertAction = [UIAlertAction actionWithTitle:@"更新"
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction *action) {
                                                                  [self launchAppStore];
                                                              }];
    
    return updateAlertAction;
}

- (UIAlertAction *)nextTimeAlertAction {
    UIAlertAction *nextTimeAlertAction = [UIAlertAction actionWithTitle:@"下一次"
                                                                  style:UIAlertActionStyleDefault
                                                                handler:^(UIAlertAction *action) {
                                                                    [self nextTime];
                                                                }];
    
    return nextTimeAlertAction;
}

- (UIAlertAction *)skipAlertAction {
    UIAlertAction *skipAlertAction = [UIAlertAction actionWithTitle:@"忽略此版本"
                                                              style:UIAlertActionStyleCancel
                                                            handler:^(UIAlertAction *action) {
                                                                [self skip];
                                                            }];
    
    return skipAlertAction;
}

- (void)launchAppStore {
    NSString *iTunesString = [NSString stringWithFormat:@"https://itunes.apple.com/app/id%@", self.appID];
    NSURL *iTunesURL = [NSURL URLWithString:iTunesString];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (@available(iOS 10.0, *)) {
            [[UIApplication sharedApplication] openURL:iTunesURL options:@{} completionHandler:nil];
        } else {
            [[UIApplication sharedApplication] openURL:iTunesURL];
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:SJCVersionDidLaunchAppStoreNotification
                                                            object:self
                                                          userInfo:nil];
    });
}

- (void)nextTime {
    [[NSNotificationCenter defaultCenter] postNotificationName:SJCVersionDidCancelNotification
                                                        object:self
                                                      userInfo:nil];
}

- (void)skip{
    [[NSUserDefaults standardUserDefaults] setObject:self.currentAppStoreVersion forKey:SJCVersionDefaultSkippedVersion];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:SJCVersionDidSkipVersionNotification
                                                        object:self
                                                      userInfo:nil];
}

@end


