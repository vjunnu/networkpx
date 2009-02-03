/*
 
PrefHooker-iKeyEx.m ... Preferences Hooker for iKeyEx.

Copyright (c) 2009, KennyTM~
All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.
* Redistributions in binary form must reproduce the above copyright notice, 
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.
* Neither the name of the KennyTM~ nor the names of its contributors may be
  used to endorse or promote products derived from this software without
  specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*/

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <substrate.h>

#import <PrefHooker/InternationalKeyboardController.h>
#import <PrefHooker/Settings.h>

void installHook() {
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
	// Install hook for InternationalKeyboardController
	
	Class ikcCls = objc_getClass("InternationalKeyboardController");
	MSHookMessage(ikcCls, @selector(specifiers), [InternationalKeyboardControllerHooked instanceMethodForSelector:@selector(specifiers)], "old_");
	
	class_addMethod(ikcCls,
					@selector(valueForIKeyExKeyboard:),
					[InternationalKeyboardControllerHooked instanceMethodForSelector:@selector(valueForIKeyExKeyboard:)],
					method_getTypeEncoding(class_getInstanceMethod([InternationalKeyboardControllerHooked class], @selector(valueForIKeyExKeyboard:)))
					);
	
	class_addMethod(ikcCls,
					@selector(setValueForIKeyExKeyboard:specifier:),
					[InternationalKeyboardControllerHooked instanceMethodForSelector:@selector(setValueForIKeyExKeyboard:specifier:)],
					method_getTypeEncoding(class_getInstanceMethod([InternationalKeyboardControllerHooked class], @selector(setValueForIKeyExKeyboard:specifier:)))
					);
	
	Class lsCls = objc_getClass("LanguageSelector");
	MSHookMessage(lsCls, @selector(keyboardExistsForLanguage:), [LanguageSelectorHooked instanceMethodForSelector:@selector(keyboardExistsForLanguage:)], "old_");
	
	// Install hook for the front page.
	PHInsertSection(@"iKeyEx", @"iKeyEx", YES);
	
	Class plcClass = objc_getClass("PrefsListController");
	@synchronized(plcClass) {
		// prevent the same method being hooked twice.
		if (![plcClass instancesRespondToSelector:@selector(old_specifiers)])
			MSHookMessage(plcClass, @selector(specifiers), [PrefsListControllerHooked instanceMethodForSelector:@selector(specifiers)], "old_");
	}
		
	[pool release];
}