#import "BitalinoPlugin.h"
#import <Flutter/Flutter.h>

@implementation DataStreamHandler
- (FlutterError*)onListenWithArguments:(id)arguments eventSink:(FlutterEventSink)eventSink {
    self.eventSink = eventSink;
    return nil;
}

- (FlutterError*)onCancelWithArguments:(id)arguments {
    self.eventSink = nil;
    return nil;
}

- (void) sendFrame:(BITalinoFrame *)frame {
    if(self.eventSink) {
        NSMutableDictionary *dataBuffer = [NSMutableDictionary dictionary];
        dataBuffer[@"sequence"] = [NSNumber numberWithInt:(int)[frame seq]];
        dataBuffer[@"analog"] = [NSArray arrayWithObjects:[NSNumber numberWithInt:(int)[frame a0]], [NSNumber numberWithInt:(int)[frame a1]], [NSNumber numberWithInt:(int)[frame a2]], [NSNumber numberWithInt:(int)[frame a3]], [NSNumber numberWithInt:(int)[frame a4]], [NSNumber numberWithInt:(int)[frame a5]], nil];
        dataBuffer[@"digital"] = [NSArray arrayWithObjects:[NSNumber numberWithInt:(int)[frame d0]],[NSNumber numberWithInt:(int)[frame d1]], [NSNumber numberWithInt:(int)[frame d2]], [NSNumber numberWithInt:(int)[frame d3]], nil];

        self.eventSink(dataBuffer);
    }
}
@end

@implementation BitalinoPlugin{
    FlutterResult _connectResult;
    FlutterResult _disconnectResult;
    FlutterResult _batteryResult;
    FlutterResult _triggerResult;
    FlutterResult _startResult;
    FlutterResult _stopResult;
    FlutterMethodChannel* _channel;
}

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    BitalinoPlugin* instance = [[BitalinoPlugin alloc] init];
    
    FlutterMethodChannel* channel = [FlutterMethodChannel
      methodChannelWithName:@"com.afonsoraposo.bitalino/bitalino"
            binaryMessenger:[registrar messenger]];
    [instance setChannel:channel];
    [registrar addMethodCallDelegate:instance channel:channel];
    
    // Data stream channel
    instance.dataStreamHandler = [DataStreamHandler new];
    FlutterEventChannel* dataStreamChannel = [FlutterEventChannel eventChannelWithName:@"com.afonsoraposo.bitalino/dataStream" binaryMessenger:[registrar messenger]];
    [dataStreamChannel setStreamHandler:instance.dataStreamHandler];
}

- (void)setChannel:(FlutterMethodChannel*)channel{
    _channel = channel;
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  if ([@"initialize" isEqualToString:call.method]) {
      
      NSString* UUID = call.arguments[@"address"];
      bitalino = [[BITalinoBLE alloc] initWithUUID:UUID];
      bitalino.delegate=self;
      
      result(@YES);
      
  }else if([@"connect" isEqualToString:call.method]) {
      @try
      {
          _connectResult = result;
          [bitalino scanAndConnect];
      }
      @catch(id exception) {
          _connectResult = nil;
          result([FlutterError errorWithCode:@"" message:[exception reason] details:[exception details]]);
      }
    }else if([@"disconnect" isEqualToString:call.method]) {
     @try
      {
          _disconnectResult = result;
          [bitalino disconnect];
      }
    @catch(id exception) {
        result([FlutterError errorWithCode:@"" message:[exception reason] details:[exception details]]);
    }
     
  }else if([@"version" isEqualToString:call.method]) {
      @try
       {
           result([bitalino version]);
       }
     @catch(id exception) {
         result([FlutterError errorWithCode:@"" message:[exception reason] details:[exception details]]);
     }
      
   }else if([@"batteryThreshold" isEqualToString:call.method]) {
      @try
      {
          _batteryResult = result;
          NSNumber* threshold = call.arguments[@"threshold"];
          [bitalino setBatteryThreshold:[threshold intValue]];
       }
       @catch(id exception) {
           _batteryResult = nil;
           result([FlutterError errorWithCode:@"" message:[exception reason] details:[exception details]]);
       }
       
   }else if([@"trigger" isEqualToString:call.method]) {
       @try
       {
           _triggerResult = result;
           NSArray* outputs = call.arguments[@"digitalChannels"];
           [bitalino setDigitalOutputs:outputs];
        }
        @catch(id exception) {
            _triggerResult = nil;
            result([FlutterError errorWithCode:@"" message:[exception reason] details:[exception details]]);
        }

   }else if([@"start" isEqualToString:call.method]) {
       @try
       {
           _startResult = result;
           NSArray* channels = call.arguments[@"analogChannels"];
           NSNumber* sampleRate = call.arguments[@"sampleRate"];
           NSNumber* numberOfSamples = call.arguments[@"numberOfSamples"];
           
           [bitalino startRecordingFromAnalogChannels:channels withSampleRate:[sampleRate intValue] numberOfSamples:[numberOfSamples intValue] samplesCompletion:^(BITalinoFrame *frame) {
               [self->_dataStreamHandler sendFrame:frame];
           }];
        }
        @catch(id exception) {
            _startResult = nil;
            result([FlutterError errorWithCode:@"" message:[exception reason] details:[exception details]]);
        }

   }else if([@"stop" isEqualToString:call.method]) {
       @try
       {
           _stopResult = result;
          [bitalino stopRecording];
        }
        @catch(id exception) {
            _stopResult  = nil;
            result([FlutterError errorWithCode:@"" message:[exception reason] details:[exception details]]);
        }

  } else {
    result(FlutterMethodNotImplemented);
  }
}

#pragma BITalino delegates
-(void)bitalinoDidConnect:(BITalinoBLE *)bitalino{
    if(_connectResult!=nil){
        _connectResult(@YES);
        _connectResult = nil;
    }
}

-(void)bitalinoDidDisconnect:(BITalinoBLE *)bitalino{
    if(_disconnectResult!=nil){
        _disconnectResult(@YES);
        _disconnectResult = nil;
    }else{
        [_channel invokeMethod:@"lostConnection" arguments:nil];
    }
}

-(void)bitalinoBatteryThresholdUpdated:(BITalinoBLE *)bitalino{
    if(_batteryResult!=nil){
        _batteryResult(@YES);
        _batteryResult = nil;
    }
}

-(void)bitalinoBatteryDigitalOutputsUpdated:(BITalinoBLE *)bitalino{
    if(_triggerResult){
        _triggerResult(@YES);
        _triggerResult = nil;
    }
}

-(void)bitalinoRecordingStarted:(BITalinoBLE *)bitalino{
    if(_startResult!=nil){
        _startResult(@YES);
        _startResult = nil;
    }
}

-(void)bitalinoRecordingStopped:(BITalinoBLE *)bitalino{
    if(_stopResult!=nil){
        _stopResult(@YES);
        _stopResult = nil;
    }
}

@end
