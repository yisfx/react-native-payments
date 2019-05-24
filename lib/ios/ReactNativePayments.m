#import "ReactNativePayments.h"
#import <React/RCTUtils.h>
#import <React/RCTEventDispatcher.h>

@implementation ReactNativePayments
@synthesize bridge = _bridge;

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}

RCT_EXPORT_MODULE()

+ (BOOL)requiresMainQueueSetup
{
  return YES;
}

- (NSDictionary *)constantsToExport
{
    return @{
             @"canMakePayments": @([PKPaymentAuthorizationViewController canMakePayments]),
             @"supportedGateways": [GatewayManager getSupportedGateways],
             @"canMakeCcPayments": @([PKPaymentAuthorizationViewController canMakePaymentsUsingNetworks:[NSArray arrayWithObjects: PKPaymentNetworkAmex, PKPaymentNetworkMasterCard, PKPaymentNetworkVisa, nil]])
             };
}

RCT_EXPORT_METHOD(canMakeCcPayment: (NSArray *)cclisct
                  callback: (RCTResponseSenderBlock)callback)
{
    
    bool result=false;
    if(cclisct){
        for(NSString *ccType in cclisct){
            if([ccType isEqualToString:@"amex"]){
                if([PKPaymentAuthorizationViewController canMakePaymentsUsingNetworks:[NSArray arrayWithObjects:     PKPaymentNetworkAmex, nil]]){
                    result=true;
                    break;
                }
            }else if([ccType isEqualToString:@"chinaunionpay"]){
                if([PKPaymentAuthorizationViewController canMakePaymentsUsingNetworks:[NSArray arrayWithObjects: PKPaymentNetworkChinaUnionPay, nil]]){
                    result=true;
                    break;
                }
            }else if([ccType isEqualToString:@"discover"]){
                if([PKPaymentAuthorizationViewController canMakePaymentsUsingNetworks:[NSArray arrayWithObjects: PKPaymentNetworkDiscover, nil]]){
                    result=true;
                    break;
                }
            }else if([ccType isEqualToString:@"interac"]){
                if([PKPaymentAuthorizationViewController canMakePaymentsUsingNetworks:[NSArray arrayWithObjects: PKPaymentNetworkInterac, nil]]){
                    result=true;
                    break;
                }
            }else if([ccType isEqualToString:@"mastercard"]){
                if([PKPaymentAuthorizationViewController canMakePaymentsUsingNetworks:[NSArray arrayWithObjects: PKPaymentNetworkMasterCard, nil]]){
                    result=true;
                    break;
                }
            }else if([ccType isEqualToString:@"privatelabel"]){
                if([PKPaymentAuthorizationViewController canMakePaymentsUsingNetworks:[NSArray arrayWithObjects: PKPaymentNetworkPrivateLabel, nil]]){
                    result=true;
                    break;
                }
            }else if([ccType isEqualToString:@"visa"]){
                if([PKPaymentAuthorizationViewController canMakePaymentsUsingNetworks:[NSArray arrayWithObjects: PKPaymentNetworkVisa, nil]]){
                    result=true;
                    break;
                }
            }
        }
    }
    NSString *r=@"";
    if(result){
        r=@"11";
    }else{
        r=@"00";
    }
    if(callback)
        callback(@[r]);
}


RCT_EXPORT_METHOD(createPaymentRequest: (NSDictionary *)methodData
                  details: (NSDictionary *)details
                  options: (NSDictionary *)options
                  callback: (RCTResponseSenderBlock)callback)
{
    NSString *merchantId = methodData[@"merchantIdentifier"];
    NSDictionary *gatewayParameters = methodData[@"paymentMethodTokenizationParameters"][@"parameters"];
    
    if (gatewayParameters) {
        self.hasGatewayParameters = true;
        self.gatewayManager = [GatewayManager new];
        [self.gatewayManager configureGateway:gatewayParameters merchantIdentifier:merchantId];
    }
    
    self.paymentRequest = [[PKPaymentRequest alloc] init];
    self.paymentRequest.merchantIdentifier = merchantId;
    self.paymentRequest.merchantCapabilities = PKMerchantCapability3DS;
    self.paymentRequest.countryCode = methodData[@"countryCode"];
    self.paymentRequest.currencyCode = methodData[@"currencyCode"];
    self.paymentRequest.supportedNetworks = [self getSupportedNetworksFromMethodData:methodData];
    self.paymentRequest.paymentSummaryItems = [self getPaymentSummaryItemsFromDetails:details];
    self.paymentRequest.shippingMethods = [self getShippingMethodsFromDetails:details];

    [self setRequiredShippingAddressFieldsFromOptions:options];
    
    // Set options so that we can later access it.
    self.initialOptions = options;
    if(callback)
        callback(@[[NSNull null]]);
}

RCT_EXPORT_METHOD(show:(RCTResponseSenderBlock)callback)
{
    
    self.viewController = [[PKPaymentAuthorizationViewController alloc] initWithPaymentRequest: self.paymentRequest];
    self.viewController.delegate = self;
    flag=true;
    shipping=0;
    method=0;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *rootViewController = RCTPresentedViewController();
        [rootViewController presentViewController:self.viewController animated:YES completion:nil];
        callback(@[[NSNull null]]);
    });
}



RCT_EXPORT_METHOD(abort: (RCTResponseSenderBlock)callback)
{
    [self.viewController dismissViewControllerAnimated:YES completion:nil];
    flag=true;
    callback(@[[NSNull null]]);
}

RCT_EXPORT_METHOD(complete: (NSString *)paymentStatus
                  callback: (RCTResponseSenderBlock)callback)
{
    
    if ([paymentStatus isEqualToString: @"success"]) {
        callback(@[[NSNull null]]);
        self.completion(PKPaymentAuthorizationStatusSuccess);
    } else if ([paymentStatus isEqualToString: @"billingerror"]) {
        callback(@[[NSNull null]]);
        self.completion(PKPaymentAuthorizationStatusInvalidBillingPostalAddress);
    } else if ([paymentStatus isEqualToString: @"shippingerror"]) {
        callback(@[[NSNull null]]);
        self.completion(PKPaymentAuthorizationStatusInvalidShippingPostalAddress);
    } else if ([paymentStatus isEqualToString: @"contacterror"]) {
        callback(@[[NSNull null]]);
        self.completion(PKPaymentAuthorizationStatusInvalidShippingContact);
    } else {
        callback(@[[NSNull null]]);
        self.completion(PKPaymentAuthorizationStatusFailure);
    }
}


-(void) paymentAuthorizationViewControllerDidFinish:(PKPaymentAuthorizationViewController *)controller
{
    [controller dismissViewControllerAnimated:YES completion:nil];
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"NativePayments:onuserdismiss" body:nil];
}

bool flag=true;
int method=0;
int shipping=0;

RCT_EXPORT_METHOD(update:(NSDictionary *)details
                  callback: (RCTResponseSenderBlock)callback){
    NSString *result=details[@"result"];
    NSArray<PKShippingMethod *> * shippingMethods = [self getShippingMethodsFromDetails:details];
    NSArray<PKPaymentSummaryItem *> * paymentSummaryItems = [self getPaymentSummaryItemsFromDetails:details];
    
    if(flag){
        if (self.initialOptions[@"requestShipping"] && [result isEqualToString:@"shippingerror"]) {
            self.shippingContactCompletion(
                                           PKPaymentAuthorizationStatusInvalidShippingPostalAddress,
                                           shippingMethods,
                                           paymentSummaryItems
                                           );
        } else if (self.initialOptions[@"requestBilling"] && [result isEqualToString:@"billingerror"]) {
            self.shippingContactCompletion(
                                           PKPaymentAuthorizationStatusInvalidBillingPostalAddress,
                                           shippingMethods,
                                           paymentSummaryItems
                                           );
        } else if (self.initialOptions[@"requestContact"] && [result isEqualToString:@"contacterror"]) {
            self.shippingContactCompletion(
                                           PKPaymentAuthorizationStatusInvalidShippingContact,
                                           shippingMethods,
                                           paymentSummaryItems
                                           );
        }else if(self.initialOptions[@"requestShipping"] && [shippingMethods count]==0){
            self.shippingContactCompletion(
                                           PKPaymentAuthorizationStatusInvalidShippingPostalAddress,
                                           shippingMethods,
                                           paymentSummaryItems
                                           );
        }else{
            self.shippingContactCompletion(PKPaymentAuthorizationStatusSuccess,shippingMethods,paymentSummaryItems);
        }
        flag=false;
        callback(@[[NSNull null]]);
    }
}

RCT_EXPORT_METHOD(handleDetailsUpdate: (NSDictionary *)details
                  callback: (RCTResponseSenderBlock)callback)

{
    if(shipping<1 && method<1){
        return;
    }
    
    NSString *result=details[@"result"];
    
    NSArray<PKShippingMethod *> * shippingMethods = [self getShippingMethodsFromDetails:details];
    
    NSArray<PKPaymentSummaryItem *> * paymentSummaryItems = [self getPaymentSummaryItemsFromDetails:details];
    
    self.paymentRequest.paymentSummaryItems = [self getPaymentSummaryItemsFromDetails:details];
    self.paymentRequest.shippingMethods = [self getShippingMethodsFromDetails:details];
    
    if (method>0) {
        self.shippingMethodCompletion(
                                      PKPaymentAuthorizationStatusSuccess,
                                      paymentSummaryItems
                                      );
        method--;
        NSLog(@"**** method--");
        // Invalidate `self.shippingMethodCompletion`
        if(method<1) {
            method=0;
            //self.shippingMethodCompletion = nil;
        }
    }
    if (shipping>0) {
        
        // Display shipping address error when shipping is needed and shipping method count is below 1
        
        if (self.initialOptions[@"requestShipping"] && [result isEqualToString:@"shippingerror"]) {
            self.shippingContactCompletion(
                                                  PKPaymentAuthorizationStatusInvalidShippingPostalAddress,
                                                  shippingMethods,
                                                  paymentSummaryItems
                                                  );
        } else if (self.initialOptions[@"requestBilling"] && [result isEqualToString:@"billingerror"]) {
            self.shippingContactCompletion(
                                           PKPaymentAuthorizationStatusInvalidBillingPostalAddress,
                                           shippingMethods,
                                           paymentSummaryItems
                                           );
        } else if (self.initialOptions[@"requestContact"] && [result isEqualToString:@"contacterror"]) {
            self.shippingContactCompletion(
                                           PKPaymentAuthorizationStatusInvalidShippingContact,
                                           shippingMethods,
                                           paymentSummaryItems
                                           );
        } else if(self.initialOptions[@"requestShipping"] && [shippingMethods count]==0) {
            self.shippingContactCompletion(
                                           PKPaymentAuthorizationStatusInvalidShippingPostalAddress,
                                           shippingMethods,
                                           paymentSummaryItems
                                           );
        }else{
            if(!flag){
                self.shippingContactCompletion(
                                           PKPaymentAuthorizationStatusSuccess,
                                           shippingMethods,
                                           paymentSummaryItems
                                           );
            }
        }
        NSLog(@"***** shipping--");
        shipping--;
        if(shipping<1){
            shipping=0;
        }
        // Invalidate `aself.shippingContactCompletion`
        if(!flag && shipping<1){
            //self.shippingContactCompletion = nil;
        }
        
    }
    
    // Call callback

    callback(@[[NSNull null]]);
    
}
#pragma mark - PKOaymentAuthorizationViewControllerDelegate

// DELEGATES
// ---------------
- (void) paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller
                        didAuthorizePayment:(PKPayment *)payment
                                 completion:(void (^)(PKPaymentAuthorizationStatus))completion
{
    // Store completion for later use
    self.completion = completion;
    
    if (self.hasGatewayParameters) {
        [self.gatewayManager createTokenWithPayment:payment completion:^(NSString * _Nullable token, NSError * _Nullable error) {
            if (error) {
                [self handleGatewayError:error];
                return;
            }

            [self handleUserAccept:payment paymentToken:token];
        }];
    } else {
        [self handleUserAccept:payment paymentToken:nil];
    }
}


// Shipping Contact
- (void) paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller
                   didSelectShippingContact:(PKContact *)contact
                                 completion:(nonnull void (^)(PKPaymentAuthorizationStatus, NSArray<PKShippingMethod *> * _Nonnull, NSArray<PKPaymentSummaryItem *> * _Nonnull))completion
{
    shipping++;
    NSLog(@"**** shipping++");
    self.shippingContactCompletion = completion;
    if(self.shippingContactCompletion){
        NSLog(@"2222");
    }
    CNPostalAddress *postalAddress = contact.postalAddress;
    NSLog(postalAddress.postalCode);
    
    // street, subAdministrativeArea, and subLocality are supressed for privacy
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"NativePayments:onshippingaddresschange"
                                                    body:@{
                                                           @"recipient": [NSNull null],
                                                           @"organization": [NSNull null],
                                                           @"addressLine":postalAddress.street,
                                                           @"city": postalAddress.city,
                                                           @"region": postalAddress.state,
                                                           @"country": [postalAddress.ISOCountryCode uppercaseString],
                                                           @"postalCode": postalAddress.postalCode,
                                                           @"phone": [NSNull null],
                                                           @"languageCode": [NSNull null],
                                                           @"sortingCode": [NSNull null],
                                                           @"dependentLocality": [NSNull null]
                                                           }];
}

// Shipping Method delegates
- (void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller
                   didSelectShippingMethod:(PKShippingMethod *)shippingMethod
                                completion:(void (^)(PKPaymentAuthorizationStatus, NSArray<PKPaymentSummaryItem *> * _Nonnull))completion
{
    method+=2;
    NSLog(@"**** method++");
    self.shippingMethodCompletion = completion;
    
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"NativePayments:onshippingoptionchange" body:@{
                                                                                                         @"selectedShippingOptionId": shippingMethod.identifier
                                                                                                         }];
    
    
}

// PRIVATE METHODS
// https://developer.apple.com/reference/passkit/pkpaymentnetwork
// ---------------
- (NSArray *_Nonnull)getSupportedNetworksFromMethodData:(NSDictionary *_Nonnull)methodData
{
    NSMutableDictionary *supportedNetworksMapping = [[NSMutableDictionary alloc] init];
    
    CGFloat iOSVersion = [[[UIDevice currentDevice] systemVersion] floatValue];
    
    if (iOSVersion >= 8) {
        [supportedNetworksMapping setObject:PKPaymentNetworkAmex forKey:@"amex"];
        [supportedNetworksMapping setObject:PKPaymentNetworkMasterCard forKey:@"mastercard"];
        [supportedNetworksMapping setObject:PKPaymentNetworkVisa forKey:@"visa"];
    }
    
    if (iOSVersion >= 9) {
        [supportedNetworksMapping setObject:PKPaymentNetworkDiscover forKey:@"discover"];
        [supportedNetworksMapping setObject:PKPaymentNetworkPrivateLabel forKey:@"privatelabel"];
    }
    
    if (iOSVersion >= 9.2) {
        [supportedNetworksMapping setObject:PKPaymentNetworkChinaUnionPay forKey:@"chinaunionpay"];
        [supportedNetworksMapping setObject:PKPaymentNetworkInterac forKey:@"interac"];
    }
    
    if (iOSVersion >= 10.1) {
        [supportedNetworksMapping setObject:PKPaymentNetworkJCB forKey:@"jcb"];
        [supportedNetworksMapping setObject:PKPaymentNetworkSuica forKey:@"suica"];
    }
    
    if (iOSVersion >= 10.3) {
        [supportedNetworksMapping setObject:PKPaymentNetworkCarteBancaire forKey:@"cartebancaires"];
        [supportedNetworksMapping setObject:PKPaymentNetworkIDCredit forKey:@"idcredit"];
        [supportedNetworksMapping setObject:PKPaymentNetworkQuicPay forKey:@"quicpay"];
    }
    
    if (iOSVersion >= 11) {
        [supportedNetworksMapping setObject:PKPaymentNetworkCarteBancaires forKey:@"cartebancaires"];
    }
    
    // Setup supportedNetworks
    NSArray *jsSupportedNetworks = methodData[@"supportedNetworks"];
    NSMutableArray *supportedNetworks = [NSMutableArray array];
    for (NSString *supportedNetwork in jsSupportedNetworks) {
        [supportedNetworks addObject: supportedNetworksMapping[supportedNetwork]];
    }
    
    return supportedNetworks;
}

- (NSArray<PKPaymentSummaryItem *> *_Nonnull)getPaymentSummaryItemsFromDetails:(NSDictionary *_Nonnull)details
{
    // Setup `paymentSummaryItems` array
    NSMutableArray <PKPaymentSummaryItem *> * paymentSummaryItems = [NSMutableArray array];
    
    // Add `displayItems` to `paymentSummaryItems`
    NSArray *displayItems = details[@"displayItems"];
    if (displayItems.count > 0) {
        for (NSDictionary *displayItem in displayItems) {
            [paymentSummaryItems addObject: [self convertDisplayItemToPaymentSummaryItem:displayItem]];
        }
    }
    
    // Add total to `paymentSummaryItems`
    NSDictionary *total = details[@"total"];
    [paymentSummaryItems addObject: [self convertDisplayItemToPaymentSummaryItem:total]];
    
    return paymentSummaryItems;
}

- (NSArray<PKShippingMethod *> *_Nonnull)getShippingMethodsFromDetails:(NSDictionary *_Nonnull)details
{
    // Setup `shippingMethods` array
    NSMutableArray <PKShippingMethod *> * shippingMethods = [NSMutableArray array];
    
    // Add `shippingOptions` to `shippingMethods`
    if(details[@"shippingOptions"]==@"[]"){
        NSLog(@"debugger");
    }
    NSArray *shippingOptions = details[@"shippingOptions"];
    if (shippingOptions.count > 0) {
        for (NSDictionary *shippingOption in shippingOptions) {
            [shippingMethods addObject: [self convertShippingOptionToShippingMethod:shippingOption]];
        }
    }
    
    return shippingMethods;
}

- (PKPaymentSummaryItem *_Nonnull)convertDisplayItemToPaymentSummaryItem:(NSDictionary *_Nonnull)displayItem;
{
    NSDecimalNumber *decimalNumberAmount = [NSDecimalNumber decimalNumberWithString:displayItem[@"amount"][@"value"]];
    PKPaymentSummaryItem *paymentSummaryItem = [PKPaymentSummaryItem summaryItemWithLabel:displayItem[@"label"] amount:decimalNumberAmount];
    
    return paymentSummaryItem;
}

- (PKShippingMethod *_Nonnull)convertShippingOptionToShippingMethod:(NSDictionary *_Nonnull)shippingOption
{
    PKShippingMethod *shippingMethod = [PKShippingMethod summaryItemWithLabel:shippingOption[@"label"] amount:[NSDecimalNumber decimalNumberWithString: shippingOption[@"amount"][@"value"]]];
    shippingMethod.identifier = shippingOption[@"id"];
    
    // shippingOption.detail is not part of the PaymentRequest spec.
    if ([shippingOption[@"detail"] isKindOfClass:[NSString class]]) {
        shippingMethod.detail = shippingOption[@"detail"];
    } else {
        shippingMethod.detail = @"";
    }
    
    //shippingMethod
    return shippingMethod;
}

- (void)setRequiredShippingAddressFieldsFromOptions:(NSDictionary *_Nonnull)options
{
    // Request Shipping
    if (options[@"requestShipping"]) {
        self.paymentRequest.requiredShippingAddressFields = PKAddressFieldPostalAddress;
    }
    
    if (options[@"requestPayerName"]) {
        self.paymentRequest.requiredShippingAddressFields = self.paymentRequest.requiredShippingAddressFields | PKAddressFieldName;
    }
    
    if (options[@"requestPayerPhone"]) {
        self.paymentRequest.requiredShippingAddressFields = self.paymentRequest.requiredShippingAddressFields | PKAddressFieldPhone;
    }
    
    if (options[@"requestPayerEmail"]) {
        self.paymentRequest.requiredShippingAddressFields = self.paymentRequest.requiredShippingAddressFields | PKAddressFieldEmail;
    }
    if (options[@"requestBilling"]) {
        self.paymentRequest.requiredBillingAddressFields = PKAddressFieldPostalAddress;
    }
}

- (void)handleUserAccept:(PKPayment *_Nonnull)payment
            paymentToken:(NSString *_Nullable)token
{
    NSString *transactionId = payment.token.transactionIdentifier;
    NSString *payerEmail=payment.shippingContact.emailAddress;
    NSString *payerName=payment.shippingContact.name.givenName;
    payerName=[payerName stringByAppendingString:@" "];
    payerName=[payerName stringByAppendingString:payment.shippingContact.name
               .familyName];
    NSString *phone=payment.shippingContact.phoneNumber.stringValue;
    NSString *street=payment.shippingContact.postalAddress.street;
    NSString *postalCode=payment.shippingContact.postalAddress.postalCode;
    NSMutableDictionary *paymentResponse = [[NSMutableDictionary alloc]initWithCapacity:3];
    NSDictionary *dic=[NSJSONSerialization JSONObjectWithData:payment.token.paymentData options:NSJSONReadingAllowFragments error:nil];


    //billingAddress----Country\State\City\Address1\ZipCode(postcode)\ContactWith\Phone
    NSString *billingphone = payment.billingContact.phoneNumber.stringValue;
    NSString *billingpayerName=payment.billingContact.name.givenName;
    billingpayerName=[billingpayerName stringByAppendingString:@" "];
    billingpayerName=[billingpayerName stringByAppendingString:payment.billingContact.name
               .familyName];
    NSString *billingstreet=payment.billingContact.postalAddress.street;
    NSString *billingcity=payment.billingContact.postalAddress.city;
    NSString *billingstate=payment.billingContact.postalAddress.state;
    NSString *billingzipcode=payment.billingContact.postalAddress.postalCode;
    NSString *billingcountry=payment.billingContact.postalAddress.country;
    
    
    ///
    
    NSDictionary *header=[dic objectForKey:@"header"];
    NSString *publicKey=[header objectForKey:@"ephemeralPublicKey"];
    NSString *data=[dic objectForKey:@"data"];
    
    
    if(TARGET_IPHONE_SIMULATOR){
        if(!publicKey){
            publicKey=@"SIMULATOR";
        }
        if(!data){
            data=@"SIMULATOR";
        }
    }
    if(billingphone==nil){
        billingphone=@"SIMULATOR";
    }
    
    [paymentResponse setObject:billingphone forKey:@"billingphone"];
    [paymentResponse setObject:billingpayerName forKey:@"billingpayerName"];
    [paymentResponse setObject:billingstreet forKey:@"billingstreet"];
    [paymentResponse setObject:billingcity forKey:@"billingcity"];
    [paymentResponse setObject:billingstate forKey:@"billingstate"];
    [paymentResponse setObject:billingzipcode forKey:@"billingzipcode"];
    [paymentResponse setObject:billingcountry forKey:@"billingcountry"];
    
    [paymentResponse setObject:street forKey:@"addressLine"];
    [paymentResponse setObject:phone forKey:@"payerPhone"];
    [paymentResponse setObject:payerName forKey:@"payerName"];
    [paymentResponse setObject:publicKey forKey:@"paymentData"];
    [paymentResponse setObject:data forKey:@"paymentToken"];
    [paymentResponse setObject:transactionId forKey:@"transactionIdentifier"];
    [paymentResponse setObject:payerEmail forKey:@"payerEmail"];
    [paymentResponse setObject:postalCode forKey:@"postalCode"];
    
    //if (token) {
    //    [paymentResponse setObject:token forKey:@"paymentToken"];
    //}
    
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"NativePayments:onuseraccept"
                                                    body:paymentResponse
     ];
}

- (void)handleGatewayError:(NSError *_Nonnull)error
{
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"NativePayments:ongatewayerror"
                                                    body: @{
                                                            @"error": [error localizedDescription]
                                                            }
     ];
}

@end
