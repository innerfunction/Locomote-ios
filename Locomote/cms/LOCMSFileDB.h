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
//  Created by Julian Goacher on 26/09/2016.
//  Copyright © 2016 InnerFunction. All rights reserved.
//

#import "SCDB.h"
#import "SCIOCTypeInspectable.h"

@class LOCMSRepository;

@interface LOCMSFileDB : SCDB <SCIOCTypeInspectable>

/// The content authority this database belongs to.
@property (nonatomic, weak) LOCMSRepository *repository;
/// The fileset categories defined for the database.
@property (nonatomic, strong) NSDictionary *filesets;
/// The name of the files table. Defaults to 'files'.
@property (nonatomic, strong) NSString *filesTable;

- (id)initWithRepositry:(LOCMSRepository *)repository;
- (id)initWithCMSFileDB:(LOCMSFileDB *)cmsFileDB;

/**
 * Prune ORM related values after applying updates to the database.
 * Deletes records in related tables where the version value (as specified in the table's
 * schema) doesn't match the version value on the source table.
 */
- (BOOL)pruneRelatedValues;
/**
 * Return the path of the cache location for files of the specified fileset category.
 * Returns nil if the fileset category isn't locally cachable.
 */
- (NSString *)cacheLocationForFileset:(NSString *)category;
/**
 * Return the absolute path for the cache location of the specified file record.
 * Returns nil if the file isn't locally cachable.
 */
- (NSString *)cacheLocationForFile:(NSDictionary *)fileRecord;
/**
 * Return the absolute path for the cache location of the file with the specified path.
 * Returns nil if the file isn't locally cachable.
 */
- (NSString *)cacheLocationForFileWithPath:(NSString *)path;

/// Return a new instance of this database.
- (LOCMSFileDB *)newInstance;

@end
