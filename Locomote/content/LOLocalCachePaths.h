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
//  Created by Julian Goacher on 17/05/2018.
//  Copyright © 2018 Locomote.sh. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * Path settings for locally cached content.
 */
@interface LOLocalCachePaths : NSObject

/// Initialize with settings and an authority name.
- (id)initWithSettings:(LOLocalCachePaths *)settings authorityName:(NSString *)authorityName;

/// A path for temporarily staging downloaded content.
@property (nonatomic, strong) NSString *stagingPath;
/// A path for caching app content.
@property (nonatomic, strong) NSString *appCachePath;
/// A path for caching downloaded content.
@property (nonatomic, strong) NSString *contentCachePath;
/// A path for app packaged content.
@property (nonatomic, strong) NSString *packagedContentPath;

@end
