//
//  TSXWAservixClient.m
//  WAservixObjC. MIT licensed.
//

#import "TSXWAservixClient.h"

NSErrorDomain const TSXWAservixErrorDomain = @"com.tekservix.waservix";
NSString *const TSXWAservixErrorBodyKey = @"TSXWAservixErrorBody";
NSString *const TSXWAservixVersion = @"1.0.0";

@interface TSXWAservixClient ()
@property (nonatomic, copy) NSString *apiKey;
@property (nonatomic, strong) NSURLSession *session;
@end

@implementation TSXWAservixClient

+ (NSURL *)defaultBaseURL {
    return [NSURL URLWithString:@"https://tekservix.com/waservix/api"];
}

- (instancetype)initWithAPIKey:(NSString *)apiKey {
    return [self initWithAPIKey:apiKey baseURL:[[self class] defaultBaseURL] session:[NSURLSession sharedSession]];
}

- (instancetype)initWithAPIKey:(NSString *)apiKey baseURL:(NSURL *)baseURL session:(NSURLSession *)session {
    NSParameterAssert(apiKey.length > 0);
    if ((self = [super init])) {
        _apiKey = [apiKey copy];
        NSString *base = baseURL.absoluteString;
        while ([base hasSuffix:@"/"]) base = [base substringToIndex:base.length - 1];
        _baseURL = [NSURL URLWithString:base];
        _session = session;
        _timeout = 30;
    }
    return self;
}

/// Percent-encodes a path segment (a phone number such as +250788123456).
static NSString *TSXEscape(NSString *s) {
    NSString *trimmed = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:
                               @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"];
    return [trimmed stringByAddingPercentEncodingWithAllowedCharacters:allowed] ?: trimmed;
}

#pragma mark Core

- (NSURLSessionDataTask *)requestWithMethod:(NSString *)method
                                       path:(NSString *)path
                                       body:(id)body
                                 completion:(TSXWAservixCompletion)completion {
    NSURL *url = [NSURL URLWithString:[self.baseURL.absoluteString stringByAppendingString:path]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = method;
    request.timeoutInterval = self.timeout;
    [request setValue:[@"Bearer " stringByAppendingString:self.apiKey] forHTTPHeaderField:@"Authorization"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:[@"waservix-objc/" stringByAppendingString:TSXWAservixVersion] forHTTPHeaderField:@"User-Agent"];
    if (body) {
        NSError *jsonError = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:body options:0 error:&jsonError];
        if (!data) {
            NSURLSessionDataTask *noop = [self.session dataTaskWithURL:url];
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, jsonError); });
            return noop;
        }
        request.HTTPBody = data;
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    }
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request
                                                 completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }
        NSInteger status = [response isKindOfClass:[NSHTTPURLResponse class]] ? ((NSHTTPURLResponse *)response).statusCode : 0;
        id json = data.length ? [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingFragmentsAllowed error:NULL] : nil;
        if (status < 200 || status >= 300) {
            NSString *message = nil;
            if ([json isKindOfClass:[NSDictionary class]] && [json[@"message"] isKindOfClass:[NSString class]]) {
                message = json[@"message"];
            }
            NSMutableDictionary *info = [NSMutableDictionary dictionary];
            info[NSLocalizedDescriptionKey] = [NSString stringWithFormat:@"WAservix API error %ld: %@", (long)status,
                                               message ?: [NSHTTPURLResponse localizedStringForStatusCode:status]];
            if (data) info[TSXWAservixErrorBodyKey] = data;
            completion(nil, [NSError errorWithDomain:TSXWAservixErrorDomain code:status userInfo:info]);
            return;
        }
        if ([json isKindOfClass:[NSDictionary class]] && json[@"data"] != nil) {
            json = json[@"data"];
        }
        completion([json isKindOfClass:[NSNull class]] ? nil : json, nil);
    }];
    [task resume];
    return task;
}

- (NSURLSessionDataTask *)get:(NSString *)path completion:(TSXWAservixCompletion)completion {
    return [self requestWithMethod:@"GET" path:path body:nil completion:completion];
}

#pragma mark Sending

- (NSURLSessionDataTask *)sendMessageTo:(NSString *)to
                                 fields:(NSDictionary<NSString *, id> *)fields
                             completion:(TSXWAservixCompletion)completion {
    NSMutableDictionary *body = [NSMutableDictionary dictionaryWithDictionary:fields ?: @{}];
    body[@"to"] = to ?: @"";
    [body removeObjectsForKeys:[body allKeysForObject:[NSNull null]]];
    return [self requestWithMethod:@"POST" path:@"/send-message" body:body completion:completion];
}

- (NSURLSessionDataTask *)sendTextTo:(NSString *)to text:(NSString *)text completion:(TSXWAservixCompletion)completion {
    return [self sendMessageTo:to fields:@{@"text": text ?: @""} completion:completion];
}

- (NSURLSessionDataTask *)sendImageTo:(NSString *)to
                             imageURL:(NSString *)imageURL
                              caption:(NSString *)caption
                           completion:(TSXWAservixCompletion)completion {
    NSMutableDictionary *f = [@{@"imageUrl": imageURL ?: @""} mutableCopy];
    if (caption) f[@"text"] = caption;
    return [self sendMessageTo:to fields:f completion:completion];
}

- (NSURLSessionDataTask *)sendDocumentTo:(NSString *)to
                             documentURL:(NSString *)documentURL
                                fileName:(NSString *)fileName
                                 caption:(NSString *)caption
                              completion:(TSXWAservixCompletion)completion {
    NSMutableDictionary *f = [@{@"documentUrl": documentURL ?: @""} mutableCopy];
    if (fileName) f[@"fileName"] = fileName;
    if (caption) f[@"text"] = caption;
    return [self sendMessageTo:to fields:f completion:completion];
}

- (NSURLSessionDataTask *)sendLocationTo:(NSString *)to
                                latitude:(double)latitude
                               longitude:(double)longitude
                                    name:(NSString *)name
                              completion:(TSXWAservixCompletion)completion {
    NSMutableDictionary *loc = [@{@"latitude": @(latitude), @"longitude": @(longitude)} mutableCopy];
    if (name) loc[@"name"] = name;
    return [self sendMessageTo:to fields:@{@"location": loc} completion:completion];
}

#pragma mark Messages

- (NSURLSessionDataTask *)getMessageInfo:(NSInteger)messageID completion:(TSXWAservixCompletion)completion {
    return [self get:[NSString stringWithFormat:@"/messages/%ld/info", (long)messageID] completion:completion];
}

- (NSURLSessionDataTask *)editMessage:(NSInteger)messageID text:(NSString *)text completion:(TSXWAservixCompletion)completion {
    return [self requestWithMethod:@"PUT" path:[NSString stringWithFormat:@"/messages/%ld", (long)messageID]
                              body:@{@"text": text ?: @""} completion:completion];
}

- (NSURLSessionDataTask *)deleteMessage:(NSInteger)messageID completion:(TSXWAservixCompletion)completion {
    return [self requestWithMethod:@"DELETE" path:[NSString stringWithFormat:@"/messages/%ld", (long)messageID] body:nil completion:completion];
}

- (NSURLSessionDataTask *)resendMessage:(NSInteger)messageID completion:(TSXWAservixCompletion)completion {
    return [self requestWithMethod:@"POST" path:[NSString stringWithFormat:@"/messages/%ld/resend", (long)messageID] body:nil completion:completion];
}

#pragma mark Numbers, contacts and groups

- (NSURLSessionDataTask *)onWhatsApp:(NSString *)phone completion:(TSXWAservixCompletion)completion {
    return [self get:[@"/on-whatsapp/" stringByAppendingString:TSXEscape(phone ?: @"")] completion:completion];
}

- (NSURLSessionDataTask *)getStatusWithCompletion:(TSXWAservixCompletion)completion {
    return [self get:@"/status" completion:completion];
}

- (NSURLSessionDataTask *)getUserWithCompletion:(TSXWAservixCompletion)completion {
    return [self get:@"/user" completion:completion];
}

- (NSURLSessionDataTask *)listContactsWithCompletion:(TSXWAservixCompletion)completion {
    return [self get:@"/contacts" completion:completion];
}

- (NSURLSessionDataTask *)getContact:(NSString *)phone completion:(TSXWAservixCompletion)completion {
    return [self get:[@"/contacts/" stringByAppendingString:TSXEscape(phone ?: @"")] completion:completion];
}

- (NSURLSessionDataTask *)saveContactWithPhone:(NSString *)phone name:(NSString *)name completion:(TSXWAservixCompletion)completion {
    return [self requestWithMethod:@"PUT" path:@"/contacts" body:@{@"phone": phone ?: @"", @"name": name ?: @""} completion:completion];
}

- (NSURLSessionDataTask *)listGroupsWithCompletion:(TSXWAservixCompletion)completion {
    return [self get:@"/groups" completion:completion];
}

- (NSURLSessionDataTask *)getGroupMetadata:(NSString *)groupID completion:(TSXWAservixCompletion)completion {
    // The group ID (…@g.us) is sent as is.
    NSString *gid = [groupID ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    return [self get:[NSString stringWithFormat:@"/groups/%@/metadata", gid] completion:completion];
}

#pragma mark Webhooks

+ (BOOL)verifyWebhookSignature:(NSString *)signature secret:(NSString *)secret {
    if (signature.length == 0 || secret.length == 0) return NO;
    NSData *a = [signature dataUsingEncoding:NSUTF8StringEncoding];
    NSData *b = [secret dataUsingEncoding:NSUTF8StringEncoding];
    if (a.length != b.length) return NO;
    const unsigned char *pa = a.bytes, *pb = b.bytes;
    unsigned char diff = 0;
    for (NSUInteger i = 0; i < a.length; i++) diff |= (unsigned char)(pa[i] ^ pb[i]);
    return diff == 0;
}

@end
