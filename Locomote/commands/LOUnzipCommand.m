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
//  Created by Julian Goacher on 08/12/2015.
//  Copyright © 2015 InnerFunction. All rights reserved.
//

#import "LOUnzipCommand.h"
#import "SCFileIO.h"

@implementation LOUnzipCommand

@synthesize name=_name;

- (id)init {
    self = [super init];
    if (self) {
        _name = @"unzip";
    }
    return self;
}

- (QPromise *)execute:(NSArray *)args {
    if ([args count] < 2) {
        return [Q reject:@"Wrong number of arguments"];
    }
    NSString *zipPath = [args objectAtIndex:0];
    NSString *toPath = [args objectAtIndex:1];
    BOOL overwrite = YES;
    if ([args count] > 2) {
        overwrite = [@"yes" isEqualToString:[args objectAtIndex:2]];
    }
    if ([SCFileIO unzipFileAtPath:zipPath toPath:toPath overwrite:overwrite]) {
        return [Q resolve:@[]];
    }
    return [Q reject:@"Failed to unzip file"];
}

@end
