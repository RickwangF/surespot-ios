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

@interface VoiceDelegate : NSObject<EZAudioPlayerDelegate, EZMicrophoneDelegate, EZRecorderDelegate>

//------------------------------------------------------------------------------
#pragma mark - Properties
//------------------------------------------------------------------------------
//
// Use a OpenGL based plot to visualize the data coming in
//
@property (nonatomic, strong) EZAudioPlotGL *recordingAudioPlot;

//------------------------------------------------------------------------------

//
// A flag indicating whether we are recording or not
//
@property (nonatomic, assign) BOOL isRecording;

//------------------------------------------------------------------------------

//
// The microphone component
//
@property (nonatomic, strong) EZMicrophone *microphone;

//------------------------------------------------------------------------------

//
// The audio player that will play the recorded file
//
@property (nonatomic, strong) EZAudioPlayer *player;

//------------------------------------------------------------------------------

//
// The recorder component
//
@property (nonatomic, strong) EZRecorder *recorder;

//------------------------------------------------------------------------------

//
// The second audio plot used on the top right to display the current playing audio
//
@property (nonatomic, weak) EZAudioPlot *playingAudioPlot;

//------------------------------------------------------------------------------

#pragma mark - Actions
//------------------------------------------------------------------------------

//
// Stops the recorder and starts playing whatever has been recorded.
//
- (IBAction)playFile:(id)sender;

//------------------------------------------------------------------------------

//
// Toggles the microphone on and off. When the microphone is on it will send its
// delegate (aka this view controller) the audio data in various ways (check out
// the EZMicrophoneDelegate documentation for more details);
//
- (IBAction)toggleMicrophone:(id)sender;

//------------------------------------------------------------------------------

//
// Toggles the recording mode on and off.
//
- (IBAction)toggleRecording:(id)sender;

@property (nonatomic, assign)   NSInteger max;
@property (nonatomic, strong)   UIView * backgroundView;
@property (nonatomic, strong)   UIView * overlayView;

- (id) initWithUsername: (NSString *) username
             ourVersion:(NSString *) ourVersion;

-(void) playVoiceMessage: (SurespotMessage *) message cell: (MessageView *) cell;
-(void) prepareRecording;
-(void) startRecordingUsername: (NSString *) username;
-(void) stopRecordingSend: (NSNumber *) send;
-(void) attachCell: (MessageView *) cell;
-(BOOL) isRecording;
@end
