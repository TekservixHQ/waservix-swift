//
//  TSXWAservixClient.h
//  WAservixObjC - WAservix WhatsApp API Gateway client for Objective-C, by Tekservix.
//
//  Send WhatsApp texts, images, documents and locations from your own number.
//  You need a Tekservix account with WAservix and a connected WhatsApp number.
//  Each number has its own device API key (it starts with "wpk_") under
//  WAservix -> Devices. https://tekservix.com/waservix/
//  API reference: https://tekservix.com/waservix/docs/
//
//  MIT licensed.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Error domain for API errors. The code is the HTTP status.
FOUNDATION_EXPORT NSErrorDomain const TSXWAservixErrorDomain;
/// userInfo key holding the raw response body (NSData) of a failed call.
FOUNDATION_EXPORT NSString *const TSXWAservixErrorBodyKey;
/// The library version.
FOUNDATION_EXPORT NSString *const TSXWAservixVersion;

/// On success `data` is the API's `data` field (an NSDictionary, NSArray or other
/// JSON value); on failure `error` is set.
typedef void (^TSXWAservixCompletion)(id _Nullable data, NSError *_Nullable error);

/// WAservix WhatsApp API Gateway client for one WhatsApp number. Thread-safe.
@interface TSXWAservixClient : NSObject

/// Client for the live API.
- (instancetype)initWithAPIKey:(NSString *)apiKey;
/// Client with another base URL or session (for tests or a proxy).
- (instancetype)initWithAPIKey:(NSString *)apiKey
                       baseURL:(NSURL *)baseURL
                       session:(NSURLSession *)session NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/// `https://tekservix.com/waservix/api`
@property (class, nonatomic, readonly) NSURL *defaultBaseURL;
@property (nonatomic, readonly) NSURL *baseURL;
/// Request timeout in seconds (default 30).
@property (nonatomic) NSTimeInterval timeout;

#pragma mark Sending
// "to" is a number (+250788123456) or a group ID (ending in @g.us).

/// Any message type. Field names follow the API: text, imageUrl, videoUrl, audioUrl,
/// documentUrl, fileName, location, poll, replyTo, mentions, viewOnce.
- (NSURLSessionDataTask *)sendMessageTo:(NSString *)to
                                 fields:(NSDictionary<NSString *, id> *)fields
                             completion:(TSXWAservixCompletion)completion;
- (NSURLSessionDataTask *)sendTextTo:(NSString *)to
                                text:(NSString *)text
                          completion:(TSXWAservixCompletion)completion;
- (NSURLSessionDataTask *)sendImageTo:(NSString *)to
                             imageURL:(NSString *)imageURL
                              caption:(nullable NSString *)caption
                           completion:(TSXWAservixCompletion)completion;
- (NSURLSessionDataTask *)sendDocumentTo:(NSString *)to
                             documentURL:(NSString *)documentURL
                                fileName:(nullable NSString *)fileName
                                 caption:(nullable NSString *)caption
                              completion:(TSXWAservixCompletion)completion;
- (NSURLSessionDataTask *)sendLocationTo:(NSString *)to
                                latitude:(double)latitude
                               longitude:(double)longitude
                                    name:(nullable NSString *)name
                              completion:(TSXWAservixCompletion)completion;

#pragma mark Messages

/// Status of a sent message: queued, sent, delivered, read, played or failed.
- (NSURLSessionDataTask *)getMessageInfo:(NSInteger)messageID completion:(TSXWAservixCompletion)completion;
/// Edits a sent text (WhatsApp allows about 15 minutes).
- (NSURLSessionDataTask *)editMessage:(NSInteger)messageID text:(NSString *)text completion:(TSXWAservixCompletion)completion;
/// Deletes a message for everyone.
- (NSURLSessionDataTask *)deleteMessage:(NSInteger)messageID completion:(TSXWAservixCompletion)completion;
/// Sends a failed message again.
- (NSURLSessionDataTask *)resendMessage:(NSInteger)messageID completion:(TSXWAservixCompletion)completion;

#pragma mark Numbers, contacts and groups

/// Does this number have WhatsApp?
- (NSURLSessionDataTask *)onWhatsApp:(NSString *)phone completion:(TSXWAservixCompletion)completion;
/// Connection status of your number.
- (NSURLSessionDataTask *)getStatusWithCompletion:(TSXWAservixCompletion)completion;
/// The WhatsApp profile of your number.
- (NSURLSessionDataTask *)getUserWithCompletion:(TSXWAservixCompletion)completion;
- (NSURLSessionDataTask *)listContactsWithCompletion:(TSXWAservixCompletion)completion;
- (NSURLSessionDataTask *)getContact:(NSString *)phone completion:(TSXWAservixCompletion)completion;
- (NSURLSessionDataTask *)saveContactWithPhone:(NSString *)phone name:(NSString *)name completion:(TSXWAservixCompletion)completion;
/// Groups your number is in; IDs end in @g.us.
- (NSURLSessionDataTask *)listGroupsWithCompletion:(TSXWAservixCompletion)completion;
- (NSURLSessionDataTask *)getGroupMetadata:(NSString *)groupID completion:(TSXWAservixCompletion)completion;

#pragma mark Webhooks

/// Checks the X-Webhook-Signature header against your number's webhook secret, in constant time.
+ (BOOL)verifyWebhookSignature:(nullable NSString *)signature secret:(NSString *)secret;

#pragma mark Anything else

/// Calls any endpoint. `path` starts with "/", `body` is sent as JSON when not nil.
- (NSURLSessionDataTask *)requestWithMethod:(NSString *)method
                                       path:(NSString *)path
                                       body:(nullable id)body
                                 completion:(TSXWAservixCompletion)completion;

@end

NS_ASSUME_NONNULL_END
