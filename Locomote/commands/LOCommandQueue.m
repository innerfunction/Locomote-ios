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
//  Created by Julian Goacher on 30/03/2017.
//  Copyright © 2017 InnerFunction. All rights reserved.
//

#import "LOCommandQueue.h"
#import "SCLogger.h"
#import "NSDictionary+SC.h"
#import "NSString+SC.h"

static SCLogger *Logger;
static dispatch_queue_t commandDispatchQueue;
static void *commandDispatchQueueKey = "sh.locomote.CommandQueue";

// Macro to test whether a method is called on the command dispatch queue.
#define RunningOnDispatchQueue  (dispatch_get_specific(commandDispatchQueueKey) != NULL)

@interface LOCommandQueue ()

/// Execute the next queued command.
- (void)dispatchNext;

@end

@implementation LOCommandQueueItem

- (id)initWithCommand:(id<LOCommand>)command args:(NSArray *)args {
    self = [super init];
    self.command = command;
    self.args = args;
    return self;
}

- (BOOL)isEqual:(id)object {
    if ([object isKindOfClass:[LOCommandQueueItem class]]) {
        LOCommandQueueItem *item = (LOCommandQueueItem *)object;
        // Note that we test command equality using command object identity.
        return _command == item.command && [_args isEqualToArray:item.args];
    }
    return NO;
}

- (NSUInteger)hash {
    return [_command hash] ^ [_args hash];
}

@end

@implementation LOCommandQueue

+ (void)initialize {
    Logger = [[SCLogger alloc] initWithTag:@"LOCommandQueue"];
    commandDispatchQueue = dispatch_queue_create( commandDispatchQueueKey, 0);
    dispatch_queue_set_specific(commandDispatchQueue, commandDispatchQueueKey, commandDispatchQueueKey, NULL);
}

+ (dispatch_queue_t)getDispatchQueue {
    return commandDispatchQueue;
}

- (id)init {
    self = [super init];
    if (self) {
        _running = NO;
        _queue = [NSMutableArray new];
        _pendingPromises = [NSMutableDictionary new];
        _registeredCommands = [NSMutableDictionary new];
    }
    return self;
}

- (void)registerCommand:(id<LOCommand>)command usingName:(NSString *)name {
    _registeredCommands[name] = command;
}

- (LOCommandQueueItem *)makeQueueItemForCommandName:(NSString *)name arguments:(NSArray *)args {
    id<LOCommand> command = _registeredCommands[name];
    if (command) {
        return [[LOCommandQueueItem alloc] initWithCommand:command args:args];
    }
    return nil;
}

- (void)queueCommand:(id<LOCommand>)command arguments:(NSArray *)args {
    // Modify the queue on the dispatch queue.
    dispatch_async(commandDispatchQueue, ^{
        LOCommandQueueItem *item = [[LOCommandQueueItem alloc] initWithCommand:command args:args];
        // Test whether the same command already exists on the queue.
        if (![_queue containsObject:item]) {
            // Add new command to the queue.
            [_queue addObject:item];
            // Execute if the queue was empty (if not empty then a
            // command is currently executing, and will eventually
            // dispatch the new command once the rest of the queue
            // is executed).
            if ([_queue count] == 1) {
                [self dispatchNext];
            }
        }
    });
}

- (void)queueCommandWithName:(NSString *)name arguments:(NSArray *)args {
    id<LOCommand> command = _registeredCommands[name];
    if (command) {
        [self queueCommand:command arguments:args];
    }
}

- (QPromise *)executeCommand:(id<LOCommand>)command arguments:(NSArray *)args {
    LOCommandQueueItem *item = [[LOCommandQueueItem alloc] initWithCommand:command args:args];
    QPromise *promise = [QPromise new];
    dispatch_async(commandDispatchQueue, ^{
        // Remove any existing copy of the command already on the queue.
        [_queue removeObject:item];
        // Add the command to the head of the queue.
        [_queue insertObject:item atIndex:0];
        // Give the command a runtime identity.
        item.runTimeID = [NSNumber numberWithInteger:[item hash]];
        // Add the command's promise to the map of pending.
        _pendingPromises[item.runTimeID] = promise;
        // Execute if the queue was empty.
        if ([_queue count] == 1) {
            [self dispatchNext];
        }
    });
    return promise;
}

- (QPromise *)clearPending {
    QPromise *promise = [QPromise new];
    dispatch_async(commandDispatchQueue, ^{
        [_queue removeAllObjects];
        [promise resolve:self];
    });
    return promise;
}

- (QPromise *)clearPendingAndExecuteCommand:(id<LOCommand>)command arguments:(NSArray *)args {
    return [self clearPending]
    .then((id)^(id result) {
        return [self executeCommand:command arguments:args];
    });
}

- (QPromise *)clearPendingAndExecuteCommandWithName:(NSString *)name arguments:(NSArray *)args {
    id<LOCommand> command = _registeredCommands[name];
    if (command) {
        return [self clearPendingAndExecuteCommand:command arguments:args];
    }
    return [Q reject:[NSString stringWithFormat:@"Unrecognized command: %@", name ]];
}

#pragma mark - SCService

- (void)startService {
    _running = YES;
    // Commands may be added to the queue before it is started, execute them
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
    void (^next)() = ^() {
        // Check that there are pending commands.
        if ([_queue count] > 0) {
            // Read and execute the next pending command.
            LOCommandQueueItem *item = _queue[0];
            [item.command execute:item.args]
                .then((id)^(NSArray *followOns) {
                    dispatch_async(commandDispatchQueue, ^{
                        // Remove the completed command from the queue.
                        [_queue removeObjectAtIndex:0];
                        // Add any follow-on commands to the end of the queue.
                        if ([followOns count] > 0) {
                            for (LOCommandQueueItem *followOn in followOns) {
                                if (![_queue containsObject:followOn]) {
                                    [_queue addObject:followOn];
                                    // Give the follow-on the same runtime ID as
                                    // its parent command.
                                    followOn.runTimeID = item.runTimeID;
                                }
                            }
                            // If completed command has a runtime ID then check whether
                            // a pending promise needs to be resolved.
                            if (item.runTimeID) {
                                QPromise *promise = _pendingPromises[item.runTimeID];
                                if (promise) {
                                    // Check for pending commands with the same runtime ID.
                                    BOOL pending = NO;
                                    for (LOCommandQueueItem *pendingItem in _queue) {
                                        if ([item.runTimeID isEqual:pendingItem.runTimeID]) {
                                            pending = YES;
                                            break;
                                        }
                                    }
                                    // If no pending commands with the same runtime ID then
                                    // resolve the promise and remove it from the set of pending.
                                    if (!pending) {
                                        [promise resolve:nil];
                                        [_pendingPromises removeObjectForKey:item.runTimeID];
                                    }
                                }
                            }
                        }
                        // Continue processing the queue.
                        [self dispatchNext];
                    });
                    return nil;
                })
                .fail(^(id error) {
                    [Logger error:@"Error executing command %@ %@: %@", item.command.name, item.args, error];
                    // Check for a pending promise.
                    if (item.runTimeID) {
                        QPromise *promise = _pendingPromises[item.runTimeID];
                        if (promise) {
                            // If a pending promise found for the current runtime ID then reject with
                            // the error and remove from the set of pending.
                            [promise reject:error];
                            [_pendingPromises removeObjectForKey:item.runTimeID];
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
        dispatch_async(commandDispatchQueue, next);
    }
}

@end
