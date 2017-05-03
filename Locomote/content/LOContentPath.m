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
//  Created by Julian Goacher on 09/09/2016.
//  Copyright © 2016 InnerFunction. All rights reserved.
//

#import "LOContentPath.h"

@implementation LOContentPath

- (id)initWithPath:(NSArray *)path rootIndex:(NSInteger)rootIdx ext:(NSString *)ext {
    self = [super init];
    if (self) {
        _path = path;
        _rootIdx = rootIdx;
        _ext = ext;
    }
    return self;
}

- (id)initWithPath:(NSString *)path {
    NSString *ext = nil;
    NSRange range = [path rangeOfString:@"."];
    if (range.location != NSNotFound) {
        ext = [path pathExtension];
        path = [path stringByDeletingPathExtension];
    }
    return [self initWithPath:[path componentsSeparatedByString:@"/"] rootIndex:0 ext:ext];
}

- (id)initWithURL:(NSURL *)url {
    // Strip the leading / from the URLs path.
    NSString *path = [url.path substringFromIndex:1];
    return [self initWithPath:path];
}

- (NSString *)head {
    return [self isEmpty] ? nil : _path[_rootIdx];
}

- (NSString *)ext {
    return _ext;
}

- (LOContentPath *)rest {
    if ([self isEmpty]) {
        return nil;
    }
    return [[LOContentPath alloc] initWithPath:_path rootIndex:_rootIdx + 1 ext:_ext];
}

- (NSArray *)components {
    return [_path subarrayWithRange:NSMakeRange(_rootIdx, [_path count] - _rootIdx)];
}

- (BOOL)isEmpty {
    return _rootIdx >= [_path count];
}

- (NSString *)fullPath {
    NSString *path = [_path componentsJoinedByString:@"/"];
    if (_ext) {
        path = [path stringByAppendingPathExtension:_ext];
    }
    return path;
}

- (NSString *)relativePath {
    return [[self components] componentsJoinedByString:@"/"];
}

@end
