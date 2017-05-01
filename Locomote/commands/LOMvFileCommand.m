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

#import "LOMvFileCommand.h"

@interface LOMvFileCommand()

- (NSError *)moveFileAtPath:(NSString *)fromPath toPath:(NSString *)toPath;

@end

@implementation LOMvFileCommand

@synthesize name=_name;

- (id)init {
    self = [super init];
    if (self) {
        _name = @"mv-file";
        _fileManager = [NSFileManager defaultManager];
    }
    return self;
}

- (QPromise *)execute:(NSArray *)args {
    if ([args count] < 2) {
        return [Q reject:@"Wrong number of arguments"];
    }
    NSString *fromPath = [args objectAtIndex:0];
    NSString *toPath = [args objectAtIndex:1];
    BOOL fromIsDirectory;
    NSError *error = nil;
    // Check from location exists.
    if ([_fileManager fileExistsAtPath:fromPath isDirectory:&fromIsDirectory]) {
        if (fromIsDirectory) {
            // Check target location exists.
            if (![_fileManager fileExistsAtPath:toPath]) {
                [_fileManager createDirectoryAtPath:toPath withIntermediateDirectories:YES attributes:nil error:&error];
            }
            if (!error) {
                // List directory contents and move each one to the target location.
                NSArray *files = [_fileManager contentsOfDirectoryAtPath:fromPath error:&error];
                for (NSInteger idx = 0; idx < [files count] && !error; idx++) {
                    NSString *filename = files[idx];
                    NSString *fromFile = [fromPath stringByAppendingPathComponent:filename];
                    NSString *toFile = [toPath stringByAppendingPathComponent:filename];
                    error = [self moveFileAtPath:fromFile toPath:toFile];
                }
            }
        }
        else {
            error = [self moveFileAtPath:fromPath toPath:toPath];
        }
    }
    if (error) {
        [Q reject:error];
    }
    return [Q resolve:@[]];
}

#pragma mark - Private methods

- (NSError *)moveFileAtPath:(NSString *)fromPath toPath:(NSString *)toPath {
    NSError *error = nil;
    // If there is already a file at the target path then remove it first.
    if ([_fileManager fileExistsAtPath:toPath]) {
        [_fileManager removeItemAtPath:toPath error:&error];
    }
    if (!error) {
        [_fileManager moveItemAtPath:fromPath toPath:toPath error:&error];
    }
    return error;
}

@end
