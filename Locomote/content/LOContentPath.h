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

#import <Foundation/Foundation.h>

/**
 * An object representing a content path.
 * A content path is a string in the form /{c0}/{c1}..{cx}.{ext}, i.e
 * one or more path components followed by an optional path extension.
 * The path root refers to the first component (i.e. c0). The [rest]
 * method returns a new content path composed of all components after
 * the current root (i.e. c1..cx), or nil if no components are left.
 */
@interface LOContentPath : NSObject {
    /// An array containing all components of the full path.
    NSArray *_path;
    /// The index of the current path's root component.
    NSInteger _rootIdx;
    /// The extension at the end of the path.
    NSString *_ext;
}

/// Initialize with a list of path components, a root component index and path extension.
- (id)initWithPath:(NSArray *)path rootIndex:(NSInteger)rootIdx ext:(NSString *)ext;

/// Initialize with a string path.
- (id)initWithPath:(NSString *)path;

/// Initialize the path with a URL.
- (id)initWithURL:(NSURL *)url;

/// Return the root path component.
- (NSString *)head;

/// Return the path extension, or nil if the path has no extension.
- (NSString *)ext;

/**
 * Return the portion of the path after the root component.
 * Returns a new content path object whose root component is the path component after the
 * current root.
 */
- (LOContentPath *)rest;

/// Return a list containing the root component and all path components following it.
- (NSArray *)components;

/// Test if the path is empty, i.e. has no root component.
- (BOOL)isEmpty;

/// Return a string representation of the full path.
- (NSString *)fullPath;

/// Return a string representation of the relative portion of the path.
- (NSString *)relativePath;

@end
