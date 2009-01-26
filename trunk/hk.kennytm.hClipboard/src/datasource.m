/*
 
 datasource.m ... Datasource for hCClipboardViews in ℏClipboard.
 
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


#import "datasource.h"
#import "clipboard.h"
#import <UIKit/UIStringDrawing.h>
#import <iKeyEx/KeyboardLoader.h>
#import <iKeyEx/common.h>

@implementation hCClipboardDataSource
@synthesize clipboard, usesPrefix, secure, dataCache;

-(void)updateDataCache {
	[dataCache release];
	[filteredSet release];
	if (secure) {
		filteredSet = [[clipboard indicesWithNonsecureData] retain];
		NSMutableArray* dataCacheNotReversed = [[[clipboard allData] objectsAtIndexes:filteredSet] mutableCopy];
		NSUInteger dataCount = [dataCacheNotReversed count];
		for (NSUInteger i = 0; i < dataCount/2; ++ i)
			[dataCacheNotReversed exchangeObjectAtIndex:i withObjectAtIndex:dataCount-1-i];
		dataCache = [dataCacheNotReversed copy];
		[dataCacheNotReversed release];
	} else {
		filteredSet = [[clipboard allIndices] retain];
		dataCache = [[clipboard allDataReversed] retain];
	}
}

-(BOOL)switchClipboard {
	[clipboard release];
	if (usesPrefix) {
		clipboard = [[Clipboard alloc] initWithPath:iKeyEx_DataPath@"hClipboard-templates.plist" defaultCapacity:UINT_MAX];
	} else {
		clipboard = [[Clipboard alloc] initDefaultClipboard];
	}
	[self updateDataCache];
	usesPrefix = !usesPrefix;
	return usesPrefix;
}

-(id)init {
	if ((self = [super init])) {
		// is there a better method to determine if Emoji is supported? (Except checking system version).
		supportsEmoji = [@"" respondsToSelector:@selector(drawAtPoint:forWidth:withFont:lineBreakMode:letterSpacing:includeEmoji:)];
		[self switchClipboard];
	}
	return self;
}
-(void)dealloc {
	[dataCache release];
	[clipboard release];
	[filteredSet release];
	[super dealloc];
}


-(NSInteger)numberOfSectionsInTableView:(UITableView*)tbl { return 1; }
-(NSInteger)tableView:(UITableView*)tbl numberOfRowsInSection:(NSInteger)section { return [dataCache count]; }

-(UITableViewCell*)tableView:(UITableView*)tbl cellForRowAtIndexPath:(NSIndexPath*)indexPath {
	// design flaw? why is the MODEL responsible for creating a VIEW?
	UITableViewCell* cell = [tbl dequeueReusableCellWithIdentifier:@"hCC"];
	if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"hCC"] autorelease]; 
		cell.font = [UIFont boldSystemFontOfSize:[UIFont systemFontSize]];
		cell.textColor = [UIColor whiteColor];
		cell.lineBreakMode = UILineBreakModeMiddleTruncation;
	}
	NSUInteger row = indexPath.row;
	
	cell.selectionStyle = UITableViewCellSelectionStyleGray;
	cell.selectedTextColor = [UIColor blackColor];
	cell.showsReorderControl = YES;
	
	NSString* txt = [[dataCache objectAtIndex:row] description];
	if (secure && [clipboard isSecureAtReversedIndex:row]) {
		txt = [[KeyboardBundle activeBundle] localizedStringForKey:@"<Secure Text with %d characters>"];
		cell.font = [UIFont italicSystemFontOfSize:[UIFont systemFontSize]];
		cell.textColor = [UIColor lightGrayColor];
	} else {
		NSUInteger txtLen = [txt length];
		if (txtLen > 200) {
			txt = [[txt substringToIndex:100] stringByAppendingString:[txt substringFromIndex:txtLen-100]];
		}
	}
		
	if (usesPrefix) {
		wchar_t emojiIcon = (wchar_t)row;
		if (supportsEmoji) {
			emojiIcon += 0xE21C;	// 0xE21C = [1] in Emoji
		} else {
			emojiIcon += 0x2460;	// 0x2460 = Circled 1 in Unicode.
		}
		cell.text = [NSString stringWithFormat:@"%C  %@", emojiIcon, txt];
	} else {
		cell.text = txt;
	}
	return cell;
}

-(void)tableView:(UITableView*)tbl commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath*)indexPath {
	//[super tableView:tbl commitEditingStyle:style forRowAtIndexPath:indexPath];
	
	if (style == UITableViewCellEditingStyleDelete) {
		NSUInteger row = [indexPath row];
		if (secure) {
			NSUInteger curIndex = [filteredSet firstIndex];
			for (NSUInteger i = 0; i < row; ++ i)
				curIndex = [filteredSet indexGreaterThanIndex:curIndex];
			row = curIndex;
			[clipboard removeEntryAtIndex:row];
		} else
			[clipboard removeEntryAtReversedIndex:row];
		
		[self updateDataCache];
		// reloadData so that the indices are properly updated. 
		[tbl deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationRight];
		[tbl performSelector:@selector(reloadData) withObject:nil afterDelay:0.5];
	}
}

-(void)tableView:(UITableView*)tbl moveRowAtIndexPath:(NSIndexPath*)ipFrom toIndexPath:(NSIndexPath*)ipTo {
	NSUInteger rowFrom = [ipFrom row], rowTo = [ipTo row];
	if (rowFrom == rowTo)
		return;
	
	NSLog(@"%d -> %d", rowFrom, rowTo);
	
	if (secure) {
		NSUInteger ciFrom = [filteredSet firstIndex];
		NSUInteger ciTo;
		NSUInteger i = 0;
		if (rowFrom < rowTo) {
			for (; i < rowFrom; ++ i)
				ciFrom = [filteredSet indexGreaterThanIndex:ciFrom];
			ciTo = ciFrom;
			for (; i < rowTo; ++i)
				ciTo = [filteredSet indexGreaterThanIndex:ciTo];	
		} else {
			ciTo = ciFrom;
			for (; i < rowTo; ++ i)
				ciTo = [filteredSet indexGreaterThanIndex:ciTo];
			ciFrom = ciTo;
			for (; i < rowFrom; ++i)
				ciFrom = [filteredSet indexGreaterThanIndex:ciFrom];
		}
		[clipboard moveEntryFromIndex:ciFrom toIndex:ciTo];
	} else {
		[clipboard moveEntryFromReversedIndex:rowFrom toReversedIndex:rowTo];
	}
	
	[self updateDataCache];
	
	[tbl performSelector:@selector(reloadData) withObject:nil afterDelay:0.5];
}


@end
