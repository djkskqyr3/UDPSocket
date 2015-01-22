//
//  KSocket.h
//  UDPSocket
//
//  Created by JamesChan on 1/5/15.
//  Copyright (c) 2015 JamesChan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DDLog.h"
#import "DDTTYLogger.h"

static const int ddLogLevel = LOG_LEVEL_INFO;

#define Time_Interval       30

@class GCDAsyncUdpSocket;

@protocol KSocketDelegate <NSObject>

@optional

- (void)onRecvData:(NSData*)data from:(NSString*)from;

@end

@interface KSocket : NSObject
{
    GCDAsyncUdpSocket   *asyncSocket;
    
    BOOL                isRunning;
    
    NSString            *peerAddress;
    int                 peerPort;
    
    int                 tag;
    
    NSError             *err;
}

@property (nonatomic, strong) id<KSocketDelegate> delegate;

+ (instancetype)sharedInstance;

- (BOOL)connect:(NSString*)host port:(int)port;
- (void)disconnect;

- (BOOL)isRunning;

- (void)sendData:(NSData*)data;

- (NSError*)currentError;


@end
