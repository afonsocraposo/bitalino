#import <Flutter/Flutter.h>
#import <BITalinoBLE/BITalinoBLE.h>

@interface BitalinoPlugin : NSObject<FlutterPlugin, BITalinoBLEDelegate>{
    int sampleRate;
    BITalinoBLE* bitalino;
}

@end
