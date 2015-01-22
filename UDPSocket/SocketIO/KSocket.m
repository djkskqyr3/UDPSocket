//
//  KSocket.m
//  KRain
//
//  Created by JamesChan on 1/5/15.
//  Copyright (c) 2015 JamesChan. All rights reserved.
//

#import "KSocket.h"
#import "GCDAsyncSocket.h"
#import "Utils.h"

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
    
    return self;
}

- (void)connectHost:(NSString*)host Port:(int)port
{
    hostClient = host;
    
    dispatch_queue_t mainQueue = dispatch_get_main_queue();
    
    asyncSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:mainQueue];
    
    DDLogInfo(@"Connecting to \"%@\" on port %d...", host, port);
    
    NSError *error = nil;    
    if (![asyncSocket connectToHost:host onPort:port withTimeout:Time_Interval error:&error])
    {
        DDLogError(@"Error connecting: %@", error);
    }
}

- (void)disconnect
{
    [asyncSocket disconnect];
}

- (BOOL)isConnected
{
    return (BOOL)asyncSocket.isConnected;
}

- (void)sendData:(NSData*)data Tag:(int)tag
{
    [asyncSocket writeData:data withTimeout:Time_Interval tag:tag];
}

- (void)sendCommand:(NSData*)data Tag:(int)tag
{
    if (data.length <= CORE_COMMAND_SIZE)
    {
        Byte *msg = (Byte*)malloc(COMMAND_TOTAL_SIZE);
        msg[0] = HEADER1;
        msg[1] = HEADER2;
        msg[2] = LENGTH;
        msg[3] = STATIC_CMD;
        msg[4] = STX;
        msg[5] = SIZE;
        msg[6] = CMD;
        msg[7] = M_PIN;
        
        Byte *tmp = (Byte*)data.bytes;
        for (int i = 0; i < data.length; i ++) {
            msg[8+i] = tmp[i];
        }
        
        Byte *clientPin = [Utils getClientPin];
        
        msg[4+DAT6] = clientPin[0] << 4 | clientPin[1] << 0;
        msg[4+DAT7] = clientPin[2] << 4 | clientPin[3] << 0;
        msg[4+DAT8] = [Utils getPIN_ID];
        
        msg[COMMAND_TOTAL_SIZE-4] = [Utils GetRfCheckNumber:msg];
        msg[COMMAND_TOTAL_SIZE-3] = ETX;
        msg[COMMAND_TOTAL_SIZE-2] = CHECKCODE;
        msg[COMMAND_TOTAL_SIZE-1] = END;
        
        [self sendData:[NSData dataWithBytes:msg length:COMMAND_TOTAL_SIZE] Tag:tag];
    }
}

#pragma mark Socket Delegate

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{
    DDLogInfo(@"socket:%p didConnectToHost:%@ port:%hu", sock, host, port);
    
    if ([_delegate respondsToSelector:@selector(connectSuccess)])
    {
        [_delegate connectSuccess];
    }
}

- (void)socket:(GCDAsyncSocket *)sock didNotConnectToHost:(NSString *)error
{
    DDLogInfo(@"socket:%p didNotConnectToHost:%@", sock, error);
    
    if ([_delegate respondsToSelector:@selector(connectFail)])
    {
        [_delegate connectFail];
    }
}

- (void)socketDidSecure:(GCDAsyncSocket *)sock
{
    DDLogInfo(@"socketDidSecure:%p", sock);
    
    NSString *requestStr = [NSString stringWithFormat:@"GET / HTTP/1.1\r\nHost: %@\r\n\r\n", hostClient];
    NSData *requestData = [requestStr dataUsingEncoding:NSUTF8StringEncoding];
    
    [sock writeData:requestData withTimeout:-1 tag:0];
    [sock readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1 tag:0];
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
    //DDLogInfo(@"socket:%p didWriteDataWithTag:%ld", sock, tag);
    [asyncSocket readDataWithTimeout:Time_Interval tag:tag];
    //[sock readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1 tag:tag];
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    //DDLogInfo(@"socket:%p didReadData:withTag:%ld", sock, tag);
   
    //DDLogInfo(@"receivedData:\n%@", data);
    
    bool WifiHaveRecFlag = false;
    Byte *msgbuf = (Byte*)malloc(data.length);
    memcpy(msgbuf, data.bytes, data.length);
    Byte *response = (Byte*)malloc(SIZE);
    
    if (data.length >= SIZE)
    {
        for (int i = 0; i <= data.length - SIZE ; i ++ ) {
            if (msgbuf[i] == STX && (msgbuf[i+SIZE-1] == ETX)) {
                memcpy(response, &msgbuf[i], SIZE);
                if ([Utils Check_Number:response] == response[INDEX_CHECKSUM])
                {
                    WifiHaveRecFlag = true;
                }
                break;
            }
        }
    }
    
    if (WifiHaveRecFlag)
    {
        WifiHaveRecFlag = false;
        switch (response[DAT0]) {
            case 0x80:
                if ([Utils Check_PIN:response])
                {
                    if ([Utils getCurrentCommand] == REFRESH_CMD)
                    {
                        [Utils GetResAllState:response];
                        
                        if ([_delegate respondsToSelector:@selector(controlDevice:)])
                        {
                            [_delegate controlDevice:REC];
                        }
                    }
                }
                break;
            case 0x58:
                if ([Utils Check_PIN:response])
                {
                    [Utils GetResCurState:response];
                    
                    if ([_delegate respondsToSelector:@selector(controlDevice:)])
                    {
                        [_delegate controlDevice:REC];
                    }
                }
                break;
            case 0x5C:
                if ([Utils Check_PIN:response])
                {
                    [Utils GetResCurRunTime:response];
                    
                    if ([_delegate respondsToSelector:@selector(controlDevice:)])
                    {
                        [_delegate controlDevice:REC];
                    }
                }
                break;
            case 0x88:
            case 0x85:
            case 0x86:
                if ([Utils Check_PIN:response])
                {
                    [Utils GetResFailInformation:response];
                    
                    if ([_delegate respondsToSelector:@selector(controlDevice:)])
                    {
                        [_delegate controlDevice:[Utils getKR_Err_Num]];
                    }
                }
                break;
            case 0x5A:
                if ([Utils Check_PIN:response])
                {
                    [Utils GetResMidboxVersion:response];
                    
                    if ([_delegate respondsToSelector:@selector(controlDevice:)])
                    {
                        [_delegate controlDevice:MID_VERSION];
                    }
                }
                break;
            case 0x61:
                if ([Utils Check_PIN:response])
                {
                    [Utils GetResSensor:response];
                    
                    if ([_delegate respondsToSelector:@selector(controlDevice:)])
                    {
                        [_delegate controlDevice:REC];
                    }
                }
                break;
            case 0x60:
                if ([Utils Check_PIN:response])
                {
                    [Utils GetResProgram:response];
                    
                    if ([_delegate respondsToSelector:@selector(controlDevice:)])
                    {
                        [_delegate controlDevice:PROGRAM_SETTING];
                    }
                }
                break;
            case 0x87:
                if ([Utils Check_PIN:response])
                {
                    [Utils GetResPinOK:response];
                    
                    if ([_delegate respondsToSelector:@selector(controlDevice:)])
                    {
                        [_delegate controlDevice:REC];
                    }
                }
                break;
            case 0x64:
                if ([Utils Check_PIN:response])
                {
                    [Utils GetResPrgFlag:response];
                    
                    if ([_delegate respondsToSelector:@selector(controlDevice:)])
                    {
                        [_delegate controlDevice:REC];
                    }
                }
                break;
            case 0x65:
                if ([Utils Check_PIN:response])
                {
                    [Utils GetResStartTime:response];
                    
                    if ([_delegate respondsToSelector:@selector(controlDevice:)])
                    {
                        [_delegate controlDevice:START_TIME_SETTING];
                    }
                }
                break;
            case 0x66:
                if ([Utils Check_PIN:response])
                {
                    [Utils GetResAllRunTime1:response];
                    
                    if ([_delegate respondsToSelector:@selector(controlDevice:)])
                    {
                        [_delegate controlDevice:REC];
                    }
                }
                break;
            case 0x67:
                if ([Utils Check_PIN:response])
                {
                    [Utils GetResAllRunTime2:response];
                    
                    if ([_delegate respondsToSelector:@selector(controlDevice:)])
                    {
                        [_delegate controlDevice:RUN_TIME_SETTING];
                    }
                }
                break;
            case 0x68:
                if ([Utils Check_PIN:response])
                {
                    [Utils GetResDayMask:response];
                    
                    if ([_delegate respondsToSelector:@selector(controlDevice:)])
                    {
                        [_delegate controlDevice:WATERING_DAYS];
                    }
                }
                break;
            case 0x69:
                if ([Utils Check_PIN:response])
                {
                    [Utils GetResStnMask:response];
                    
                    if ([_delegate respondsToSelector:@selector(controlDevice:)])
                    {
                        [_delegate controlDevice:REC];
                    }
                }
                break;
            case 0x6A:
                if ([Utils Check_PIN:response])
                {
                    [Utils GetResSpFeatMode:response];
                    
                    if ([_delegate respondsToSelector:@selector(controlDevice:)])
                    {
                        [_delegate controlDevice:REC];
                    }
                }
                break;
            case 0x70:
                if ([Utils Check_PIN:response])
                {
                    [Utils GetResYweekMask:response];
                    
                    if ([_delegate respondsToSelector:@selector(controlDevice:)])
                    {
                        [_delegate controlDevice:SET_SUSPEND];
                    }
                }
                break;
            default:
                break;
        }
    }
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
    DDLogInfo(@"socketDidDisconnect:%p withError: %@", sock, err);
    
    if ([_delegate respondsToSelector:@selector(disconnectSuccess)])
    {
        [_delegate disconnectSuccess];
    }
}

@end
