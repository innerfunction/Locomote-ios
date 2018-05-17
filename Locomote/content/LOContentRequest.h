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

@class LOContentPath;
@protocol LOContentAuthority;

/**
 * A protocol for providing information about a content URL or URI request.
 */
@protocol LOContentRequest <NSObject>

/// The content authority the request is being made to.
@property (nonatomic, weak) id<LOContentAuthority> authority;
/// The request path.
@property (nonatomic, strong) LOContentPath *path;
/// The request parameters.
@property (nonatomic, strong) NSDictionary *parameters;
/// Parameters extracted from the request path.
@property (nonatomic, strong) NSDictionary *pathParameters;

@end

