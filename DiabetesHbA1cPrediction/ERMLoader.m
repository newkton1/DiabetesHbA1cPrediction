//
//  ERMLoader.m
//  DiabetesHbA1cPrediction
//
//  Bootstraps ExerciseReminderManager at binary load time.
//
//  Swift 6 prohibits defining +load in Swift code, but Objective-C +load
//  is unrestricted and runs before main() — making it the most reliable
//  startup hook available.  NSClassFromString+performSelector is used so
//  this file has zero header dependency on the Swift class (which lives in
//  a separate parallel Swift compilation batch in Xcode 26 and is therefore
//  not guaranteed to be visible at Swift compile time from other files).
//
//  TO ADD THIS FILE: drag ERMLoader.m into your Xcode project navigator,
//  make sure "Add to targets: DiabetesHbA1cPrediction" is checked, then build.
//

#import <Foundation/Foundation.h>

@interface _ERMLoader : NSObject
@end

@implementation _ERMLoader

+ (void)load {
    // Try the standard Swift mangled name (ModuleName.ClassName) first,
    // then fall back to the bare class name in case the module prefix
    // differs between Debug and Release builds.
    Class cls = NSClassFromString(@"DiabetesHbA1cPrediction.ExerciseReminderManager");
    if (!cls) cls = NSClassFromString(@"ExerciseReminderManager");

    SEL sel = NSSelectorFromString(@"bootstrap");
    if ([cls respondsToSelector:sel]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [cls performSelector:sel];
#pragma clang diagnostic pop
    }
}

@end
