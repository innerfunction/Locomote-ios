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

#import <Foundation/Foundation.h>
#import "LOCommand.h"
#import "SCService.h"
#import "Q.h"

/// A pending command item.
@interface LOCommandQueueItem : NSObject

/// The command to be executed.
@property (nonatomic, strong) id<LOCommand> command;
/// The command's arguments.
@property (nonatomic, strong) NSArray *args;
/**
 * An command's runtime identity.
 * Follow-on commands share the same identity as the command that spawned
 * them.
 */
@property (nonatomic, strong) NSNumber *runTimeID;

/// Initialize a new item with the specified command and arguments.
- (id)initWithCommand:(id<LOCommand>)command args:(NSArray *)args;

@end

@interface LOCommandQueue : NSObject <SCService> {
    /**
     * A flag indicating whether the queue is started.
     * Commands won't be processed unless and until the queue is running.
     */
    BOOL _running;
    /// A queue of pending commands.
    NSMutableArray<LOCommandQueueItem *> *_queue;
    /// A map of pending command completion promises.
    NSMutableDictionary<NSNumber *,QPromise *> *_pendingPromises;
    /// A map of registered command names.
    NSMutableDictionary<NSString *,id<LOCommand>> *_registeredCommands;
}

/// Register a command name.
- (void)registerCommand:(id<LOCommand>)command usingName:(NSString *)name;
/// Create a command queue item from a command name and its arguments.
- (LOCommandQueueItem *)makeQueueItemForCommandName:(NSString *)name arguments:(NSArray *)args;
/**
 * Append a new command to the end of the queue.
 * The command will be appended to the end of the queue, providing the same command
 * with the same arguments doesn't already exist on the queue. The command will be
 * executed after all commands ahead of it are executed.
 * The method returns a deferred promise which resolves once the command, and any
 * follow on command it generates, have completed execution.
 */
- (QPromise *)queueCommand:(id<LOCommand>)command arguments:(NSArray *)args;
/// Append a new command to the queue, by name.
- (QPromise *)queueCommandWithName:(NSString *)name arguments:(NSArray *)args;
/**
 * Clear all pending commands on the queue.
 * If any command is currently executing then it will complete, but any follow-on
 * commands it returns will be discarded.
 * Returns a deferred promise which resolves when the queue is cleared.
 */
- (QPromise *)clearPending;
/// Return the command dispatch queue.
+ (dispatch_queue_t)getDispatchQueue;

@end
