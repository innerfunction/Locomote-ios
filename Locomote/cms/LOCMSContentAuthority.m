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

#import "LOCMSContentAuthority.h"
#import "LOCMSRepository.h"
#import "LOContentProvider.h"
#import "LOContentRequest.h"
#import "LOContentResponse.h"
#import "SCResource.h"
#import "NSDictionary+SC.h"

@interface LOCMSContentRequest : NSObject <LOContentRequest>

- (id)initWithAuthority:(LOCMSContentAuthority *)authority path:(NSString *)path parameters:(NSDictionary *)parameters;

@end

@interface LONSURLProtocolResponse : NSObject <LOContentResponse> {
    __weak NSMutableSet *_liveResponses;
    NSURLProtocol *_protocol;
}

- (id)initWithNSURLProtocol:(NSURLProtocol *)protocol liveResponses:(NSMutableSet *)liveResponses;

@end

@interface LOSchemeHandlerResponse : SCResource <LOContentResponse> {
    NSMutableData *_buffer;
}

@end

@interface LOCMSContentAuthority ()

/// Write a content reponse for the specified path.
- (void)writeResponse:(id<LOContentResponse>)response
              forPath:(NSString *)path
           parameters:(NSDictionary *)parameters;

@end

@implementation LOCMSContentAuthority

@synthesize requestHandlers=_requestHandlers;

- (id)init {
    self = [super init];
    if (self) {
        _liveResponses = [NSMutableSet new];
        _dispatcher    = [[LORequestDispatcher alloc] initWithHost:self];
        _repositories  = @{};
        // By default, refresh every minute.
        _refreshInterval = 1.0f;
    }
    return self;
}

- (void)addRepository:(LOCMSRepository *)repository {
    _repositories = [_repositories dictionaryWithAddedObject:repository forKey:repository.basePath];
}

- (void)completeSetup {
    self.localCachePaths = [[LOLocalCachePaths alloc] initWithSettings:_provider.localCachePaths suffix:_authorityName];
    // Each repository key specifies the base path the repository is mounted under.
    // Generate a list of repo keys ordered longest to shortest, before generating a request
    // handler mapping for each repository based on its base path. (Keys are ordered longest
    // first so that more specific repo paths take precedence over less specific paths).
    NSArray *keys = [_repositories keysSortedByValueUsingComparator:^NSComparisonResult(NSString *key1, NSString *key2) {
        NSUInteger len1 = [key1 length], len2 = [key2 length];
        return (len1 < len2) ? NSOrderedDescending : ((len1 > len2) ? NSOrderedAscending : NSOrderedSame);
    }];
    // Generate request handler mappings.
    NSMutableArray *mappings = [NSMutableArray new];
    for (id key in keys) {
        // Read the repository.
        LOCMSRepository *repository = _repositories[key];
        // Generate a file path pattern using the repo base path (note that base path will have a
        // trailing slash).
        NSString *path = [NSString stringWithFormat:@"%@**/*", repository.basePath];
        // Create the mapping and add to the list.
        LORequestHandlerMapping *mapping = [[LORequestHandlerMapping alloc] initWithPath:path handler:repository];
        [mappings addObject:mapping];
        // Pass a reference to this authority to the repository.
        repository.authority = self;
    }
    // Set the request handler mappings.
    self.requestHandlers = mappings;
    // Complete setup of each content repository.
    for (LOCMSRepository *repository in [_repositories allValues]) {
        [repository completeSetup];
    }
}

- (QPromise *)start {
    // Start each content repository.
    for (LOCMSRepository *repository in [_repositories allValues]) {
        [repository start];
    }
    // Schedule content refreshes.
    if (_refreshInterval > 0) {
        [NSTimer scheduledTimerWithTimeInterval:(_refreshInterval * 60.0f)
                                         target:self
                                       selector:@selector(syncContent)
                                       userInfo:nil
                                        repeats:YES];
    }
    
    return [self syncContent];
}

#pragma mark - SCIOCTypeInspectable

- (NSDictionary *)collectionMemberTypeInfo {
    return @{
        @"requestHandlers": [LORequestHandlerMapping class]
    };
}

#pragma mark - LOContentAuthority

- (void)handleURLProtocolRequest:(NSURLProtocol *)protocol {
    [_liveResponses addObject:protocol];
    LONSURLProtocolResponse *response = [[LONSURLProtocolResponse alloc] initWithNSURLProtocol:protocol
                                                                                 liveResponses:_liveResponses];
    NSURL *url = protocol.request.URL;
    
    // Parse the URL's scheme and path parts as a compound URI; this is to allow encoding of
    // request parameters in the compound URI format - i.e. +p1@v1+p2@v2 etc.
    SCCompoundURI *uri = [[SCCompoundURI alloc] initWithScheme:url.scheme name:url.path];
    
    // NOTE URI handler only available in content management SDK.
    NSDictionary *parameters = @{};
    if( self.uriHandler ) {
        parameters = [self.uriHandler dereferenceParameters:uri];
    }
    
    [self writeResponse:response
                forPath:url.path
             parameters:parameters];
}

- (void)cancelURLProtocolRequest:(NSURLProtocol *)protocol {
    [_liveResponses removeObject:protocol];
}

- (BOOL)hasContentForPath:(NSString *)path parameters:(NSDictionary *)parameters {
    // (TODO: Find the LOCMSRepository handling the path and delegate to it)
    return NO;
}

- (NSString *)localCacheLocationOfPath:(NSString *)path parameters:(NSDictionary *)parameters {
    // (TODO: Find the LOCMSRepository handling the path and delegate to it)
    return nil;
}

- (id)contentForPath:(NSString *)path parameters:(NSDictionary *)parameters {
    LOSchemeHandlerResponse *response = [LOSchemeHandlerResponse new];
    [self writeResponse:response
                forPath:path
             parameters:parameters];
    return response;
}

- (void)writeResponse:(id<LOContentResponse>)response
              forPath:(NSString *)path
           parameters:(NSDictionary *)parameters {
    
    id<LOContentRequest> request = [[LOCMSContentRequest alloc] initWithAuthority:self
                                                                             path:path
                                                                       parameters:parameters];
    [_dispatcher dispatchRequest:request response:response];
}

- (QPromise *)syncContent {
    NSMutableArray *promises = [NSMutableArray new];
    for (id key in _repositories) {
        LOCMSRepository *repository = _repositories[key];
        [promises addObject:[repository syncContent]];
    }
    return [Q all:promises];
}

@end

@implementation LOCMSContentRequest

@synthesize authority=_authority, path=_path, parameters=_parameters, pathParameters=_pathParameters;

- (id)initWithAuthority:(LOCMSContentAuthority *)authority path:(NSString *)path parameters:(NSDictionary *)parameters {
    self = [super init];
    self.authority = authority;
    self.path = path;
    self.parameters = parameters;
    self.pathParameters = [NSDictionary new];
    return self;
}

@end

@implementation LONSURLProtocolResponse

- (id)initWithNSURLProtocol:(NSURLProtocol *)protocol liveResponses:(NSMutableSet *)liveResponses {
    self = [super init];
    if (self) {
        _protocol = protocol;
        _liveResponses = liveResponses;
    }
    return self;
}

- (void)respondWithData:(NSData *)data mimeType:(NSString *)mimeType cachePolicy:(NSURLCacheStoragePolicy)policy {
    if ([_liveResponses containsObject:_protocol]) {
        id<NSURLProtocolClient> client = _protocol.client;
        NSURLResponse *response = [[NSURLResponse alloc] initWithURL:_protocol.request.URL
                                                            MIMEType:mimeType
                                               expectedContentLength:data.length
                                                    textEncodingName:nil];
        [client URLProtocol:_protocol didReceiveResponse:response cacheStoragePolicy:policy];
        [client URLProtocol:_protocol didLoadData:data];
        [client URLProtocolDidFinishLoading:_protocol];
        [_liveResponses removeObject:self];
    }
}

- (void)respondWithMimeType:(NSString *)mimeType cacheStoragePolicy:(NSURLCacheStoragePolicy)policy {
    if ([_liveResponses containsObject:_protocol]) {
        id<NSURLProtocolClient> client = _protocol.client;
        NSURLResponse *response = [[NSURLResponse alloc] initWithURL:_protocol.request.URL
                                                            MIMEType:mimeType
                                               expectedContentLength:-1
                                                    textEncodingName:nil];
        [client URLProtocol:_protocol didReceiveResponse:response cacheStoragePolicy:policy];
    }
}

- (void)sendData:(NSData *)data {
    if ([_liveResponses containsObject:_protocol]) {
        id<NSURLProtocolClient> client = _protocol.client;
        [client URLProtocol:_protocol didLoadData:data];
    }
}

- (void)done {
    if ([_liveResponses containsObject:_protocol]) {
        id<NSURLProtocolClient> client = _protocol.client;
        [client URLProtocolDidFinishLoading:_protocol];
        [_liveResponses removeObject:_protocol];
    }
}

- (void)respondWithError:(NSError *)error {
    if ([_liveResponses containsObject:_protocol]) {
        [_protocol.client URLProtocol:_protocol didFailWithError:error];
        [_liveResponses removeObject:_protocol];
    }
}

- (void)respondWithStringData:(NSString *)stringData mimeType:(NSString *)mimeType cachePolicy:(NSURLCacheStoragePolicy)cachePolicy {
    NSData *data = [stringData dataUsingEncoding:NSUTF8StringEncoding];
    [self respondWithData:data mimeType:mimeType cachePolicy:cachePolicy];
}

- (void)respondWithJSONData:(id)jsonData cachePolicy:(NSURLCacheStoragePolicy)cachePolicy {
    NSData *data = [NSJSONSerialization dataWithJSONObject:jsonData
                                                   options:0
                                                     error:nil];
    [self respondWithData:data mimeType:@"application/json" cachePolicy:cachePolicy];
}

- (void)respondWithFileData:(NSString *)filepath mimeType:(NSString *)mimeType cachePolicy:(NSURLCacheStoragePolicy)cachePolicy {
    NSData *data = [NSData dataWithContentsOfFile:filepath];
    [self respondWithData:data mimeType:mimeType cachePolicy:cachePolicy];
}

@end

@implementation LOSchemeHandlerResponse

- (NSURL *)externalURL {
    NSString *uri = [NSString stringWithFormat:@"%@:%@", self.uri.scheme, self.uri.name];
    return [NSURL URLWithString:uri];
}

- (void)respondWithData:(NSData *)data mimeType:(NSString *)mimeType cachePolicy:(NSURLCacheStoragePolicy)policy {
    // TODO: Allow SCResource to report MIME types?
    self.data = data;
}

- (void)respondWithMimeType:(NSString *)mimeType cacheStoragePolicy:(NSURLCacheStoragePolicy)policy {
    // TODO: Allow SCResource to report MIME types?
    _buffer = [NSMutableData new];
}

- (void)sendData:(NSData *)data {
    [_buffer appendData:data];
}

- (void)done {
    self.data = _buffer;
    _buffer = nil;
}

- (void)respondWithError:(NSError *)error {
    // TODO: Should errors be reported through the SCResource interface?
    _buffer = nil;
}

- (void)respondWithStringData:(NSString *)stringData mimeType:(NSString *)mimeType cachePolicy:(NSURLCacheStoragePolicy)cachePolicy {
    NSData *data = [stringData dataUsingEncoding:NSUTF8StringEncoding];
    [self respondWithData:data mimeType:mimeType cachePolicy:cachePolicy];
}

- (void)respondWithJSONData:(id)jsonData cachePolicy:(NSURLCacheStoragePolicy)cachePolicy {
    NSData *data = [NSJSONSerialization dataWithJSONObject:jsonData
                                                   options:0
                                                     error:nil];
    [self respondWithData:data mimeType:@"application/json" cachePolicy:cachePolicy];
}

- (void)respondWithFileData:(NSString *)filepath mimeType:(NSString *)mimeType cachePolicy:(NSURLCacheStoragePolicy)cachePolicy {
    NSData *data = [NSData dataWithContentsOfFile:filepath];
    [self respondWithData:data mimeType:mimeType cachePolicy:cachePolicy];
}

@end
