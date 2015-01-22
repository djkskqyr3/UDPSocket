//
//  ViewController.m
//  UDPSocket
//
//  Created by JamesChan on 1/23/15.
//  Copyright (c) 2015 JamesChan. All rights reserved.
//

#import "ViewController.h"

// Socket
#import "KSocket.h"

#define K_PORT 5555

@interface ViewController () <KSocketDelegate, UITextFieldDelegate>
{
    KSocket         *socket;
}

@property (weak, nonatomic) IBOutlet UITextField    *txfPeerIP;
@property (weak, nonatomic) IBOutlet UIButton       *btnConnect;
@property (weak, nonatomic) IBOutlet UIButton       *btnSend;
@property (weak, nonatomic) IBOutlet UITextField    *txfSend;
@property (weak, nonatomic) IBOutlet UITextView     *txvRecv;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    socket = [KSocket sharedInstance];
    socket.delegate = self;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)btnConnect_Action:(id)sender
{
    if ([socket isRunning])
    {
        [socket disconnect];
        [self setConnected:NO];
    }
    else
    {
        if (self.txfPeerIP.text == nil || [self.txfPeerIP.text isEqualToString:@""])
            return;
        
        if ([socket connect:self.txfPeerIP.text port:K_PORT])
        {
             [self setConnected:YES];
        }
    }
}

- (IBAction)btnSend_Action:(id)sender
{
    if ([socket isRunning] == NO)
        return;
    
    if (self.txfSend.text == nil || [self.txfSend.text isEqualToString:@""])
        return;
    
    NSData *data = [self.txfSend.text dataUsingEncoding:NSUTF8StringEncoding];
    [socket sendData:data];
    
    self.txfSend.text = @"";
}

- (void)setConnected:(BOOL)connected
{
    if (connected)
    {
        [self.btnConnect setTitle:@"Disconnect" forState:UIControlStateNormal];
        [self.btnConnect setBackgroundColor:[UIColor greenColor]];
    }
    else
    {
        [self.btnConnect setTitle:@"Connect" forState:UIControlStateNormal];
        [self.btnConnect setBackgroundColor:[UIColor whiteColor]];
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self.txfPeerIP resignFirstResponder];
    [self.txfSend resignFirstResponder];
    return YES;
}

#pragma mark - KSocketDelegate Methods

- (void)onRecvData:(NSData*)data from:(NSString*)from;
{
    NSString *msg = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    self.txvRecv.text = [self.txvRecv.text stringByAppendingString:msg];
}

@end
