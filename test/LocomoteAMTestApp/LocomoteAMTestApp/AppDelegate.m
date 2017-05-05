//
//  AppDelegate.m
//  LocomoteAMTestApp
//
//  Created by Julian Goacher on 05/05/2017.
//  Copyright © 2017 Locomote.sh. All rights reserved.
//

#import "AppDelegate.h"
#import "Locomote.h"

#define CONFIG_STYLE_REF    0
#define CONFIG_STYLE_OBJ    1

#define START_STYLE_WAIT                0
#define START_STYLE_WAIT_TIMEOUT        1
#define START_STYLE_CALLBACK            2
#define START_STYLE_CALLBACK_TIMEOUT    3

#define USE_CONFIG_STYLE    (CONFIG_STYLE_REF)
#define USE_START_STYLE     (START_STYLE_WAIT)

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    
    switch (USE_CONFIG_STYLE) {
    case CONFIG_STYLE_REF:
    
        [Locomote addRepository:@"locomote/test"];
        
        break;
    case CONFIG_STYLE_OBJ:
    default:
    
        [Locomote addRepository:@{ @"account": @"locomote", @"repo": @"test" }];
        
        break;
    }
    
    
    switch (USE_START_STYLE) {
    case START_STYLE_WAIT:
    
        [Locomote startAndWait];
        
        break;
    case START_STYLE_WAIT_TIMEOUT:
    
        [Locomote startAndWaitWithTimeout:5];
        
        break;
    case START_STYLE_CALLBACK:
    
        [Locomote startWithCallback: (void)^(BOOL synced) {
        }];
        
        break;
    case START_STYLE_CALLBACK_TIMEOUT:
    default:
    
        [Locomote startWithTimeout:5 callback: (void)^(BOOL synced) {
        }];
        
        break;
    }
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
