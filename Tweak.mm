//
//	Tweak.mm
//	StripeCount (w/o Logos)
//
//	Created by Lightmann during COVID-19
//

#import <substrate.h>
#import "Tweak.h"

CGFloat labelXOffset;
CGFloat labelWidth;

static UILabel *_stripeCount;

static void (*orig__UITableViewHeaderFooterViewLabel_setFrame)(_UITableViewHeaderFooterViewLabel *, SEL, CGRect *);
static void hook__UITableViewHeaderFooterViewLabel_setFrame(_UITableViewHeaderFooterViewLabel *, SEL, CGRect *);

static UILabel* new_ZBPackageListTableViewController_stripeCount(ZBPackageListTableViewController *, SEL);
static void new_ZBPackageListTableViewController_setStripeCount(ZBPackageListTableViewController *, SEL, UILabel *);

static void (*orig_ZBPackageListTableViewController_viewDidAppear)(ZBPackageListTableViewController *, SEL, BOOL);
static void hook_ZBPackageListTableViewController_viewDidAppear(ZBPackageListTableViewController *, SEL, BOOL);

static void new_ZBPackageListTableViewController_reconfigureStripeCount(ZBPackageListTableViewController *, SEL);

// get values we'll use for positioning later
static void hook__UITableViewHeaderFooterViewLabel_setFrame(_UITableViewHeaderFooterViewLabel *self, SEL cmd, CGRect *frame) {
	orig__UITableViewHeaderFooterViewLabel_setFrame(self, cmd, frame);

	if([[self _viewControllerForAncestor] isMemberOfClass:objc_getClass("ZBPackageListTableViewController")]){
		labelXOffset = self.frame.origin.x;
		labelWidth = self.frame.size.width;
	}
}

// getter and setter for new UILabel *stripeCount property
static UILabel* new_ZBPackageListTableViewController_stripeCount(ZBPackageListTableViewController *self, SEL cmd) {
	return _stripeCount;
}

static void new_ZBPackageListTableViewController_setStripeCount(ZBPackageListTableViewController *self, SEL cmd, UILabel *newLabel) {
	if (_stripeCount != newLabel) _stripeCount = newLabel;
}

// where the magic happens . . .
static void hook_ZBPackageListTableViewController_viewDidAppear(ZBPackageListTableViewController *self, SEL cmd, BOOL appeared) {
	orig_ZBPackageListTableViewController_viewDidAppear(self, cmd, appeared);

	// if we're on the packages page (index 3) and stripeCount hasn't been made yet...
	if(self.tabBarController.selectedIndex == 3 && !self.stripeCount){
		// Create label
		self.stripeCount = [[UILabel alloc] initWithFrame:CGRectZero];
		[self.view addSubview:self.stripeCount];

		[self.stripeCount setTranslatesAutoresizingMaskIntoConstraints:NO];
		[self.stripeCount.heightAnchor constraintEqualToConstant:20].active = YES;
		[self.stripeCount.widthAnchor constraintEqualToConstant:self.view.bounds.size.width].active = YES;
		[self.stripeCount.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:-12].active = YES;

		// RTL Support
		if([UIApplication sharedApplication].userInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft){
			[self.stripeCount.rightAnchor constraintEqualToAnchor:self.view.rightAnchor constant:labelXOffset+labelWidth].active = YES;
		}
		else{
			[self.stripeCount.leftAnchor constraintEqualToAnchor:self.view.leftAnchor constant:labelXOffset].active = YES;
		}

		// configure label based on our boolean (default is false)
		if([[NSUserDefaults standardUserDefaults] boolForKey:@"sc_dylib_config"]){
			// get # of dylibs -- since the folder contains a .plist for every .dylib we divide by 2 to get just the dylib count
			int dylibCount = ([[[NSFileManager defaultManager] contentsOfDirectoryAtPath:@"/Library/MobileSubstrate/DynamicLibraries" error:nil] count]/2);
			[self.stripeCount setText:[NSString stringWithFormat:@"Dylibs: %d", dylibCount]];
		}
		else{
			int totalCount = MSHookIvar<int>(self, "numberOfPackages");
			[self.stripeCount setText:[NSString stringWithFormat:@"Total: %d", totalCount]];
		}

		// create and add tap gesture to tableview
		UITapGestureRecognizer *configGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(reconfigureStripeCount)];
		configGesture.numberOfTapsRequired = 2;
		[self.view addGestureRecognizer:configGesture];
	}
}

// respond to tap gesture
static void new_ZBPackageListTableViewController_reconfigureStripeCount(ZBPackageListTableViewController *self, SEL cmd) {
	// if config is set to total, change to dylib
	if(![[NSUserDefaults standardUserDefaults] boolForKey:@"sc_dylib_config"]){
		int dylibCount = ([[[NSFileManager defaultManager] contentsOfDirectoryAtPath:@"/Library/MobileSubstrate/DynamicLibraries" error:nil] count]/2);
		[self.stripeCount setText:[NSString stringWithFormat:@"Dylibs: %d", dylibCount]];
		[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"sc_dylib_config"];
	}
	// if config is set to dylib, change to total
	else{
		int totalCount = MSHookIvar<int>(self, "numberOfPackages");
		[self.stripeCount setText:[NSString stringWithFormat:@"Total: %d", totalCount]];
		[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"sc_dylib_config"];
	}
}

// ctor
__attribute__((constructor)) static void init() {
	// _UITableViewHeaderFooterViewLabel | setFrame:
	MSHookMessageEx(
		objc_getClass("_UITableViewHeaderFooterViewLabel"), // hook class
		@selector(setFrame:), // target this method
		(IMP)&hook__UITableViewHeaderFooterViewLabel_setFrame, // implementation to override orig
		(IMP *)&orig__UITableViewHeaderFooterViewLabel_setFrame // orig
	);

	// @property (nonatomic, retain) UILabel *stripeCount;
	// note: can't add an ivar to an existing class at runtime,
	// so we back property with _stripeCount static var declared above
	objc_property_attribute_t type = { "T", "@\"UILabel\"" };
	objc_property_attribute_t characteristics = { "N", "&" }; // N = nonatomic | & = retain
	// useful link: https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtPropertyIntrospection.html#//apple_ref/doc/uid/TP40008048-CH101-SW6
	objc_property_attribute_t attributes[] = { type, characteristics };
	class_addProperty(
		objc_getClass("ZBPackageListTableViewController"),
		"stripeCount",
		attributes,
		2
	);

	// UILabel *stripeCount getter
	class_addMethod(
		objc_getClass("ZBPackageListTableViewController"),
		@selector(stripeCount),
		(IMP)&new_ZBPackageListTableViewController_stripeCount,
		"@@:" // characters to describe the type(s) in the new method. in this case, stripeCount returns a UILabel and doesn't accept an argument
		// useful link: https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html
	);

	// UILabel *stripeCount setter
	class_addMethod(
		objc_getClass("ZBPackageListTableViewController"),
		@selector(setStripeCount:),
		(IMP)&new_ZBPackageListTableViewController_setStripeCount,
		"v@:@" // setStripeCount: returns void and accepts a UILabel argument
	);

	// ZBPackageListTableViewController | viewDidAppear:
	MSHookMessageEx(
		objc_getClass("ZBPackageListTableViewController"),
		@selector(viewDidAppear:),
		(IMP)&hook_ZBPackageListTableViewController_viewDidAppear,
		(IMP *)&orig_ZBPackageListTableViewController_viewDidAppear
	);

	// reconfigureStripeCount
	class_addMethod(
		objc_getClass("ZBPackageListTableViewController"),
		@selector(reconfigureStripeCount),
		(IMP)&new_ZBPackageListTableViewController_reconfigureStripeCount,
		"v@:" // reconfigureStripeCount returns void and doesn't accept an argument
	);
}
