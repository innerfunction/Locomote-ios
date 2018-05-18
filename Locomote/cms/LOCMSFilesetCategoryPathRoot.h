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
//  Created by Julian Goacher on 23/09/2016.
//  Copyright © 2016 InnerFunction. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LOContentAuthority.h"
#import "LOCMSFileDB.h"

@class LOCMSFileset;
@class LOCMSRepository;

/**
 * A default path root implementation for access to a single category of fileset contents.
 * @deprecated
 */
@interface LOCMSFilesetCategoryPathRoot : NSObject <LOContentAuthorityPathRoot>

/// The fileset being accessed.
@property (nonatomic, weak) LOCMSFileset *fileset;
/// The content repository.
@property (nonatomic, weak) LOCMSRepository *repository;
/// The file database.
@property (nonatomic, weak) LOCMSFileDB *fileDB;

/// Initialize the path root with the specified fileset and content repository.
- (id)initWithFileset:(LOCMSFileset *)fileset repository:(LOCMSRepository *)repository;
/// Query the file database for entries in the current fileset.
- (NSArray *)queryWithParameters:(NSDictionary *)parameters;
/// Read a single entry from the file database by key (i.e. file ID).
- (NSDictionary *)entryWithKey:(NSString *)key;
/// Read a single entry from the file database by file path.
- (NSDictionary *)entryWithPath:(NSString *)path;
/// Write a query response.
- (void)writeQueryContent:(NSArray *)content asType:(NSString *)type toResponse:(id<LOContentAuthorityResponse>)response;
/// Write an entry response.
- (void)writeEntryContent:(NSDictionary *)content asType:(NSString *)type toResponse:(id<LOContentAuthorityResponse>)response;

@end
