#import "BitalinoPlugin.h"

#define BITALINO_IDENTIFIER @"DC33B7A6-EA9F-BE9E-47A2-B016CD98CBEE"

@implementation BitalinoPlugin{
    FlutterResult _connectResult;
    //FlutterResult _batteryResult;
    FlutterMethodChannel* _channel;
}

- (instancetype)initWithChannel:(FlutterMethodChannel*)channel
{
    self = [super init];
    if (self) {
        _channel = channel;
    }
    return self;
}

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* channel = [FlutterMethodChannel
      methodChannelWithName:@"com.afonsoraposo.bitalino/bitalino"
            binaryMessenger:[registrar messenger]];
  BitalinoPlugin* instance = [[BitalinoPlugin alloc] initWithChannel:channel];
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  if ([@"initialize" isEqualToString:call.method]) {
      sampleRate = 1;
      
      bitalino = [[BITalinoBLE alloc] initWithUUID:BITALINO_IDENTIFIER];
      bitalino.delegate=self;
      
      result(@YES);
      
  }else if([@"connect" isEqualToString:call.method]) {
      @try
      {
          _connectResult = result;
          if(![bitalino isConnected]){
              [bitalino scanAndConnect];
          } else{
              [bitalino disconnect];
          }
          
      }
      @catch(id exception) {
          NSLog(@"%@", [exception reason]);
          _connectResult = nil;
          result([FlutterError errorWithCode:@"" message:[exception reason] details:[exception details]]);
      }
      
  }else if([@"version" isEqualToString:call.method]) {
      result([bitalino version]);
      
  /*
   NOT WORKING, CRASHES APP
   }else if([@"batteryThreshold" isEqualToString:call.method]) {
      @try
      {
          _batteryResult = result;
          NSNumber *threshold = call.arguments[@"threshold"];
          NSLog(@"%@", threshold);
          [bitalino setBatteryThreshold:10];
       }
       @catch(id exception) {
           NSLog(@"%@", [exception reason]);
           _batteryResult = nil;
           result([FlutterError errorWithCode:@"" message:[exception reason] details:[exception details]]);
       }
  */
  } else {
    result(FlutterMethodNotImplemented);
  }
}


#pragma BITalino delegates
-(void)bitalinoDidConnect:(BITalinoBLE *)bitalino{
    _connectResult(@YES);
    _connectResult = nil;
}

-(void)bitalinoDidDisconnect:(BITalinoBLE *)bitalino{
    // disconnect
    [_channel invokeMethod:@"lostConnection" arguments:nil];
    NSLog(@"disconnected :(");
}

-(void)bitalinoBatteryThresholdUpdated:(BITalinoBLE *)bitalino{
    /*
    _batteryResult(@YES);
    _batteryResult = nil;
     */
}

-(void)bitalinoBatteryDigitalOutputsUpdated:(BITalinoBLE *)bitalino{
    //
}

-(void)bitalinoRecordingStarted:(BITalinoBLE *)bitalino{
    //
}

-(void)bitalinoRecordingStopped:(BITalinoBLE *)bitalino{
    //
}

@end
