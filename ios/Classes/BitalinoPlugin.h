#import <Flutter/Flutter.h>
#import <BITalinoBLE/BITalinoBLE.h>

@class DataStreamHandler;

@interface BitalinoPlugin : NSObject<FlutterPlugin, BITalinoBLEDelegate>{
    int sampleRate;
    BITalinoBLE* bitalino;
}
    @property (nonatomic, strong) DataStreamHandler* dataStreamHandler;
@end

@interface DataStreamHandler : NSObject<FlutterStreamHandler>
    @property (nonatomic, strong) FlutterEventSink eventSink;
    - (void) sendFrame:(BITalinoFrame *)frame;
@end


