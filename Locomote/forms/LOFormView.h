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
//  Created by Julian Goacher on 12/02/2016.
//  Copyright © 2016 InnerFunction. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LOFormField.h"
#import "SCHTTPClient.h"

typedef void (^LOFormViewDataEvent)(LOFormView *, id);
typedef void (^LOFormViewErrorEvent)(LOFormView *, NSError *);

/**
 * Protocol implemented by form fields which can indicate form loading status.
 */
@protocol LOFormLoadingIndicator <NSObject>

- (void)showFormLoading:(BOOL)loading;

@end

@interface LOFormView : UITableView <UITableViewDataSource, UITableViewDelegate> {
    NSInteger _focusedFieldIdx;
    UIEdgeInsets _defaultInsets;
    NSDictionary *_defaultValues;
    NSDictionary *_inputValues;
    id<LOFormLoadingIndicator> _loadingIndicator;
}

/** The list of form fields. */
@property (nonatomic, strong) NSArray *fields;
/** The form submit method, e.g. GET or POST. */
@property (nonatomic, strong) NSString *method;
/** The URL to submit the form to. */
@property (nonatomic, strong) NSString *submitURL;
/** An internal URI to post when submitting the form. */
@property (nonatomic, strong) NSString *submitURI;
/** A dictionary containing values for all named input fields. */
@property (nonatomic, strong) NSDictionary *inputValues;
/** Flag specifying whether the form is enabled or not. */
@property (nonatomic, assign) BOOL isEnabled;
/** A HTTP client to use when submitting the form to a URL. */
@property (nonatomic, strong) SCHTTPClient *httpClient;

@property (nonatomic, copy) LOFormViewDataEvent onBeforeSubmit;
@property (nonatomic, copy) LOFormViewErrorEvent onSubmitRequestError;
@property (nonatomic, copy) LOFormViewDataEvent onSubmitError;
@property (nonatomic, copy) LOFormViewDataEvent onSubmitOk;

// The view controller the form is displayed within. This is needed by some field types to
// e.g. present modal dialogs.
@property (nonatomic, weak) UIViewController *viewController;

/** Get the current value of a named field. */
- (id)getFieldValue:(NSString *)name;
/** Get the currently focused field. */
- (LOFormField *)getFocusedField;
/** Clear the current field focus. */
- (void)clearFieldFocus;
/** Move field focus to the next focusable field. */
- (void)moveFocusToNextField;
/** Reset all fields to the original values. */
- (void)reset;
/**
 * Validate all field values.
 * If any field is invalid then moves field focus to the first invalid field, and then returns false.
 */
- (BOOL)validate;
/**
 * Submit the form.
 * Validates the form before submitting. Returns true if the form is valid and was submitted.
 */
- (BOOL)submit;
/**
 * Before submit event callback.
 */
- (void)beforeSubmit;
/**
 * Update the form's visible state to show that it is submitting.
 */
- (void)submitting:(BOOL)submitting;
/**
 * Submit event callback.
 * Called if the request failed below the application layer.
 */
- (void)submitRequestError:(NSError *)error;
/**
 * Test if a submit response is an application level error.
 */
- (BOOL)isSubmitErrorResponse:(SCHTTPClientResponse *)response;
/**
 * Submit event callback.
 * Called if an application level error occurs on submit.
 */
- (void)submitError:(SCHTTPClientResponse *)response;
/**
 * Submit event callback.
 * Called if the submit request is successful.
 */
- (void)submitOk:(SCHTTPClientResponse *)response;
/**
 * Display a notification of a form error.
 */
- (void)notifyError:(NSString *)message;
/**
 * Notify the form of a field resize.
 */
- (void)notifyFormFieldResize:(LOFormField *)field;
/**
 * Return a list of the fields on this form within the same name group.
 */
- (NSArray *)getFieldsInNameGroup:(NSString *)name;

@end
