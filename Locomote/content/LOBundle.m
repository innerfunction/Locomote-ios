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
//  Created by Julian Goacher on 02/05/2017.
//  Copyright © 2017 Locomote.sh. All rights reserved.
//

#import "LOBundle.h"

// Test that a path is non-nil and that a file exists at the path.
#define FileExists(path) (path != nil && [[NSFileManager defaultManager] fileExistsAtPath:path])

// Assemble a dir path, file name and extension into a full path string.
#define ResourcePath(subpath, name, ext) ([[subpath stringByAppendingPathComponent:name] stringByAppendingPathExtension:ext])

@interface LOBundle ()

//- (void)_localizeTextViewChildren:(UIView *)view;

@end

@implementation LOBundle

static NSBundle *LocomoteBundle;

+ (void)initialize {
    LocomoteBundle = [LOBundle new];
}

+ (NSBundle *)locomoteBundle {
    return LocomoteBundle;
}

- (id)init {
    self = [super init];
    if (self) {
        _mainBundle = [NSBundle mainBundle];
        _provider = [LOContentProvider getInstance];
    }
    return self;
}

- (NSURL *)bundleURL {
    return _mainBundle.bundleURL;
}

- (NSURL *)resourceURL {
    return _mainBundle.resourceURL;
}

- (NSURL *)executableURL {
    return _mainBundle.executableURL;
}

- (NSURL *)privateFrameworksURL {
    return _mainBundle.privateFrameworksURL;
}

- (NSURL *)sharedFrameworksURL {
    return _mainBundle.sharedFrameworksURL;
}

- (NSURL *)sharedSupportURL {
    return _mainBundle.sharedSupportURL;
}

- (NSURL *)builtInPlugInsURL {
    return _mainBundle.builtInPlugInsURL;
}

- (NSURL *)appStoreReceiptURL {
    return _mainBundle.appStoreReceiptURL;
}

- (NSString *)bundlePath {
    return _mainBundle.bundlePath;
}

- (NSString *)resourcePath {
    return _mainBundle.resourcePath;
}

- (NSString *)executablePath {
    return _mainBundle.executablePath;
}

- (NSString *)pathForAuxiliaryExecutable:(NSString *)executableName {
    return [_mainBundle pathForAuxiliaryExecutable:executableName];
}

- (NSString *)privateFrameworksPath {
    return _mainBundle.sharedFrameworksPath;
}

- (NSString *)sharedFrameworksPath {
    return _mainBundle.sharedFrameworksPath;
}

- (NSString *)sharedSupportPath {
    return _mainBundle.sharedSupportPath;
}

- (NSString *)builtInPlugInsPath {
    return _mainBundle.builtInPlugInsPath;
}

- (NSString *)bundleIdentifier {
    return _mainBundle.bundleIdentifier;
}

- (NSDictionary<NSString *, id> *)infoDictionary {
    return _mainBundle.infoDictionary;
}

- (NSDictionary<NSString *, id> *)localizedInfoDictionary {
    return _mainBundle.localizedInfoDictionary;
}

- (nullable id)objectForInfoDictionaryKey:(NSString *)key {
    return [_mainBundle objectForInfoDictionaryKey:key];
}

- (nullable Class)classNamed:(NSString *)className {
    return [_mainBundle classNamed:className];
}

- (Class)principalClass {
    return _mainBundle.principalClass;
}

- (NSArray<NSString *> *)preferredLocalizations {
    return _mainBundle.preferredLocalizations;
}

- (NSArray<NSString *> *)localizations {
    return _mainBundle.localizations;
}

- (NSString *)developmentLocalization {
    return _mainBundle.developmentLocalization;
}

- (nullable NSURL *)URLForResource:(nullable NSString *)name withExtension:(nullable NSString *)ext {
    return [self URLForResource:name withExtension:ext subdirectory:@""];
}

- (nullable NSURL *)URLForResource:(nullable NSString *)name withExtension:(nullable NSString *)ext subdirectory:(nullable NSString *)subpath {
    NSString *rscPath = ResourcePath(subpath, name, ext);
    NSString *filePath = [_provider localCacheLocationOfPath:rscPath];
    if (FileExists(filePath)) {
        return [NSURL fileURLWithPath:filePath];
    }
    return [_mainBundle URLForResource:name withExtension:ext];
}

- (nullable NSURL *)URLForResource:(nullable NSString *)name withExtension:(nullable NSString *)ext subdirectory:(nullable NSString *)subpath localization:(nullable NSString *)localizationName {
    return [self URLForResource:name withExtension:ext subdirectory:subpath]; // TODO Use parameters for localization info?
}

/* Assume that the default implementation routes through URLForResource:
- (nullable NSArray<NSURL *> *)URLsForResourcesWithExtension:(nullable NSString *)ext subdirectory:(nullable NSString *)subpath {
    return [_mainBundle URLsForResourcesWithExtension:ext subdirectory:subpath];
}
*/

/* Assume that the default implementation routes through URLsForResourcesWithExtension:
- (nullable NSArray<NSURL *> *)URLsForResourcesWithExtension:(nullable NSString *)ext subdirectory:(nullable NSString *)subpath localization:(nullable NSString *)localizationName {
    return [_mainBundle URLsForResourcesWithExtension:ext subdirectory:subpath localization:localizationName];
}
*/

- (nullable NSString *)pathForResource:(nullable NSString *)name ofType:(nullable NSString *)ext {
    NSString *rscPath = ResourcePath(@"", name, ext);
    NSString *filePath = [_provider localCacheLocationOfPath:rscPath];
    if (FileExists(filePath)) {
        return filePath;
    }
    return [[NSBundle mainBundle] pathForResource:name ofType:ext];
}

- (nullable NSString *)pathForResource:(nullable NSString *)name ofType:(nullable NSString *)ext inDirectory:(nullable NSString *)subpath {
    NSString *path = ResourcePath(@"", name, ext);
    NSString *filePath = [_provider localCacheLocationOfPath:path];
    if (FileExists(filePath)) {
        return filePath;
    }
    return [_mainBundle pathForResource:name ofType:ext inDirectory:subpath];
}

- (nullable NSString *)pathForResource:(nullable NSString *)name ofType:(nullable NSString *)ext inDirectory:(nullable NSString *)subpath forLocalization:(nullable NSString *)localizationName {
    return [self pathForResource:name ofType:ext inDirectory:subpath];
}

- (NSArray<NSString *> *)pathsForResourcesOfType:(nullable NSString *)ext inDirectory:(nullable NSString *)subpath {
    return [_mainBundle pathsForResourcesOfType:ext inDirectory:subpath];
}

- (NSArray<NSString *> *)pathsForResourcesOfType:(nullable NSString *)ext inDirectory:(nullable NSString *)subpath forLocalization:(nullable NSString *)localizationName {
    return [_mainBundle pathsForResourcesOfType:ext inDirectory:subpath forLocalization:localizationName];
}

- (NSString *)localizedStringForKey:(NSString *)key value:(nullable NSString *)value table:(nullable NSString *)tableName {
    return [_mainBundle localizedStringForKey:key value:value table:tableName];
}

/*
- (NSArray *)loadNibNamed:(NSString *)name owner:(id)owner options:(NSDictionary *)options {
    NSArray *result = [super loadNibNamed:name owner:owner options:options];
    for (UIView *view in result) {
        [self _localizeTextViewChildren:view];
    }
    return result;
}
*/

@end
