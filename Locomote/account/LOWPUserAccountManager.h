// Copyright 2018 InnerFunction Ltd.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
//  Created by Julian Goacher on 22/05/2018.
//  Copyright © 2018 Locomote.sh. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LOUserAccountManager.h"

/**
 * A user account manager implementation that works with a Wordpress backend to authenticate users.
 * Can also be used to create Wordpress user accounts.
 * TODO: This class probably belongs outside of this library.
 */
@interface LOWPUserAccountManager : NSObject <LOUserAccountManager>

@property (nonatomic, strong) NSUserDefaults *userDefaults;
@property (nonatomic, strong) NSString *baseURL;

@end
