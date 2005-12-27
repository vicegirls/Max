/*
 *  $Id$
 *
 *  Copyright (C) 2005 Stephen F. Booth <me@sbooth.org>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#import "UtilityFunctions.h"

#import "FreeDBException.h"
#import "MallocException.h"
#import "IOException.h"
#import "LAMEException.h"
#import "EmptySelectionException.h"
#import "CustomNamingException.h"
#import "MissingResourceException.h"
#import "ParanoiaException.h"
#import "FLACException.h"
#import "VorbisException.h"
#import "FileFormatNotSupportedException.h"
#import "CoreAudioException.h"

#include "sndfile.h"

static NSDateFormatter		*sDateFormatter		= nil;
static NSString				*sDataDirectory		= nil;

NSString *
getApplicationDataDirectory()
{
	@synchronized(sDataDirectory) {
		if(nil == sDataDirectory) {
			BOOL					isDir;
			NSFileManager			*manager;
			NSArray					*paths;
			
			manager			= [NSFileManager defaultManager];
			paths			= NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
			sDataDirectory	= [[[paths objectAtIndex:0] stringByAppendingString:@"/Max"] retain];

			if(NO == [manager fileExistsAtPath:sDataDirectory isDirectory:&isDir]) {
				if(NO == [manager createDirectoryAtPath:sDataDirectory attributes:nil]) {
//					NSError *error = [NSError errorWithDomain:@"Initialization" code:0 userInfo:nil];
//					[[NSDocumentController sharedDocumentController] presentError:error];
					@throw [IOException exceptionWithReason:@"Unable to create application data directory" userInfo:nil];
				}
			}
			else if(NO == isDir) {
//				NSError *error = [NSError errorWithDomain:@"Initialization" code:0 userInfo:nil];
//				[[NSDocumentController sharedDocumentController] presentError:error];
				@throw [IOException exceptionWithReason:@"Unable to create application data directory" userInfo:nil];
			}
		}
	}
	return [[sDataDirectory retain] autorelease];
}

void 
createDirectoryStructure(NSString *path)
{
	NSString		*pathPart;
	NSArray			*pathComponents		= [path pathComponents];
	
	if(1 < [pathComponents count]) {
		int				i;
		int				directoryCount		= [pathComponents count] - 1;

		// Accept a '/' as the first path
		if(NO == [[pathComponents objectAtIndex:0] isEqualToString:@"/"]) {
			pathPart = makeStringSafeForFilename([pathComponents objectAtIndex:0]);
		}
		else {
			pathPart = [pathComponents objectAtIndex:0];
		}		
		validateAndCreateDirectory(pathPart);
		
		// Iterate through all the components
		for(i = 1; i < directoryCount - 1; ++i) {
			pathPart = [NSString stringWithFormat:@"%@/%@", pathPart, makeStringSafeForFilename([pathComponents objectAtIndex:i])];				
			validateAndCreateDirectory(pathPart);
		}
		
		// Ignore trailing '/'
		if(NO == [[pathComponents objectAtIndex:directoryCount - 1] isEqualToString:@"/"]) {
			pathPart = [NSString stringWithFormat:@"%@/%@", pathPart, makeStringSafeForFilename([pathComponents objectAtIndex:directoryCount - 1])];
			validateAndCreateDirectory(pathPart);
		}
	}
}

NSString * 
makeStringSafeForFilename(NSString *string)
{
	NSCharacterSet		*characterSet		= [NSCharacterSet characterSetWithCharactersInString:@"/:"];
	NSMutableString		*result				= [NSMutableString stringWithCapacity:[string length]];
	NSRange				range;
	
	[result setString:string];
	
	range = [result rangeOfCharacterFromSet:characterSet];		
	while(range.location != NSNotFound && range.length != 0) {
		[result replaceCharactersInRange:range withString:@"_"];
		range = [result rangeOfCharacterFromSet:characterSet];		
	}
	
	return [[result retain] autorelease];
}

NSString * 
generateUniqueFilename(NSString *basename, NSString *extension)
{
	NSFileManager		*manager			= [NSFileManager defaultManager];
	unsigned			num					= 1;
	NSString			*result;
	
	result = [NSString stringWithFormat:@"%@.%@", basename, extension];
	for(;;) {
		if(NO == [manager fileExistsAtPath:result]) {
			break;
		}
		result = [NSString stringWithFormat:@"%@-%u.%@", basename, num, extension];
		++num;
	}
	
	return [[result retain] autorelease];
}

void
validateAndCreateDirectory(NSString *path)
{
	NSFileManager		*manager			= [NSFileManager defaultManager];
	BOOL				isDir;

	if(NO == [manager fileExistsAtPath:path isDirectory:&isDir]) {
		if(NO == [manager createDirectoryAtPath:path attributes:nil]) {
			@throw [NSException exceptionWithName:@"NSObjectInaccessibleException" reason:@"Unable to create directory" userInfo:nil];
		}
	}
	else if(FALSE == isDir) {
		@throw [NSException exceptionWithName:@"NSObjectInaccessibleException" reason:@"Unable to create directory" userInfo:nil];
	}	
}

NSArray *
getLibsndfileExtensions()
{
	NSMutableArray			*result;
	SF_FORMAT_INFO			formatInfo;
	SF_INFO					info;
	int						i, majorCount;

	sf_command(NULL, SFC_GET_FORMAT_MAJOR_COUNT, &majorCount, sizeof(int)) ;

	result = [NSMutableArray arrayWithCapacity:majorCount];
	
	// Generic defaults
	info.channels		= 1 ;
	info.samplerate		= 0;
	
	// Loop through each major mode
	for(i = 0; i < majorCount; ++i) {	
		formatInfo.format = i;
		sf_command(NULL, SFC_GET_FORMAT_MAJOR, &formatInfo, sizeof(formatInfo));
		[result addObject:[NSString stringWithUTF8String:formatInfo.extension]];
	}

	return [[result retain] autorelease];
}

void
displayExceptionAlert(NSException *exception)
{
	displayExceptionSheet(exception, nil, nil, nil, nil);
}

void 
displayExceptionSheet(NSException	*exception,
					  NSWindow		*window,
					  id			delegate,
					  SEL			selector,
					  void			*contextInfo)
{
	NSBeep();
	
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle: @"OK"];
	if([exception isKindOfClass:[FreeDBException class]]) {
		[alert setMessageText: @"FreeDB Error"];
	}
	else if([exception isKindOfClass:[IOException class]]) {
		[alert setMessageText: @"Input/Output Error"];
	}
	else if([exception isKindOfClass:[MallocException class]]) {
		[alert setMessageText: @"Memory Error"];
	}
	else if([exception isKindOfClass:[LAMEException class]]) {
		[alert setMessageText: @"LAME Error"];
	}
	else if([exception isKindOfClass:[EmptySelectionException class]]) {
		[alert setMessageText: @"Empty Selection"];
	}
	else if([exception isKindOfClass:[CustomNamingException class]]) {
		[alert setMessageText: @"Custom Naming Error"];
	}
	else if([exception isKindOfClass:[MissingResourceException class]]) {
		[alert setMessageText: @"Missing Resource"];
	}
	else if([exception isKindOfClass:[ParanoiaException class]]) {
		[alert setMessageText: @"cdparanoia Error"];
	}
	else if([exception isKindOfClass:[FLACException class]]) {
		[alert setMessageText: @"FLAC Error"];
	}
	else if([exception isKindOfClass:[VorbisException class]]) {
		[alert setMessageText: @"Ogg Vorbis Error"];
	}
	else if([exception isKindOfClass:[FileFormatNotSupportedException class]]) {
		[alert setMessageText: @"File Format Error"];
	}
	else if([exception isKindOfClass:[CoreAudioException class]]) {
		[alert setMessageText: @"Core Audio Error"];
	}
	else {
		[alert setMessageText: @"Unknown Error"];
	}
	[alert setInformativeText: [exception reason]];
	[alert setAlertStyle: NSWarningAlertStyle];
	
	if(nil == window) {
		if([alert runModal] == NSAlertFirstButtonReturn) {
			// do nothing
		} 
	}
	else {
		[alert beginSheetModalForWindow:window modalDelegate:delegate didEndSelector:selector contextInfo:contextInfo];
	}
}

NSString *
getID3v2Timestamp()
{
	@synchronized(sDateFormatter) {
		if(nil == sDateFormatter) {
			[NSDateFormatter setDefaultFormatterBehavior:NSDateFormatterBehavior10_4];
			sDateFormatter = [[NSDateFormatter alloc] init];
			[sDateFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"GMT"]];
			[sDateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss"];
		}
	}
	return [sDateFormatter stringFromDate:[NSDate date]];
}
