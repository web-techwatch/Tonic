//
//  TonicSynthManager.mm
//  TonicDemo
//
//  Created by Nick Donaldson on 2/8/13.

//

#import "TonicSynthManager.h"
#import "Novocaine.h"
#include <vector>

using std::vector;
using namespace Tonic;

// ------ Simple wrapper for storing synth smart pointers in NS containers -----

@interface SynthWrapper : NSObject

@property (nonatomic, assign) Synth synth;

+ (SynthWrapper*)wrapperWithSynth:(Synth)synth;

@end

@implementation SynthWrapper

+ (SynthWrapper*)wrapperWithSynth:(Tonic::Synth)synth
{
  SynthWrapper * wrapper = [SynthWrapper new];
  wrapper.synth = synth;
  return wrapper;
}

@end

// --------------------------

@interface TonicSynthManager ()

@property (nonatomic, assign) Mixer mixer;
@property (nonatomic, assign) RingBufferWriter inputBuffer;

@property (nonatomic, strong) NSMutableDictionary *synthDict;

- (void)setupNovocaineOutput;

@end

@implementation TonicSynthManager

+ (TonicSynthManager*)sharedManager
{
  static TonicSynthManager *_sharedManager;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    _sharedManager = [[TonicSynthManager alloc] initInternal];
  });
  return _sharedManager;
}

- (id)init
{
  [NSException raise:NSInternalInconsistencyException format:@"init is not a valid initializer for singleton TonicSynthManager"];
  return nil;
}

- (id)initInternal
{
  self = [super init];
  if (self){
    self.synthDict = [NSMutableDictionary dictionaryWithCapacity:10];
    self.inputBuffer = RingBufferWriter("input", 8192, 2); // enough and then some
    self.inputEnabled = NO;
    [self setupNovocaineOutput];
  }
  return self;
}

- (void)setupNovocaineOutput
{
  __weak TonicSynthManager *wself = self;

  [[Novocaine audioManager] setOutputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels) {
    @autoreleasepool {
      wself.mixer.fillBufferOfFloats(data, numFrames, numChannels);
    }
  }];
  
  [[Novocaine audioManager] setInputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels){
    @autoreleasepool {
      if (wself.inputEnabled){
        wself.inputBuffer.write(data, numFrames, numChannels);
      }
    }
  }];
  
  [[Novocaine audioManager] pause];
}

- (void)startSession
{
  [[Novocaine audioManager] play];
}

- (void)endSession
{
  [[Novocaine audioManager] pause];
}

- (void)setInputEnabled:(BOOL)inputEnabled
{
  _inputEnabled = inputEnabled;
  if (inputEnabled){
    self.inputBuffer.reset();
  }
}

- (void)addSynth:(Tonic::Synth)synth forKey:(NSString *)key
{
    if (key){
      
      if ([[self.synthDict allKeys] containsObject:key]){
        self.mixer.removeInput([[self.synthDict valueForKey:key] synth]);
      }
      self.mixer.addInput(synth);
      [self.synthDict setValue:[SynthWrapper wrapperWithSynth:synth] forKey:key];

    }
    else{
      [NSException raise:NSInvalidArgumentException format:@"Argument \"key\" cannot be nil"];
    }
}

- (void)removeSynthForKey:(NSString *)key
{
    if (key){
      if ([[self.synthDict allKeys] containsObject:key]){
        Synth oldSynth = [[self.synthDict valueForKey:key] synth];
        self.mixer.removeInput(oldSynth);
      }
    }
    else{
      [NSException raise:NSInvalidArgumentException format:@"Argument \"key\" cannot be nil"];
    }
  
}

@end
