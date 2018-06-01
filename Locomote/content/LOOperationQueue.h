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
//  Created by Julian Goacher on 01/06/2018.
//

#import <Foundation/Foundation.h>
#import "SCService.h"
#import "Q.h"

/**
 * A block which implements an operation and returns a deferred promise
 * resolving to a list of follow-on operations.
 */
typedef QPromise *(^LOOperationBlock) (void);

/// A pending command item.
@interface LOOperationQueueItem : NSObject

/// The block implementing the operation to be executed.
@property (nonatomic, copy) LOOperationBlock operation;
/// An identifier for uniquely identifying the operation on the queue.
@property (nonatomic, strong) NSString *opID;
/**
 * An operation's runtime identity.
 * Follow-on operations share the same identity as the command that operation
 * them.
 */
@property (nonatomic, strong) NSNumber *runTimeID;

/// Initialize a new item with the specified operation and identifier.
- (id)initWithOperation:(LOOperationBlock)operation opID:(NSString *)opID;
/// Initialize a new item with just the specified operation.
- (id)initWithOperation:(LOOperationBlock)operation;

@end

@interface LOOperationQueue : NSObject <SCService> {
    /**
     * A flag indicating whether the queue is started.
     * Operations won't be processed unless and until the queue is running.
     */
    BOOL _running;
    /// A queue of pending operations.
    NSMutableArray<LOOperationQueueItem *> *_queue;
    /// A map of pending operation completion promises.
    NSMutableDictionary<NSNumber *,QPromise *> *_pendingPromises;
}

/**
 * Append a new operation to the end of the queue.
 * The operation will be appended to the end of the queue, providing another
 * operation with the same identifier doesn't already exist on the queue.
 * The operation will be executed after all operations ahead of it on the queue
 * are executed.
 * The method returns a deferred promise which resolves once the operation, and any
 * follow on operations it generates, have completed execution.
 */
- (QPromise *)queueOperation:(LOOperationBlock)operation opID:(NSString *)opID;
/**
 * Clear all pending operations on the queue.
 * If any operation is currently executing then it will complete, but any follow-on
 * operations it returns will be discarded.
 * Returns a deferred promise which resolves when the queue is cleared.
 */
- (QPromise *)clearPending;
/// Return the command dispatch queue.
+ (dispatch_queue_t)getDispatchQueue;

@end
