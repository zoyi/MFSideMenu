//
//  UIViewController+MFSideMenu.m
//
//  Created by Michael Frederick on 3/18/12.
//

#import "UIViewController+MFSideMenu.h"
#import "MFSideMenuManager.h"
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import "UIBarButtonItem+CKAdditions.h"

@class SideMenuViewController;

@interface UIViewController (MFSideMenuPrivate)
- (void) toggleSideMenu:(BOOL)hidden animationDuration:(NSTimeInterval)duration;
@end

@implementation UIViewController (MFSideMenu)

static char menuStateKey;
static char velocityKey;

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (void) toggleSideMenuPressed:(id)sender {
    if(self.navigationController.menuState == MFSideMenuStateVisible) {
        [self.navigationController setMenuState:MFSideMenuStateHidden];
    } else {
        [self.navigationController setMenuState:MFSideMenuStateVisible];
    }
}

- (void) backButtonPressed:(id)sender {
    [self.navigationController popViewControllerAnimated:YES];
}

- (UIBarButtonItem *)menuBarButtonItem {
  UIView *menuBarButtonBackgroundView = [[[UIView alloc] initWithFrame:CGRectZero] autorelease];
  menuBarButtonBackgroundView.backgroundColor = [UIColor clearColor];
  UIButton *menuBarButton = [UIButton buttonWithType:UIButtonTypeCustom];
  [menuBarButton setImage:[UIImage imageNamed:@"menu-icon-gnb.png"] forState:UIControlStateNormal];
  [menuBarButton addTarget:self action:@selector(toggleSideMenuPressed:) forControlEvents:UIControlEventTouchUpInside];
  
  menuBarButton.frame = CGRectMake(10, 0, 40, 40);
  [menuBarButtonBackgroundView addSubview:menuBarButton];
  menuBarButtonBackgroundView.frame = CGRectMake(0, 0, CGRectGetMaxX(menuBarButton.frame), CGRectGetMaxY(menuBarButton.frame));
  return [[[UIBarButtonItem alloc] initWithCustomView:menuBarButtonBackgroundView] autorelease];
}

- (UIBarButtonItem *)backBarButtonItem {
  return [UIBarButtonItem cookiStyleBackButtonItem];
}

- (void) setupSideMenuBarButtonItem {
    if([MFSideMenuManager sharedManager].menuSide == MenuRightHandSide
       && [MFSideMenuManager menuButtonEnabled]) {
        self.navigationItem.rightBarButtonItem = [self menuBarButtonItem];
        return;
    } else {
      // right bar button
      if (!([self isKindOfClass:NSClassFromString(@"CKWebKitViewController")]
            || [self isKindOfClass:NSClassFromString(@"CKWebController")])) {
        self.navigationItem.rightBarButtonItem = [UIBarButtonItem cookiBadgeButtonItem];
      }

    }
    
    if(self.navigationController.menuState == MFSideMenuStateVisible ||
       [[self.navigationController.viewControllers objectAtIndex:0] isEqual:self]) {
        if([MFSideMenuManager menuButtonEnabled]) {
          self.navigationItem.hidesBackButton = YES;
            self.navigationItem.leftBarButtonItem = [self menuBarButtonItem];
        }
    } else {
        if([MFSideMenuManager sharedManager].menuSide == MenuLeftHandSide) {
            if([MFSideMenuManager backButtonEnabled]) {
              self.navigationItem.hidesBackButton = YES;
                self.navigationItem.leftBarButtonItem = [self backBarButtonItem];
            }
        }
    }
}

- (void)setMenuState:(MFSideMenuState)menuState {
    [self setMenuState:menuState animationDuration:kMenuAnimationDuration];
}

- (void)setMenuState:(MFSideMenuState)menuState animationDuration:(NSTimeInterval)duration {
    if(![self isKindOfClass:[UINavigationController class]]) {
        [self.navigationController setMenuState:menuState animationDuration:duration];
        return;
    }
    
    MFSideMenuState currentState = self.menuState;
    
    objc_setAssociatedObject(self, &menuStateKey, [NSNumber numberWithInt:menuState], OBJC_ASSOCIATION_RETAIN);
    
    switch (currentState) {
        case MFSideMenuStateHidden:
            if (menuState == MFSideMenuStateVisible) {
                [self toggleSideMenu:NO animationDuration:duration];
            }
            break;
        case MFSideMenuStateVisible:
            if (menuState == MFSideMenuStateHidden) {
                [self toggleSideMenu:YES animationDuration:duration];
            }
            break;
        default:
            break;
    }
}

- (MFSideMenuState)menuState {
    if(![self isKindOfClass:[UINavigationController class]]) {
        return self.navigationController.menuState;
    }
    
    return (MFSideMenuState)[objc_getAssociatedObject(self, &menuStateKey) intValue];
}

- (void)setVelocity:(CGFloat)velocity {
    objc_setAssociatedObject(self, &velocityKey, [NSNumber numberWithFloat:velocity], OBJC_ASSOCIATION_RETAIN);
}

- (CGFloat)velocity {
    return (CGFloat)[objc_getAssociatedObject(self, &velocityKey) floatValue];
}

- (void)animationFinished:(NSString *)animationID finished:(BOOL)finished context:(void *)context {
    if ([animationID isEqualToString:@"toggleSideMenu"]) {
        if([self isKindOfClass:[UINavigationController class]]) {
            UINavigationController *controller = (UINavigationController *)self;
            [controller.visibleViewController setupSideMenuBarButtonItem];
            
            // disable user interaction on the current view controller is the menu is visible
            controller.visibleViewController.view.userInteractionEnabled = (self.menuState == MFSideMenuStateHidden);
        }
    }
}

@end


@implementation UIViewController (MFSideMenuPrivate)

- (CGFloat) xAdjustedForInterfaceOrientation:(CGPoint)point {
    if(UIInterfaceOrientationIsPortrait(self.interfaceOrientation)) {
        return ABS(point.x);
    } else {
        return ABS(point.y);
    }
}

- (void) toggleSideMenu:(BOOL)hidden animationDuration:(NSTimeInterval)duration {
    if(![self isKindOfClass:[UINavigationController class]]) return;
  
  UINavigationController *controller = (UINavigationController *)self;
  // disable user interaction on the current view controller is the menu is visible
  controller.visibleViewController.view.userInteractionEnabled = hidden;
  
    CGFloat x = [self xAdjustedForInterfaceOrientation:self.view.frame.origin];
    CGFloat navigationControllerXPosition = [MFSideMenuManager menuVisibleNavigationControllerXPosition];
    CGFloat animationPositionDelta = (hidden) ? x : (navigationControllerXPosition  - x);
    
    if(ABS(self.velocity) > 1.0) {
        // try to continue the animation at the speed the user was swiping
        duration = animationPositionDelta / ABS(self.velocity);
    } else {
        // no swipe was used, user tapped the bar button item
        CGFloat animationDurationPerPixel = kMenuAnimationDuration / navigationControllerXPosition;
        duration = animationDurationPerPixel * animationPositionDelta;
    }
    
    if(duration > kMenuAnimationMaxDuration) duration = kMenuAnimationMaxDuration;
    
    [UIView beginAnimations:@"toggleSideMenu" context:NULL];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(animationFinished:finished:context:)];
    [UIView setAnimationDuration:duration];
    
    CGRect frame = self.view.frame;
    frame.origin = CGPointZero;
    if (!hidden) {
        switch (self.interfaceOrientation) 
        {
            case UIInterfaceOrientationPortrait:
                frame.origin.x = navigationControllerXPosition;
                break;
                
            case UIInterfaceOrientationPortraitUpsideDown:
                frame.origin.x = -1*navigationControllerXPosition;
                break;
                
            case UIInterfaceOrientationLandscapeLeft:
                frame.origin.y = -1*navigationControllerXPosition;
                break;
                
            case UIInterfaceOrientationLandscapeRight:
                frame.origin.y = navigationControllerXPosition;
                break;
        } 
    }
    self.view.frame = frame;
        
    [UIView commitAnimations];
}

@end 
