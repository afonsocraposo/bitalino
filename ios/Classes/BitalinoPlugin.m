#import "BitalinoPlugin.h"
#if __has_include(<bitalino/bitalino-Swift.h>)
#import <bitalino/bitalino-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "bitalino-Swift.h"
#endif

@implementation BitalinoPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftBitalinoPlugin registerWithRegistrar:registrar];
}
@end
