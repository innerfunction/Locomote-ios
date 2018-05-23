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

#import <Foundation/Foundation.h>
#import "SCService.h"
#import "SCMessageReceiver.h"
#import "SCIOCTypeInspectable.h"
#import "Q.h"

@protocol LOUserProfileManager;
@class LOCMSAccountFormFactory, LOCMSRepository;

/// A content source, i.e. a content repository.
@interface LOContentSource : NSObject <SCMessageReceiver> {
    LOCMSRepository *_repository;
}

/// A reference to the source's content repository.
@property (nonatomic, strong) NSString *ref;
/// The user account manager to use with this content source.
@property (nonatomic, strong) id<LOUserProfileManager> userProfileManager;
/// The source's form factory.
@property (nonatomic, strong) LOCMSAccountFormFactory *accountFormFactory;
/// An action message for displaying the login form.
@property (nonatomic, strong) NSString *showLoginAction;

@end

/// A container or Locomote sourced content.
@interface LOContentContainer : NSObject <SCService, SCIOCTypeInspectable>

/**
 * A map to the different content sources contained by this container.
 * A map of content names to content sources.
 */
@property (nonatomic, strong) NSDictionary<NSString *, LOContentSource *> *sources;

- (void)addRepository:(NSString *)ref;
- (QPromise *)start;

+ (LOContentContainer *)getInstance;

@end


