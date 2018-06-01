//
//  VoiceDelegate.h
//  surespot
//
//  Created by Adam on 12/27/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

#import <UIKit/UIKit.h>

#include <EZAudio/EZAudio.h>
#import "SurespotMessage.h"
#import "MessageView.h"

@interface VoiceDelegate : NSObject<AVAudioPlayerDelegate, EZMicrophoneDelegate, EZRecorderDelegate>

@property (nonatomic, strong) EZAudioPlotGL *recordingAudioPlot;
@property (nonatomic, assign) BOOL isRecording;
@property (nonatomic, strong) EZMicrophone *microphone;
@property (nonatomic, strong) AVAudioPlayer *player;
@property (nonatomic, strong) EZRecorder *recorder;
@property (nonatomic, assign)   NSInteger max;
@property (nonatomic, strong)   UIView * backgroundView;
@property (nonatomic, strong)   UIView * overlayView;

- (id) initWithUsername: (NSString *) username
             ourVersion:(NSString *) ourVersion;
-(void) playVoiceMessage: (SurespotMessage *) message cell: (MessageView *) cell;
-(void) startRecordingUsername: (NSString *) username;
-(void) stopRecordingSend: (NSNumber *) send;
-(void) attachCell: (MessageView *) cell;
-(BOOL) isRecording;
@end
