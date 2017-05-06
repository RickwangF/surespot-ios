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
#import "CAXException.h"
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
@property (nonatomic, strong) AVAudioRecorder *recorder;
@property (nonatomic, strong) AVAudioPlayer *player;
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

@synthesize view;
@synthesize rioUnit;
@synthesize unitIsRunning;
@synthesize unitHasBeenCreated;
@synthesize inputProc;

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
                                             selector:@selector(applicationDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillResignActive:)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];

    return self;
}

- (BOOL)isRecording
{
    return [_recorder isRecording];
}

-(void) prepareRecording {
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
    
    // Initiate and prepare the recorder
    _recorder = [[AVAudioRecorder alloc] initWithURL:outputFileURL settings:recordSetting error:nil];
    _recorder.delegate = self;
    _recorder.meteringEnabled = YES;
    [_recorder prepareToRecord];
    
    [self initScope];
    
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
    
    if (!_recorder.recording) {
        
        if (![self hasPermissionForMic]) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Use of microphone disabled"
                                                            message:@"This device is not configured to allow Surespot to access your microphone."
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
            return;
        }
        [self prepareRecording];
        
        _theirUsername = username;
        
        XThrowIfError(AudioOutputUnitStart(rioUnit), "couldn't start remote i/o unit");
        
        unitIsRunning = 1;
        
        DDLogInfo(@"activating audio session");
        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        [audioSession setActive:YES error:nil];
        
        _max = 0;
        _timeRemaining = 10;
        _countdownTextField.text = @"10";
        
        //(re)set the open gl view frame
        _scopeRect = [self getScopeRect];
        drawBufferLen = _scopeRect.size.width;
        resetOscilLine = YES;
        [view setFrame: _scopeRect];
        
        //position the countdown view
        [_countdownView setFrame:CGRectMake(10, _scopeRect.origin.y+10, 44, 44)];
        
        AGWindowView * overlayView = [[AGWindowView alloc] initAndAddToKeyWindow];
        CGRect frame = overlayView.frame;
        
        _backgroundView = [[UIView alloc] initWithFrame:frame];
        _backgroundView.backgroundColor = [UIUtils surespotTransparentGrey];
        _backgroundView.opaque = NO;
        
        [overlayView addSubview:_backgroundView];
        
        
        [overlayView addSubview:view];
        [overlayView addSubview:_countdownView];
        [_countdownTextField setFrame:CGRectMake(0, 0, 44, 44)];
        
        [_recorder record];
        [view startAnimation];
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
    if (_recorder.recording) {
        
        [_countdownTimer invalidate];
        [_recorder stop];
        
        [view stopAnimation];
        
        [[AGWindowView activeWindowViewContainingView:view] removeFromSuperview];
        [view removeFromSuperview];
        [_countdownView removeFromSuperview];
        [_backgroundView removeFromSuperview];
        _backgroundView = nil;
        
        AudioOutputUnitStop(rioUnit);
        
        DDLogInfo(@"deactivating audio session");
        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        [audioSession setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
        
        if ([send boolValue]) {
            [self uploadVoiceUrl:_recorder.url];
        }
        else {
            [[NSFileManager defaultManager] removeItemAtPath:_outputPath error:nil];
        }
        
    }
}


-(void) uploadVoiceUrl: (NSURL *) url {
    
    if (!url || _max < SEND_THRESHOLD) {
        
        [UIUtils showToastKey:@"no_audio_detected" duration:1.5];
        [[NSFileManager defaultManager] removeItemAtPath:_outputPath error:nil];
        return;
    }
    
    [[[ChatManager sharedInstance] getChatController:_username] sendVoiceMessage:url to:_theirUsername];
}



#pragma mark-

void cycleOscilloscopeLines()
{
    // Cycle the lines in our draw buffer so that they age and fade. The oldest line is discarded.
    int drawBuffer_i;
    for (drawBuffer_i=(kNumDrawBuffers - 2); drawBuffer_i>=0; drawBuffer_i--)
        memmove(drawBuffers[drawBuffer_i + 1], drawBuffers[drawBuffer_i], drawBufferLen);
}

#pragma mark -Audio Session Interruption Listener

void rioInterruptionListener(void *inClientData, UInt32 inInterruption)
{
    try {
        printf("Session interrupted! --- %s ---", inInterruption == kAudioSessionBeginInterruption ? "Begin Interruption" : "End Interruption");
        
        VoiceDelegate *THIS = (__bridge VoiceDelegate*)inClientData;
        
        if (inInterruption == kAudioSessionBeginInterruption) {
            XThrowIfError(AudioOutputUnitStop(THIS->rioUnit), "couldn't stop unit");
        }
    } catch (CAXException e) {
        char buf[256];
        fprintf(stderr, "Error: %s (%s)\n", e.mOperation, e.FormatError(buf));
    }
}


#pragma mark -RIO Input Callback

static OSStatus	PerformThru(
                            void						*inRefCon,
                            AudioUnitRenderActionFlags 	*ioActionFlags,
                            const AudioTimeStamp 		*inTimeStamp,
                            UInt32 						inBusNumber,
                            UInt32 						inNumberFrames,
                            AudioBufferList 			*ioData)
{
    AudioBufferList * bufferList = new AudioBufferList();
    
    SInt32 samples[inNumberFrames];
    memset (&samples, 0, sizeof (samples));
    
    bufferList->mNumberBuffers = 1;
    bufferList->mBuffers[0].mData = samples;
    bufferList->mBuffers[0].mNumberChannels = 1;
    bufferList->mBuffers[0].mDataByteSize = inNumberFrames*sizeof(SInt32);
    
    
    // DDLogInfo(@"performThru");
    VoiceDelegate *THIS = (__bridge VoiceDelegate *)inRefCon;
    OSStatus err = AudioUnitRender(THIS->rioUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, bufferList);
    if (err) { printf("PerformThru: error %d\n", (int)err); return err; }
    
    // Remove DC component
    for(int i = 0; i < bufferList->mNumberBuffers; ++i)
        THIS->dcFilter[i].InplaceFilter((Float32*)(bufferList->mBuffers[i].mData), inNumberFrames);
    
    // The draw buffer is used to hold a copy of the most recent PCM data to be drawn on the oscilloscope
    if (drawBufferLen != drawBufferLen_alloced)
    {
        int drawBuffer_i;
        
        // Allocate our draw buffer if needed
        if (drawBufferLen_alloced == 0)
            for (drawBuffer_i=0; drawBuffer_i<kNumDrawBuffers; drawBuffer_i++)
                drawBuffers[drawBuffer_i] = NULL;
        
        // Fill the first element in the draw buffer with PCM data
        for (drawBuffer_i=0; drawBuffer_i<kNumDrawBuffers; drawBuffer_i++)
        {
            drawBuffers[drawBuffer_i] = (SInt8 *)realloc(drawBuffers[drawBuffer_i], drawBufferLen);
            bzero(drawBuffers[drawBuffer_i], drawBufferLen);
        }
        
        drawBufferLen_alloced = drawBufferLen;
    }
    
    int i;
    
    //Convert the floating point audio data to integer (Q7.24)
    err = AudioConverterConvertComplexBuffer(THIS->audioConverter, inNumberFrames, bufferList, THIS->drawABL);
    if (err) { printf("AudioConverterConvertComplexBuffer: error %d\n", (int)err); return err; }
    
    SInt8 *data_ptr = (SInt8 *)(THIS->drawABL->mBuffers[0].mData);
    for (i=0; i<inNumberFrames; i++)
    {
        if ((i+drawBufferIdx) >= drawBufferLen)
        {
            cycleOscilloscopeLines();
            drawBufferIdx = -i;
        }
        
        drawBuffers[0][i + drawBufferIdx] = data_ptr[2];
        
        if (data_ptr[2] > THIS.max) THIS.max = data_ptr[2];
        data_ptr += 4;
    }
    
    drawBufferIdx += inNumberFrames;
    
    delete bufferList;
    return err;
}

#pragma mark-

- (void)initScope
{
    // Turn off the idle timer, since this app doesn't rely on constant touch input
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    
    // Initialize our remote i/o unit
    
    inputProc.inputProc = PerformThru;
    inputProc.inputProcRefCon = (__bridge void *) self;
    
    try {
        [[AVAudioSession sharedInstance] setActive:YES error:nil];
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
        [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
        [[AVAudioSession sharedInstance] setPreferredIOBufferDuration:0.005 error:nil];
        hwSampleRate = [[AVAudioSession sharedInstance] sampleRate];
        [[AVAudioSession sharedInstance] setPreferredSampleRate:hwSampleRate error:nil];
        
        XThrowIfError(SetupRemoteIO(rioUnit, hwSampleRate, inputProc, thruFormat), "couldn't setup remote i/o unit");
        unitHasBeenCreated = true;
        
        
        UInt32 size = sizeof(thruFormat);
        XThrowIfError(AudioUnitGetProperty(rioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &thruFormat, &size), "couldn't get the remote I/O unit's output client format");
        
        drawFormat.SetAUCanonical(2, false);
        drawFormat.mSampleRate = 44100;
        XThrowIfError(AudioConverterNew(&thruFormat, &drawFormat, &audioConverter), "couldn't setup AudioConverter");
        
        dcFilter = new DCRejectionFilter[thruFormat.NumberChannels()];
        
        UInt32 maxFPS;
        size = sizeof(maxFPS);
        XThrowIfError(AudioUnitGetProperty(rioUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maxFPS, &size), "couldn't get the remote I/O unit's max frames per slice");
        
        drawABL = (AudioBufferList*) malloc(sizeof(AudioBufferList) + sizeof(AudioBuffer));
        drawABL->mNumberBuffers = 2;
        for (UInt32 i=0; i<drawABL->mNumberBuffers; ++i)
        {
            drawABL->mBuffers[i].mData = (SInt32*) calloc(maxFPS, sizeof(SInt32));
            drawABL->mBuffers[i].mDataByteSize = maxFPS * sizeof(SInt32);
            drawABL->mBuffers[i].mNumberChannels = 1;
        }
        
        oscilLine = (GLfloat*)malloc(drawBufferLen * 2 * sizeof(GLfloat));
    }
    catch (CAXException &e) {
        char buf[256];
        
        DDLogError(@"Error: %s (%s)\n", e.mOperation, e.FormatError(buf));
        unitIsRunning = 0;
        if (dcFilter) delete[] dcFilter;
        if (drawABL)
        {
            for (UInt32 i=0; i<drawABL->mNumberBuffers; ++i)
                free(drawABL->mBuffers[i].mData);
            free(drawABL);
            drawABL = NULL;
        }
        [UIUtils showToastMessage:[NSString stringWithCString: e.FormatError(buf) encoding:NSUTF8StringEncoding ] duration:2];
    }
    catch (...) {
        DDLogError(@"An unknown error occurred\n");
        unitIsRunning = 0;
        if (dcFilter) delete[] dcFilter;
        if (drawABL)
        {
            for (UInt32 i=0; i<drawABL->mNumberBuffers; ++i)
                free(drawABL->mBuffers[i].mData);
            free(drawABL);
            drawABL = NULL;
        }
        [UIUtils showToastMessage:@"could_not_initialize_voice" duration:2];
    }
    
    
    if (!view) {
        view = [[EAGLView alloc] initWithFrame: CGRectMake(0, 0, 1,1) ];
        // Set ourself as the delegate for the EAGLView so that we get drawing and touch events
        view.delegate = self;
        
        // Set up the view to refresh at 20 hz
        [view setAnimationInterval:1./20.];
    }
}


- (void)dealloc
{
    delete[] dcFilter;
    if (drawABL)
    {
        for (UInt32 i=0; i<drawABL->mNumberBuffers; ++i)
            free(drawABL->mBuffers[i].mData);
        free(drawABL);
        drawABL = NULL;
    }
    
    
    free(oscilLine);
    
    AudioComponentInstanceDispose(rioUnit);
    unitHasBeenCreated = false;
    unitIsRunning = false;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}




- (void)drawOscilloscope
{
    // DDLogInfo(@"drawOscilliscope");
    // Clear the view
    glClear(GL_COLOR_BUFFER_BIT);
    
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE);
    
    glColor4f(0., 0., 0., 1.);
    
    glPushMatrix();
    
    
    GLfloat *oscilLine_ptr;
    GLfloat max = drawBufferLen;
    SInt8 *drawBuffer_ptr;
    
    // Alloc an array for our oscilloscope line vertices
    if (resetOscilLine) {
        oscilLine = (GLfloat*)realloc(oscilLine, drawBufferLen * 2 * sizeof(GLfloat));
        resetOscilLine = NO;
    }
    
    
    
    
    // Translate to the left side and vertical center of the screen, and scale so that the screen coordinates
    // go from 0 to 1 along the X, and -1 to 1 along the Y
    glTranslatef(0, _scopeRect.size.height/2, 0.);
    glScalef(_scopeRect.size.width, _scopeRect.size.height/2, 1.);
    
    // Set up some GL state for our oscilloscope lines
    glDisable(GL_TEXTURE_2D);
    glDisableClientState(GL_TEXTURE_COORD_ARRAY);
    glDisableClientState(GL_COLOR_ARRAY);
    glDisable(GL_LINE_SMOOTH);
    glLineWidth(1.);
    
    int drawBuffer_i;
    // Draw a line for each stored line in our buffer (the lines are stored and fade over time)
    for (drawBuffer_i=0; drawBuffer_i<kNumDrawBuffers; drawBuffer_i++)
    {
        if (!drawBuffers[drawBuffer_i]) continue;
        
        oscilLine_ptr = oscilLine;
        drawBuffer_ptr = drawBuffers[drawBuffer_i];
        
        GLfloat i;
        // Fill our vertex array with points
        for (i=0.; i<max; i=i+1.)
        {
            *oscilLine_ptr++ = i/max;
            *oscilLine_ptr++ = (Float32)(*drawBuffer_ptr++) / 128.;
        }
        
        // If we're drawing the newest line, draw it in solid blue. Otherwise, draw it in a faded blue.
        if (drawBuffer_i == 0)
            
            glColor4f(0.2, 0.71, 0.898, 1.);
        else
            glColor4f(0.2, 0.71, 0.898, (.24 * (1. - ((GLfloat)drawBuffer_i / (GLfloat)kNumDrawBuffers))));
        
        // Set up vertex pointer,
        glVertexPointer(2, GL_FLOAT, 0, oscilLine);
        
        // and draw the line.
        glDrawArrays(GL_LINE_STRIP, 0, drawBufferLen);
        
    }
    
    glPopMatrix();
}


- (void)drawView:(id)sender forTime:(NSTimeInterval)time
{
    [self drawOscilloscope];
    
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    view.applicationResignedActive = NO;
}

- (void)applicationWillResignActive:(NSNotification *)notification {
    //stop animation before going into background
    [self stopRecordingSendInternal:[NSNumber numberWithBool:NO]];
    view.applicationResignedActive = YES;
}

@end
