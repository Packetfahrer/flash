#import "FLASHFlashButton.h"

#import "FLASHFlashController.h"
#import "Macros.h"

#import "SBFLockScreenMetrics.h"
#import "SBLockScreenViewHeaders.h"
#import "UIImage+Private.h"

static const CGFloat kImageViewSize = 29;

static const CGFloat kOnAlpha = 1;
static const CGFloat kOffAlpha = 0.6;

static const NSTimeInterval kHideTimerInterval = 3;
static const NSTimeInterval kAnimationDuration = 0.35;

static SBLockScreenScrollView * getLockScreenScrollView() {
  SBLockScreenViewController *vc =
      [[%c(SBLockScreenManager) sharedInstance] lockScreenViewController];
  return [vc lockScreenScrollView];
}

@implementation FLASHFlashButton {
  UIImageView *_flashImageView;
  NSTimer *_hideTimer;
}

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    UITapGestureRecognizer *tapGestureRecogizer =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_handleTap:)];
    tapGestureRecogizer.delegate = self;
    [self addGestureRecognizer:tapGestureRecogizer];
    [getLockScreenScrollView().panGestureRecognizer requireGestureRecognizerToFail:tapGestureRecogizer];
    [tapGestureRecogizer release];

    NSBundle *bundle = [NSBundle bundleWithPath:kBundlePath];
    UIImage *icon = [UIImage imageNamed:@"Flash" inBundle:bundle];

    _flashImageView = [[UIImageView alloc] initWithImage:icon];
    _flashImageView.alpha = kOffAlpha;
    _flashImageView.userInteractionEnabled = NO;
    [self addSubview:_flashImageView];

    _visible = NO;
    self.alpha = 0;
  }
  return self;
}


- (void)didMoveToWindow {
  [super didMoveToWindow];
  if (self.window) {
    [[FLASHFlashController sharedFlashController] addDelegate:self];
  } else {
    [[FLASHFlashController sharedFlashController] removeDelegate:self];
  }
}

- (void)dealloc {
  // _hideTimer must be nil otherwise we wouldn't dealloc (it holds a strong ref to us).
  [_flashImageView release];
  [super dealloc];
}

- (void)layoutSubviews {
  [super layoutSubviews];

  const CGFloat cornerInset = [%c(SBFLockScreenMetrics) slideUpGrabberInset];
  CGRect bounds = self.bounds;
  CGRect frame = CGRectMake(bounds.origin.x + cornerInset,
                            CGRectGetMaxY(bounds) - cornerInset - kImageViewSize,
                            kImageViewSize,
                            kImageViewSize);
  _flashImageView.frame = frame;
}

- (void)_handleTap:(UIGestureRecognizer *)sender {
  [[FLASHFlashController sharedFlashController] flashButtonTapped:self];
}

#pragma mark - Timering

- (void)_addTimer {
  if (!_hideTimer) {
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:kHideTimerInterval
                                                      target:self
                                                    selector:@selector(_timerDidFire:)
                                                    userInfo:nil
                                                     repeats:NO];
    _hideTimer = [timer retain];
  }
}

- (void)_removeTimer {
  if (_hideTimer) {
    [_hideTimer invalidate];
    [_hideTimer release];
    _hideTimer = nil;
  }
}

- (void)_timerDidFire:(NSTimer *)timer {
  [self setVisible:NO immediately:YES animated:YES];
}

#pragma mark - Visibility

- (void)setVisible:(BOOL)visible {
  [self setVisible:visible immediately:NO animated:YES];
}

// Here's the behavior that we want:
//
// - setVisible (immediately or not) starts a hide timer that is cancelled and re-created when we
//   setVisible again.
// - Immediate hide does it immediately, no questions asked.
// - Non-immediate hide waits for the hide timer to fire then does it.
//
// Note that a scheduled hide is always animated and that the immediately argument is useless
// if visible is YES.
- (void)setVisible:(BOOL)visible immediately:(BOOL)immediately animated:(BOOL)animated {
  if (_visible != visible) {
    if (visible) { // Set visible, refresh timer.
      _visible = visible;
      [self _removeTimer];
      [self _addTimer];
      [self _visibilityChangedAnimated:animated];
    } else if (immediately) { // Immediate Hide, removeTimer.
      _visible = visible;
      [self _removeTimer];
      [self _visibilityChangedAnimated:animated];
    } else { // Non-immediate Hide. Schedule.
      [self _addTimer];
    }
  } else if (visible) { // Still visible, refresh timer.
    [self _removeTimer];
    [self _addTimer];
  }
}

- (void)_visibilityChangedAnimated:(BOOL)animated {
  if (animated) {
    UIViewAnimationOptions options = UIViewAnimationOptionAllowUserInteraction |
        UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseInOut |
        UIViewAnimationOptionTransitionNone;
    [UIView animateWithDuration:kAnimationDuration
                          delay:0
                        options:options
                     animations:^{
                         self.alpha = (_visible) ? 1 : 0;
                     }
                     completion:nil];
  } else {
    self.alpha = (_visible) ? 1 : 0;
  }
}

#pragma mark - FLASHFlashlightDelegate

- (void)flashlightDidTurnOn:(BOOL)flag {
  if (flag != self.flashlightOn) {
    self.flashlightOn = flag;

    _flashImageView.alpha = (flag) ? kOnAlpha : kOffAlpha;
  }
}

#pragma mark - UIGestureRecognizerDelegate

// Tether support. I'm watching you, @phillipten.
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
  shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
  Class DGTController = %c(DGTController);
  if (DGTController && [otherGestureRecognizer isKindOfClass:[UITapGestureRecognizer class]] &&
      [otherGestureRecognizer.delegate isKindOfClass:DGTController]) {
    return YES;
  }
  return NO;
}

@end
