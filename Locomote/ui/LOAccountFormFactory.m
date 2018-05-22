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
//  Created by Julian Goacher on 22/05/2018.
//  Copyright © 2018 Locomote.sh. All rights reserved.
//

#import "LOAccountFormFactory.h"
#import "LOFormViewController.h"
#import "LOUserAccountManager.h"
#import "SCAppContainer.h"
#import "SCConfiguration.h"
#import "SCContainer.h"
#import "SCViewBehaviour.h"
#import "NSDictionary+SC.h"

#define ValueOrNSNull(value) (value == nil ? [NSNull null] : value)

@implementation LOAccountFormFactory

- (id)initWithUserAccountManager:(id<LOUserAccountManager>)userAccountManager httpClient:(SCHTTPClient *)httpClient {

    NSDictionary *baseConfiguration = @{
        @"-ios-class":      @"LOFormViewController",
        @"form": @{
            @"method":      @"POST",
            @"submitURL":   @"$SubmitURL",
            @"isEnabled":   @"$IsEnabled",
            @"fields":      @"$Fields"
        }
    };
    self = [super initWithBaseConfiguration:baseConfiguration];
    if (self) {
    
        self.userAccountManager = userAccountManager;
        self.httpClient = httpClient;
        
        // Initialize form patterns.
        NSDictionary *fieldNames = self.userAccountManager.standardFieldNames;
        self.stdParams = @{
            @"ImageField": @{
                @"-ios-class":              @"LOFormImageField"
            },
            @"FirstnameField": @{
                @"-ios-class":              @"LOFormTextField",
                @"name":                    fieldNames[LOUserAccountFirstName],
                @"title":                   @"First name",
                @"titleLabel": @{
                    @"style":               @"$TitleStyle"
                },
                @"input": @{
                    @"autocapitalization":  @"words",
                    @"autocorrection":      @NO,
                    @"style":               @"$InputStyle"
                }
            },
            @"LastnameField": @{
                @"-ios-class":              @"LOFormTextField",
                @"name":                    fieldNames[LOUserAccountLastName],
                @"title":                   @"Last name",
                @"titleLabel": @{
                    @"style":               @"$TitleStyle"
                },
                @"input": @{
                    @"autocapitalization":  @"words",
                    @"autocorrection":      @NO,
                    @"style":               @"$InputStyle"
                }
            },
            @"EmailField": @{
                @"-ios-class":              @"LOFormTextField",
                @"name":                    fieldNames[LOUserAccountEMail],
                @"isRequired":              @YES,
                @"title":                   @"Email",
                @"titleLabel": @{
                    @"style":               @"$TitleStyle"
                },
                @"input": @{
                    @"keyboard":            @"email",
                    @"autocapitalization":  @"none",
                    @"autocorrection":      @NO,
                    @"style":               @"$InputStyle"
                }
            },
            @"UsernameField": @{
                @"-ios-class":              @"LOFormTextField",
                @"name":                    fieldNames[LOUserAccountUsername],
                @"isRequired":              @YES,
                @"title":                   @"Username",
                @"titleLabel": @{
                    @"style":               @"$TitleStyle"
                },
                @"input": @{
                    @"autocapitalization":  @"none",
                    @"autocorrection":      @NO,
                    @"style":               @"$InputStyle"
                }
            },
            @"PasswordField": @{
                @"-ios-class":              @"LOFormTextField",
                @"name":                    fieldNames[LOUserAccountPassword],
                @"isPassword":              @YES,
                @"isRequired":              @YES,
                @"title":                   @"Password",
                @"titleLabel": @{
                    @"style":               @"$TitleStyle"
                }
            },
            @"ConfirmPasswordField": @{
                @"-ios-class":              @"LOFormTextField",
                @"name":                    fieldNames[LOUserAccountConfirmPW],
                @"isPassword":              @YES,
                @"title":                   @"Confirm password",
                @"hasSameValueAs":          @"user_pass",
                @"titleLabel": @{
                    @"style":               @"$TitleStyle"
                }
            },
            @"ProfileIDField": @{
                @"-ios-class":              @"LOFormHiddenField",
                @"name":                    fieldNames[LOUserAccountProfileID]
            },
            @"SubmitField": @{
                @"-ios-class":              @"LOSubmitField",
                @"title":                   @"Login",
                @"titleLabel": @{
                    @"style":               @"$TitleStyle"
                }
            }
        };
    }
    return self;
}

- (id)buildObjectWithConfiguration:(id<SCConfiguration>)configuration
                       inContainer:(id<SCContainer>)container
                        identifier:(NSString *)identifier {
    
    NSString *formType = [configuration getValueAsString:@"formType"];
    NSString *submitURL = @"";
    NSString *loginAction = [configuration getValueAsString:@"loginAction"];
    BOOL isEnabled = YES;

    id<SCViewBehaviour> viewBehaviour = nil;
    LOFormViewDataEvent onSubmitOk;
    LOFormViewErrorEvent onSubmitError;

    if ([@"login" isEqualToString:formType]) {
        submitURL = _userAccountManager.authenticationURL;
        BOOL checkForLogin = [configuration getValueAsBoolean:@"checkForLogin" defaultValue:YES];
        if (checkForLogin) {
            viewBehaviour = [[LOLoginBehaviour alloc] initWithUserAccountManager:_userAccountManager loginAction:loginAction];
        }
        //isEnabled = NO;
        onSubmitOk = ^(LOFormView *form, NSDictionary *data) {
            // Store user credentials & user info
            [_userAccountManager storeUserProfile:data[@"profile"]];
            [_userAccountManager storeUserCredentials:form.inputValues];
            // Dispatch the specified event
            [[SCAppContainer getAppContainer] postMessage:loginAction sender:form];
        };
        onSubmitError = ^(LOFormView *form, id data) {
            NSString *action = [NSString stringWithFormat:@"post:toast+message=%@", @"Login%20failure"];
            [[SCAppContainer getAppContainer] postMessage:action sender:form];
        };
    }
    else if ([@"new-account" isEqualToString:formType]) {
        submitURL = _userAccountManager.newAccountURL;
        onSubmitOk = ^(LOFormView *form, NSDictionary *data) {
            // Store user credentials & user info
            [_userAccountManager storeUserCredentials:form.inputValues];
            [_userAccountManager storeUserProfile:data[@"profile"]];
            // Dispatch the specified event
            [[SCAppContainer getAppContainer] postMessage:loginAction sender:form];
        };
        onSubmitError = ^(LOFormView *form, id data) {
            NSString *message = data[@"error"];
            if (!message) {
                message = @"Account creation failure";
            }
            message = [message stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]];
            NSString *action = [NSString stringWithFormat:@"post:toast+message=%@", message];
            [[SCAppContainer getAppContainer] postMessage:action sender:form];
        };
    }
    else if ([@"profile" isEqualToString:formType]) {
        submitURL = _userAccountManager.accountProfileURL;
        onSubmitOk = ^(LOFormView *form, NSDictionary *data) {
            // Update stored user info
            [_userAccountManager storeUserProfile:data[@"profile"]];
            NSString *action = [NSString stringWithFormat:@"post:toast+message=%@", @"Account%20updated"];
            [[SCAppContainer getAppContainer] postMessage:action sender:form];
        };
        onSubmitError = ^(LOFormView *form, id data) {
            NSString *message = data[@"error"];
            if (!message) {
                message = @"Account update failure";
            }
            message = [message stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]];
            NSString *action = [NSString stringWithFormat:@"post:toast+message=%@", message];
            [[SCAppContainer getAppContainer] postMessage:action sender:form];
        };
    }
    NSDictionary *params = [_stdParams extendWith:@{
        @"SubmitURL":   submitURL,
        @"IsEnabled":   [NSNumber numberWithBool:isEnabled],
        @"Fields":      ValueOrNSNull([configuration getValue:@"fields"]),
        @"TitleStyle":  ValueOrNSNull([configuration getValue:@"titleStyle"]),
        @"InputStyle":  ValueOrNSNull([configuration getValue:@"inputStyle"])
    }];
    configuration = [configuration configurationWithKeysExcluded:@[ @"-factory", @"formType", @"fields" ]];
    LOFormViewController *formView = (LOFormViewController *)[self buildObjectWithConfiguration:configuration
                                                                                    inContainer:container
                                                                                 withParameters:params
                                                                                     identifier:identifier];
    formView.behaviour          = viewBehaviour;
    formView.form.onSubmitOk    = onSubmitOk;
    formView.form.onSubmitError = onSubmitError;
    formView.form.httpClient    = _httpClient;
    if ([@"profile" isEqualToString:formType]) {
        formView.form.inputValues = [_userAccountManager getUserProfile];
    }
    return formView;
}

@end

@implementation LOLoginBehaviour

- (id)initWithUserAccountManager:(id<LOUserAccountManager>)userAccountManager loginAction:(NSString *)loginAction {
    self = [super init];
    self.userAccountManager = userAccountManager;
    self.loginAction = loginAction;
    return self;
}

- (void)viewDidAppear {
    // Check if user already logged in, if so then dispatch a specified event.
    if ([_userAccountManager isAuthenticated]) {
        [[SCAppContainer getAppContainer] postMessage:_loginAction sender:self.viewController];
    }
}

@end
