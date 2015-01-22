//
//  KSocket.m
//  UDPSocket
//
//  Created by JamesChan on 1/5/15.
//  Copyright (c) 2015 JamesChan. All rights reserved.
//

#import "KSocket.h"
#import "GCDAsyncUdpSocket.h"

@implementation KSocket

+ (instancetype)sharedInstance
{
    static KSocket *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] init];
    });
    return _sharedInstance;
}

- (id)init
{
    self = [super init];
    
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    
    asyncSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    
    tag = 0;
    err = nil;
    
    return self;
}

- (BOOL)connect:(NSString*)host port:(int)port
{
    NSError *error = nil;
    if (![asyncSocket bindToPort:port error:&error])
    {
        err = error;
        DDLogInfo(@"Error binding: %@", error);
        return NO;
    }
    
    if (![asyncSocket beginReceiving:&error])
    {
        err = error;
        DDLogInfo(@"Error receiving: %@", error);
        return NO;
    }
    
    peerAddress = host;
    peerPort    = port;
    
    isRunning   = YES;
    
    return YES;
}

- (void)disconnect
{
    [asyncSocket close];
    isRunning   = NO;
    
    DDLogInfo(@"Stopped Udp server");
}

- (BOOL)isRunning
{
    return isRunning;
}

- (void)sendData:(NSData*)data
{
    [asyncSocket sendData:data toHost:peerAddress port:peerPort withTimeout:-1 tag:tag];
    
    DDLogInfo(@"SENT (%i): %@", (int)tag, data);
    
    tag++;
}

- (NSError*)currentError
{
    return err;
}

#pragma mark Socket Delegate

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data
      fromAddress:(NSData *)address
withFilterContext:(id)filterContext
{
    if (!isRunning) return;
    
    NSString *host = nil;
    uint16_t port = 0;
    [GCDAsyncUdpSocket getHost:&host port:&port fromAddress:address];
    
    DDLogInfo(@"RECV: message from: %@:%hu", host, port);
    
    if ([_delegate respondsToSelector:@selector(onRecvData:from:)])
    {
        [_delegate onRecvData:data from:host];
    }
}

@end
