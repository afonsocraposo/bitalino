#import "BitalinoPlugin.h"
#import <BITalinoBLE/BITalinoBLE.h>

@implementation BitalinoPlugin

int sampleRate;
BITalinoBLE* bitalino;
#define BITALINO_IDENTIFIER @"4510AAEC-C465-8FFD-A266-537A9590E6EE"

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* channel = [FlutterMethodChannel
      methodChannelWithName:@"com.afonsoraposo.bitalino/bitalino"
            binaryMessenger:[registrar messenger]];
  BitalinoPlugin* instance = [[BitalinoPlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  if ([@"initialize" isEqualToString:call.method]) {
      bitalino = [[BITalinoBLE alloc] initWithUUID:BITALINO_IDENTIFIER];
      //result(TRUE);
  }else if([@"connect" isEqualToString:call.method]) {
      //result();
  } else {
    result(FlutterMethodNotImplemented);
  }
}

@end
