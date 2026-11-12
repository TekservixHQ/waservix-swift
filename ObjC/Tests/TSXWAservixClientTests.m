#import <XCTest/XCTest.h>

#import "TSXWAservixClient.h"

@interface TSXWAservixClientTests : XCTestCase
@end

@implementation TSXWAservixClientTests

- (void)testWebhookSecret {
    XCTAssertTrue([TSXWAservixClient verifyWebhookSignature:@"s3cret-value" secret:@"s3cret-value"]);
    XCTAssertFalse([TSXWAservixClient verifyWebhookSignature:@"s3cret-valuf" secret:@"s3cret-value"]);
    XCTAssertFalse([TSXWAservixClient verifyWebhookSignature:@"short" secret:@"s3cret-value"]);
    XCTAssertFalse([TSXWAservixClient verifyWebhookSignature:@"" secret:@""]);
    XCTAssertFalse([TSXWAservixClient verifyWebhookSignature:nil secret:@"s3cret-value"]);
}

- (void)testBaseURLIsTrimmed {
    NSURL *base = [NSURL URLWithString:@"https://example.com/api//"];
    TSXWAservixClient *c = [[TSXWAservixClient alloc] initWithAPIKey:@"wpk_x" baseURL:base session:[NSURLSession sharedSession]];
    XCTAssertEqualObjects(c.baseURL.absoluteString, @"https://example.com/api");
    XCTAssertEqualObjects(TSXWAservixClient.defaultBaseURL.absoluteString, @"https://tekservix.com/waservix/api");
}

- (void)testLiveInvalidKeyGives401 {
    XCTestExpectation *done = [self expectationWithDescription:@"status"];
    TSXWAservixClient *c = [[TSXWAservixClient alloc] initWithAPIKey:@"wpk_invalid_objc_test"];
    [c getStatusWithCompletion:^(id data, NSError *error) {
        XCTAssertNil(data);
        XCTAssertEqualObjects(error.domain, TSXWAservixErrorDomain);
        XCTAssertEqual(error.code, 401);
        XCTAssertNotNil(error.userInfo[TSXWAservixErrorBodyKey]);
        [done fulfill];
    }];
    [self waitForExpectationsWithTimeout:30 handler:nil];
}

@end
