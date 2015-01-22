//
//  KSocket.h
//  KRain
//
//  Created by JamesChan on 1/5/15.
//  Copyright (c) 2015 JamesChan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DDLog.h"
#import "DDTTYLogger.h"

#define K_HOST              @"116.31.93.147"
#define K_PORT              5555

static const int ddLogLevel = LOG_LEVEL_INFO;

#define Time_Interval       30

@class GCDAsyncSocket;

@protocol KSocketDelegate <NSObject>

@optional

- (void)connectSuccess;
- (void)connectFail;
- (void)disconnectSuccess;
- (void)controlDevice:(int)s;

@end

@interface KSocket : NSObject
{
    GCDAsyncSocket  *asyncSocket;
    NSString        *hostClient;
    NSThread        *readThread;
}

@property (nonatomic, strong) id<KSocketDelegate> delegate;

+ (instancetype)sharedInstance;

- (void)connectHost:(NSString*)host Port:(int)port;
- (void)disconnect;

- (BOOL)isConnected;

- (void)sendData:(NSData*)data Tag:(int)tag;
- (void)sendCommand:(NSData*)data Tag:(int)tag;

@end
