// Copyright 2017 InnerFunction Ltd.
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
//  Created by Julian Goacher on 30/09/2016.
//  Copyright © 2016 InnerFunction. All rights reserved.
//

#import "LOMIMETypes.h"

static NSDictionary *LOMIMETypes_lookup;

@implementation LOMIMETypes

+  (void)initialize {
    LOMIMETypes_lookup = @{
        @"html":    @"text/html",
        @"json":    @"application/json",
        @"png":     @"image/png",
        @"jpg":     @"image/jpg",
        @"jpeg":    @"image/jpeg",
        @"gif":     @"image/gif"
    };
}

+ (NSString *)mimeTypeForType:(NSString *)type {
    NSString *mimeType = LOMIMETypes_lookup[type];
    if (!mimeType) {
        mimeType = @"application/octet-stream";
    }
    return mimeType;
}

@end
