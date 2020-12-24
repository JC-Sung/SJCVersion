//
//  SJCVersion.h
//  版本更新
//
//  Created by 时光与你 on 2019/8/20.
//  Copyright © 2019 Yehwang. All rights reserved.
//

#import <UIKit/UIKit.h>

FOUNDATION_EXPORT NSString * const SJCVersionDidShowNotification;
FOUNDATION_EXPORT NSString * const SJCVersionDidLaunchAppStoreNotification;
FOUNDATION_EXPORT NSString * const SJCVersionDidSkipVersionNotification;
FOUNDATION_EXPORT NSString * const SJCVersionDidCancelNotification;
FOUNDATION_EXPORT NSString * const SJCVersionDidDetectNewVersionWithoutAlertNotification;

typedef NS_ENUM(NSUInteger, SJCVersionAlertType){
    SJCVersionAlertTypeForce = 1,
    SJCVersionAlertTypeOption,
    SJCVersionAlertTypeSkip,
    SJCVersionAlertTypeNone
};


@interface SJCVersion : NSObject

@property (nonatomic, copy, readonly) NSString *currentAppStoreVersion;

@property (nonatomic, assign) SJCVersionAlertType alertType;

+ (SJCVersion *)sharedInstance;

- (void)checkVersion;

- (void)checkVersionDaily;

- (void)checkVersionWeekly;

@end

