//
//  VoiceDelegate.m
//  surespot
//
//  Created by Adam on 12/27/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//

#import "VoiceDelegate.h"
#import "CocoaLumberjack.h"
#import "IdentityController.h"
#import "EncryptionController.h"
#import "UIUtils.h"
#import "NSData+Base64.h"
#import "NSData+SRB64Additions.h"
#import "ChatManager.h"
#import "ChatDataSource.h"
#import "NetworkManager.h"
#import "AudioUnit/AudioUnit.h"
#import "SurespotAppDelegate.h"
#import "SurespotMessage.h"
#import "SDWebImageManager.h"
#import "FileController.h"
#import "ChatUtils.h"
#import "NSBundle+FallbackLanguage.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelInfo;
#else
static const DDLogLevel ddLogLevel = DDLogLevelOff;
#endif

@interface VoiceDelegate()
@property (nonatomic, strong) NSString * username;
@property (nonatomic, strong) NSString * theirUsername;
@property (nonatomic, strong) NSString * ourVersion;
@property (nonatomic, strong) UIView * countdownView;
@property (nonatomic, strong) UITextField * countdownTextField;
@property (nonatomic, strong) NSTimer * countdownTimer;
@property (nonatomic, assign) NSInteger timeRemaining;
@property (nonatomic, strong) SurespotMessage * message;
@property (nonatomic, weak) MessageView * cell;
@property (nonatomic, strong) NSTimer * playTimer;
@property (nonatomic, strong) NSLock * playLock;
@property (nonatomic, strong) NSString * outputPath;
@property (nonatomic, assign) CGRect scopeRect;
@end

@implementation VoiceDelegate
const NSInteger SEND_THRESHOLD = 25;

- (BOOL) hasPermissionForMic {
    // this will only work with iOS 8+
    if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_7_1)
    {
        switch ([[AVAudioSession sharedInstance] recordPermission]) {
            case AVAudioSessionRecordPermissionGranted:
                return YES;
                break;
            case AVAudioSessionRecordPermissionDenied:
                return NO;
                break;
            case AVAudioSessionRecordPermissionUndetermined:
                // This is the initial state before a user has made any choice
                // You can use this spot to request permission here if you want
                return YES;
                break;
            default:
                return YES;
                break;
        }
    }
    return YES;
}

- (id) initWithUsername: (NSString *) username
             ourVersion:(NSString *) ourVersion


{
    DDLogInfo(@"init, username: %@, version: %@", username, ourVersion);
    // Call superclass's initializer
    self = [super init];
    if( !self ) return nil;
    _username = username;
    _ourVersion = ourVersion;
    
    _playLock = [[NSLock alloc] init];
    _countdownView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 44, 44)];
    
    //setup the button
    _countdownView.layer.cornerRadius = 22;
    _countdownView.layer.borderColor = [[UIUtils surespotBlue] CGColor];
    _countdownView.layer.borderWidth = 3.0f;
    _countdownView.backgroundColor = [UIColor blackColor];
    _countdownView.opaque = YES;
    
    
    _countdownTextField = [[UITextField alloc] initWithFrame:CGRectMake(0,0, 44, 44)];
    _countdownTextField.textAlignment = NSTextAlignmentCenter;
    _countdownTextField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    _countdownTextField.textColor = [UIColor whiteColor];
    _countdownTextField.font = [UIFont boldSystemFontOfSize:24];
    
    [_countdownView addSubview:_countdownTextField];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillResignActive:)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    
    return self;
}

-(void) playVoiceMessage: (SurespotMessage *) message cell: (MessageView *) cell {
    BOOL differentMessage = ![message isEqual:_message];
    
    [self stopPlayingDeactivateSession:!differentMessage];
    
    if (differentMessage) {
        _message = message;
        _cell = cell;
        cell.message = message;
        DDLogVerbose(@"attaching message %@ to cell %@", [message iv], cell);
        
        //see if we have local data
        NSData * voiceData;
        if (message.plainData) {
            voiceData = [NSData dataWithContentsOfURL: [NSURL URLWithString:message.plainData]];
        }
        
        if (voiceData) {
            [self playMessageData:voiceData message:message];
        }
        else {
            [[SDWebImageManager sharedManager] downloadWithURL:[NSURL URLWithString: message.data]
                                                      mimeType:message.mimeType
                                                   ourUsername:_username
                                                    ourVersion:[message getOurVersion: _username]
                                                 theirUsername:[message getOtherUser: _username]
                                                  theirVersion:[message getTheirVersion: _username]
                                                            iv:message.iv
                                                        hashed: message.hashed
                                                       options: SDWebImageRetryFailed
                                                      progress:nil
                                                     completed:^(id data, NSString *mimeType, NSError *error, SDImageCacheType cacheType, BOOL finished) {
                                                         if ((!data || error) && finished) {
                                                             message.playVoice = NO;
                                                             message.voicePlayed = YES;
                                                             if (error) {
                                                                 DDLogError(@"error downloading voice message: %@ - %@", error.localizedDescription, error.localizedFailureReason);
                                                             }
                                                             
                                                             cell.messageStatusLabel.text = NSLocalizedString(@"error_downloading_message_data", nil);
                                                             return;
                                                         }
                                                         
                                                         if (message.formattedDate) {
                                                             cell.messageStatusLabel.text = message.formattedDate;
                                                         }
                                                         
                                                         [self playMessageData:data message:message];
                                                         
                                                     }];
        }
    }
}

-(void) playMessageData: (NSData *) data message: (SurespotMessage *) message {
    
    _player = [[AVAudioPlayer alloc] initWithData: data error:nil];
    //
    // Override the output to the speaker. Do this after creating the EZAudioPlayer
    // to make sure the EZAudioDevice does not reset this.
    //
    NSError * error;
    [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:&error];
    if (error)
    {
        DDLogError(@"Error overriding output to the speaker: %@", error.localizedDescription);
    }
    
    if ([_player duration] > 0) {
        _cell.audioIcon.image = [UIImage imageNamed:@"ic_media_previous"];
        _cell.audioSlider.maximumValue = [_player duration];
        [_playLock lock];
        [_playTimer invalidate];
        _playTimer = [NSTimer timerWithTimeInterval:.05
                                             target:self
                                           selector:@selector(updateTime:)
                                           userInfo:nil
                                            repeats:YES];
        
        
        //default loop is suspended when scrolling so timer events don't fire
        //http://bynomial.com/blog/?p=67
        [[NSRunLoop mainRunLoop] addTimer:_playTimer forMode:NSRunLoopCommonModes];
        [_playLock unlock];
        [_player setDelegate:self];
        [_player play];
    }
    else {
        [self stopPlayingDeactivateSession:YES];
    }
    message.playVoice = NO;
    message.voicePlayed = YES;
}

-(void) attachCell: (MessageView *) cell {
    
    DDLogVerbose(@"message cell: %@ iv: %@ playing: %@", cell, [[cell message] iv], [_message iv]);
    
    //if the message matches the cell's message then set the current cell and the slider's maximum
    if (_message && [[cell message] isEqual:_message]) {
        DDLogVerbose(@"message equal");
        _cell = cell;
        [_cell.audioSlider setMaximumValue:_player.duration];
    }
    else {
        DDLogVerbose(@"message unequal");
        cell.audioSlider.value = 0;
    }
}

-(void) stopPlayingDeactivateSession: (BOOL) deactivateSession {
    if (_player.playing) {
        [_player stop];
    }
    [_playLock lock];
    [_playTimer invalidate];
    _playTimer = nil;
    [_playLock unlock];
    
    _cell.audioIcon.image = [UIImage imageNamed:@"ic_media_play"];
    _cell.audioSlider.value = 0;
    _message = nil;
    
    if (deactivateSession) {
        DDLogInfo(@"deactivating audio session");
        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        [audioSession setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
    }
}

- (void)updateTime:(NSTimer *)timer {
    //if the cell is still pointing to the same message set the slider value
    if (_cell && _message && [[_cell message] isEqual:_message]) {
        DDLogVerbose(@"setting slider value");
        dispatch_async(dispatch_get_main_queue(), ^{
            _cell.audioSlider.value = [_player currentTime];
            _cell.audioIcon.image = [UIImage imageNamed:@"ic_media_previous"];
        });
    }
}

-(void) startRecordingUsername: (NSString *) username {
    DDLogInfo(@"start recording");
    [self stopPlayingDeactivateSession:NO];
    if (!_isRecording) {
        _isRecording = YES;
        
        
        if (![self hasPermissionForMic]) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Use of microphone disabled"
                                                            message:@"This device is not configured to allow Surespot to access your microphone."
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
            _isRecording = NO;
            return;
        }                
        
        AVAudioSession *session = [AVAudioSession sharedInstance];
        NSError *error;
        [session setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
        if (error)
        {
            DDLogError(@"Error setting up audio session category: %@", error.localizedDescription);
            _isRecording = NO;
            return;
        }
        [session setActive:YES error:&error];
        if (error)
        {
            DDLogError(@"Error setting up audio session active: %@", error.localizedDescription);
            _isRecording = NO;
            return;
        }
        
        NSString *guid = [[NSProcessInfo processInfo] globallyUniqueString] ;
        NSString *uniqueFileName = [NSString stringWithFormat:@"%@.m4a", guid];
        _outputPath = [[FileController getCacheDir] stringByAppendingPathComponent: uniqueFileName];
        DDLogInfo(@"recording to %@", _outputPath);
        NSURL *outputFileURL = [NSURL fileURLWithPath:_outputPath];
        
        // Define the recorder setting
        NSMutableDictionary *recordSetting = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                              [NSNumber numberWithInt:kAudioFormatMPEG4AAC] , AVFormatIDKey,
                                              [NSNumber numberWithInteger: 12000], AVEncoderBitRateKey,
                                              [NSNumber numberWithFloat: 12000],AVSampleRateKey,
                                              [NSNumber numberWithInt:1],AVNumberOfChannelsKey, nil];
        
        
        self.microphone = [EZMicrophone microphoneWithDelegate:self];
        [self.microphone startFetchingAudio];
        
        self.recorder = [EZRecorder recorderWithURL:outputFileURL
                                       clientFormat:[self.microphone audioStreamBasicDescription]
                                           fileType:EZRecorderFileTypeM4A
                                           delegate:self];
        _theirUsername = username;
        
        _max = 0;
        _timeRemaining = 10;
        _countdownTextField.text = @"10";
        
        //(re)set the open gl view frame
        _scopeRect = [self getScopeRect];
        
        //position the countdown view
        [_countdownView setFrame:CGRectMake(10, _scopeRect.origin.y+10, 44, 44)];
        
        _overlayView = [[AGWindowView alloc] initAndAddToKeyWindow];
        CGRect frame = _overlayView.frame;
        
        _backgroundView = [[UIView alloc] initWithFrame:frame];
        _backgroundView.backgroundColor = [UIUtils surespotTransparentGrey];
        _backgroundView.opaque = NO;
        
        [_overlayView addSubview:_backgroundView];
        
        // Programmatically create an audio plot
        _recordingAudioPlot = [[EZAudioPlotGL alloc] initWithFrame:_scopeRect];
        self.recordingAudioPlot.backgroundColor = [UIColor colorWithRed: 0.984 green: 0.71 blue: 0.365 alpha: 1];
        self.recordingAudioPlot.color           = [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:1.0];
        self.recordingAudioPlot.plotType        = EZPlotTypeRolling;
        self.recordingAudioPlot.shouldFill      = YES;
        self.recordingAudioPlot.shouldMirror    = YES;
        
        [_overlayView addSubview:_recordingAudioPlot];
        [_overlayView addSubview:_countdownView];
        [_countdownTextField setFrame:CGRectMake(0, 0, 44, 44)];
        
        
        _countdownTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(countdownTimerFired:) userInfo:nil repeats:YES];
    }
}

-(CGRect) getScopeRect {
    CGSize screenSize = [[UIScreen mainScreen] bounds].size;
    //if (screenSize.height > )
    int halfHeight = screenSize.height / 2;
    return CGRectMake(0, (screenSize.height-halfHeight)/2, screenSize.width, halfHeight);
}

-(void) countdownTimerFired: (NSTimer *) timer {
    _timeRemaining--;
    dispatch_async(dispatch_get_main_queue(), ^{
        _countdownTextField.text = [@(_timeRemaining) stringValue];
        
        if (_timeRemaining <= 0) {
            [self stopRecordingSend:[NSNumber numberWithBool:YES]];
        }
    });
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    DDLogInfo(@"finished playing, successfully?: %@", flag ? @"YES" : @"NO");
    [self stopPlayingDeactivateSession:YES];
}

-(void) stopRecordingSend: (NSNumber*) send {
    //give em like another 0.5
    [self performSelector:@selector(stopRecordingSendInternal:) withObject:send afterDelay:.2];
}

-(void) stopRecordingSendInternal: (NSNumber*) send {
    DDLogInfo(@"stop recording");
    if (_isRecording) {
        [_countdownTimer invalidate];
        [_microphone stopFetchingAudio];
        [_recorder closeAudioFile];
        
        [_overlayView removeFromSuperview];
        [_recordingAudioPlot removeFromSuperview];
        [_countdownView removeFromSuperview];
        [_backgroundView removeFromSuperview];
        _backgroundView = nil;
        
        
        DDLogInfo(@"deactivating audio session");
        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        [audioSession setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
        
        if ([send boolValue]) {
            [self uploadVoiceUrl:[NSURL fileURLWithPath:_outputPath]];
        }
        else {
            [[NSFileManager defaultManager] removeItemAtPath:_outputPath error:nil];
        }
        _isRecording = NO;
    }
}



-(void) uploadVoiceUrl: (NSURL *) url {
    
    //    if (!url || _max < SEND_THRESHOLD) {
    //
    //        [UIUtils showToastKey:@"no_audio_detected" duration:1.5];
    //        [[NSFileManager defaultManager] removeItemAtPath:_outputPath error:nil];
    //        return;
    //    }
    
    [[[ChatManager sharedInstance] getChatController:_username] sendVoiceMessage:url to:_theirUsername];
}

// Thread Safety
//
// Note that any callback that provides streamed audio data (like streaming
// microphone input) happens on a separate audio thread that should not be
// blocked. When we feed audio data into any of the UI components we need to
// explicity create a GCD block on the main thread to properly get the UI to
// work.
- (void)   microphone:(EZMicrophone *)microphone
     hasAudioReceived:(float **)buffer
       withBufferSize:(UInt32)bufferSize
 withNumberOfChannels:(UInt32)numberOfChannels
{
    // Getting audio data as an array of float buffer arrays. What does that
    // mean? Because the audio is coming in as a stereo signal the data is split
    // into a left and right channel. So buffer[0] corresponds to the float* data
    // for the left channel while buffer[1] corresponds to the float* data for
    // the right channel.
    
    //
    // See the Thread Safety warning above, but in a nutshell these callbacks
    // happen on a separate audio thread. We wrap any UI updating in a GCD block
    // on the main thread to avoid blocking that audio flow.
    //
    __weak typeof (self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        //
        // All the audio plot needs is the buffer data (float*) and the size.
        // Internally the audio plot will handle all the drawing related code,
        // history management, and freeing its own resources. Hence, one badass
        // line of code gets you a pretty plot :)
        //
        [weakSelf.recordingAudioPlot updateBuffer:buffer[0]
                                   withBufferSize:bufferSize];
    });
}

//------------------------------------------------------------------------------

- (void)   microphone:(EZMicrophone *)microphone
        hasBufferList:(AudioBufferList *)bufferList
       withBufferSize:(UInt32)bufferSize
 withNumberOfChannels:(UInt32)numberOfChannels
{
    //
    // Getting audio data as a buffer list that can be directly fed into the
    // EZRecorder. This is happening on the audio thread - any UI updating needs
    // a GCD main queue block. This will keep appending data to the tail of the
    // audio file.
    //
    if (self.isRecording)
    {
        [self.recorder appendDataFromBufferList:bufferList
                                 withBufferSize:bufferSize];
    }
}

- (void)recorderDidClose:(EZRecorder *)recorder
{
    recorder.delegate = nil;
}

- (void)applicationWillResignActive:(NSNotification *)notification {
    //stop recording
    [self stopRecordingSendInternal:[NSNumber numberWithBool:NO]];
}

@end
