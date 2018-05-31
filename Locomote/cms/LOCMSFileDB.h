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

- (id)initWithRepository:(LOCMSRepository *)repository;
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
 * This will always be the non-packaged cache location.
 */
- (NSString *)cacheLocationForFileset:(NSString *)category;
/**
 * Return the full path to the cache location of the specified file path in the
 * specified fileset category.
 * Returns nil if the fileset category isn't locally cachable.
 * This will always return the non-packaged cache location.
 */
- (NSString *)cacheLocationForFile:(NSString *)filePath inFileset:(NSString *)category;
/**
 * Return the absolute path for the cache location of the specified file record.
 * Returns nil if the file isn't locally cachable.
 * This may return the packaged cache location (i.e. a path to the app bundle) if
 * the file record has a status of 'packaged'.
 */
- (NSString *)cacheLocationForFileRecord:(NSDictionary *)fileRecord;
/**
 * Return the absolute path for the cache location of the file with the specified path.
 * Returns nil if the file isn't locally cachable.
 */
- (NSString *)cacheLocationForFile:(NSString *)filePath;
/**
 * Update a file record after a file download to indicate that the file is now locally cached.
 * The main purpose of this is to change a packaged file's status to 'published'.
 */
- (void)markFileAsDownloaded:(NSString *)filePath;
/**
 * Insert a DB reset record for the specified category with the specified client visible set.
 */
- (void)insertResetCVS:(NSString *)cvs forCategory:(NSString *)category;
/**
 * Read the reset CVS for a fileset category.
 */
- (NSString *)getResetCVSForCategory:(NSString *)category;
/**
 * Return a list of any in-progress file DB resets.
 */
- (NSArray *)getInProgressResetRecords;
/**
 * Delete a reset record from the database.
 */
- (void)deleteResetRecordForCategory:(NSString *)category;
/**
 * Delete all reset records from the database.
 */
- (void)deleteAllResetRecords;
/// Return a new instance of this database.
- (LOCMSFileDB *)newInstance;

@end
