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
#import "LOCMSContentAuthority.h"
#import "LORequestDispatcher.h"
#import "LOCMSSettings.h"
#import "LOCMSFileset.h"

@class LOCMSRepository;

/**
 * A request handler that serves content from a single Locomote content repository.
 * In a typical setup, a file within a specific repository can be referenced using a content
 * URL in the form:
 *
 *      content://{authority}/{account}/{repo}/{path...}
 *
 * Where 'authority' would be the host name (e.g. locomote.sh); 'account' and 'repo' would
 * specify account and content repo names; and 'path...' would be the path to the required
 * file within the repository.
 * In addition, the request handler provides a number of standard API end points which can
 * be used to access file lists and file meta data. These are:
 *
 * > files.api/
 *      Return a list of all files in the repository. Results can be filtered by supplying
 *      query parameters.
 * > files.api/{id}
 *      Access a file's meta-data by ID.
 * > files.api/{id}/content
 *      Access file content by the file ID.
 * > files.api/{id}/siblings
 *      Return a list of a file's siblings. These are all files that share the same path
 *      directory as the reference file.
 * > files.api/{id}/children
 *      Return a list of the immediate children of a file. These are all files that are
 *      in a path directory immediately below the reference file.
 * > files.api/{id}/descendents
 *      Return a list of all descendents of a file. These are all files that are in a path
 *      directory below the reference file.
 * (TODO: Document fileset.api)
 * > search.api
 *      Perform a full-text search of page content.
 */
@interface LOCMSRepoRequestHandler : NSObject <LORequestHandler, LORequestDispatcherHost> {
    /// A request dispatcher.
    LORequestDispatcher *_dispatcher;
}

/// Settings for accessing the content repository.
@property (nonatomic, strong) LOCMSSettings *settings;
/// The filesets defined for the content repository.
/// TODO: Repurpose the current LOCMSRepository to be a home for all repo specific settings,
/// then make a property of this class; this class should pass the repository through to
/// each of its handlers when the repo property is set.
@property (nonatomic, strong, readonly) NSDictionary<NSString *, LOCMSFileset *> *filesets;

- (id)initWithRepository:(LOCMSRepository *)repository;

@end
