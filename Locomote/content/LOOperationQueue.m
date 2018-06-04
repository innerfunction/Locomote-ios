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

#import "LOOperationQueue.h"
#import "SCLogger.h"
#import "NSDictionary+SC.h"
#import "NSString+SC.h"

static SCLogger *Logger;
static dispatch_queue_t operationDispatchQueue;
static void *operationDispatchQueueKey = "sh.locomote.OperationQueue";

// Macro to test whether a method is called on the command dispatch queue.
#define RunningOnDispatchQueue  (dispatch_get_specific(operationDispatchQueueKey) != NULL)

#define AnonymousID (@"Anonymous")

@interface LOOperationQueue ()

/// Execute the next queued command.
- (void)dispatchNext;

@end

@implementation LOOperationQueueItem

- (id)initWithOperation:(LOOperationBlock)operation opID:(NSString *)opID {
    self = [super init];
    self.operation = operation;
    if (opID) {
        self.opID = opID;
    }
    else {
        self.opID = AnonymousID;
    }
    return self;
}

- (id)initWithOperation:(LOOperationBlock)operation {
    return [self initWithOperation:operation opID:nil];
}

- (BOOL)isEqual:(id)object {
    if ([_opID isEqualToString:AnonymousID]) {
        // Anonymous operations cannot be equal to each other.
        return NO;
    }
    if ([object isKindOfClass:[LOOperationQueueItem class]]) {
        return [_opID isEqualToString:((LOOperationQueueItem *)object).opID];
    }
    return NO;
}

- (NSUInteger)hash {
    return [_opID hash];
}

@end

@implementation LOOperationQueue

+ (void)initialize {
    Logger = [[SCLogger alloc] initWithTag:@"LOOperationQueue"];
    operationDispatchQueue = dispatch_queue_create( operationDispatchQueueKey, 0);
    dispatch_queue_set_specific(operationDispatchQueue, operationDispatchQueueKey, operationDispatchQueueKey, NULL);
}

+ (dispatch_queue_t)getDispatchQueue {
    return operationDispatchQueue;
}

- (id)init {
    self = [super init];
    if (self) {
        _running = NO;
        _queue = [NSMutableArray new];
        _pendingPromises = [NSMutableDictionary new];
    }
    return self;
}

- (QPromise *)queueOperation:(LOOperationBlock)operation opID:(NSString *)opID {
    QPromise *promise = [QPromise new];
    // Modify the operation queue on the dispatch queue.
    dispatch_async(operationDispatchQueue, ^{
        LOOperationQueueItem *item = [[LOOperationQueueItem alloc] initWithOperation:operation opID:opID];
        
        // TODO: The desired behaviour here is not to add an op to the queue if it *or any of its follow-ons*
        // has yet to complete; but this isn't what currently happens (as the op is removed from the queue as
        // soon as it completes, i.e. before its follow-ons are executed). A separate queue of pending op IDs
        // would be needed to get the desired behaviour.

        // Test whether the same operation already exists on the queue.
        NSInteger idx = [self->_queue indexOfObject:item];
        if (idx == NSNotFound) {
            // Add new operation to the queue.
            [self->_queue addObject:item];
            // Give the operation a runtime identity.
            item.runTimeID = [NSNumber numberWithInteger:[item hash]];
            // Add the operation's promise to the map of pending.
            self->_pendingPromises[item.runTimeID] = promise;
            // Execute if the queue was empty (if not empty then a operation is currently executing,
            // and will eventually dispatch the new operation once the rest of the queue is executed).
            if ([self->_queue count] == 1) {
                [self dispatchNext];
            }
        }
        else {
            // So that this operation invocation's promise resolves when the matching, pending operation
            // completes, join the current promise and the pending promise in a new promise, and replace
            // the pending promise with the new joined promise.
            LOOperationQueueItem *queuedItem = self->_queue[idx];
            QPromise *pending = self->_pendingPromises[queuedItem.runTimeID];
            QPromise *joined = [QPromise new];
            joined.then( (id)^(id result) {
                [pending resolve:result];
                [promise resolve:result];
                return nil;
            })
            .fail( ^(id error) {
                [pending reject:error];
                [promise reject:error];
            });
            self->_pendingPromises[queuedItem.runTimeID] = joined;
        }
    });
    return promise;
}

- (QPromise *)clearPending {
    QPromise *promise = [QPromise new];
    dispatch_async(operationDispatchQueue, ^{
        [self->_queue removeAllObjects];
        [promise resolve:self];
    });
    return promise;
}

#pragma mark - SCService

- (void)startService {
    _running = YES;
    // Operations may be added to the queue before it is started, execute them
    // now once the queue is started.
    [self dispatchNext];
}

- (void)stopService {
    _running = NO;
}

#pragma mark - private

- (void)dispatchNext {
    if (!_running) {
        // Don't do anything if the queue isn't running.
        return;
    }
    // The next step...
    void (^next)(void) = ^() {
        // Check that there are pending commands.
        if ([self->_queue count] > 0) {
            // Read and execute the next pending command.
            LOOperationQueueItem *item = self->_queue[0];
            item.operation()
                .then((id)^(NSArray *followOns) {
                    dispatch_async(operationDispatchQueue, ^{
                        // Remove the completed command from the queue.
                        [self->_queue removeObjectAtIndex:0];
                        // Add any follow-on commands to the end of the queue.
                        if ([followOns count] > 0) {
                            for (LOOperationBlock followOn in followOns) {
                                // Note that follow-on ops are anonymous; this is to simplify the operation interface
                                // (by not requiring operations to package follow on blocks before returning them).
                                LOOperationQueueItem *followOnItem = [[LOOperationQueueItem alloc] initWithOperation:followOn];
                                [self->_queue addObject:followOnItem];
                                // Give the follow-on the same runtime ID as
                                // its parent command.
                                followOnItem.runTimeID = item.runTimeID;
                            }
                        }
                        // If completed command has a runtime ID then check whether
                        // a pending promise needs to be resolved.
                        if (item.runTimeID) {
                            QPromise *promise = self->_pendingPromises[item.runTimeID];
                            if (promise) {
                                // Check for pending commands with the same runtime ID.
                                BOOL pending = NO;
                                for (LOOperationQueueItem *pendingItem in self->_queue) {
                                    if ([item.runTimeID isEqual:pendingItem.runTimeID]) {
                                        pending = YES;
                                        break;
                                    }
                                }
                                // If no pending commands with the same runtime ID then
                                // resolve the promise and remove it from the set of pending.
                                if (!pending) {
                                    [promise resolve:nil];
                                    [self->_pendingPromises removeObjectForKey:item.runTimeID];
                                }
                            }
                        }
                        // Continue processing the queue.
                        [self dispatchNext];
                    });
                    return nil;
                })
                .fail(^(id error) {
                    [Logger error:@"Operation execution error (%@): %@", item.opID, error];
                    // Check for a pending promise.
                    if (item.runTimeID) {
                        QPromise *promise = self->_pendingPromises[item.runTimeID];
                        if (promise) {
                            // If a pending promise found for the current runtime ID then reject with
                            // the error and remove from the set of pending.
                            [promise reject:error];
                            [self->_pendingPromises removeObjectForKey:item.runTimeID];
                        }
                    }
                    [self dispatchNext];
                });
        }
    };
    // If already running on the dispatch queue then run the next step; otherwise dispatch
    // the next step.
    if (RunningOnDispatchQueue) {
        next();
    }
    else {
        dispatch_async(operationDispatchQueue, next);
    }
}

@end
