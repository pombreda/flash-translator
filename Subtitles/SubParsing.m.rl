/*
 *  SubParsing.c
 *  SSARender2
 *
 *  Created by Alexander Strange on 7/25/07.
 *  Copyright 2007 __MyCompanyName__. All rights reserved.
 *
 */

#import "SubParsing.h"
#import "SubUtilities.h"
#import "SubContext.h"

%%machine SSAfile;
%%write data;

@implementation SubRenderSpan
+(SubRenderSpan*)startingSpanForDiv:(SubRenderDiv*)div delegate:(SubRenderer*)delegate
{
	SubRenderSpan *span = [[SubRenderSpan alloc] init];
	span->offset = 0;
	span->ex = [delegate spanExtraFromRenderDiv:div];
	span->delegate = delegate;
	return [span autorelease];
}

-(SubRenderSpan*)cloneWithDelegate:(SubRenderer*)delegate_
{
	SubRenderSpan *span = [[SubRenderSpan alloc] init];
	span->offset = offset;
	span->ex = [delegate_ cloneSpanExtra:self];
	span->delegate = delegate_;
	return [span autorelease];
}

-(void)dealloc
{
	[delegate releaseSpanExtra:ex];
	[super dealloc];
}
@end

@implementation SubRenderDiv
-(NSString*)description
{
	int i, sc = [spans count];
	NSMutableString *tmp = [NSMutableString stringWithFormat:@"div %d spans:",sc];
	for (i = 0; i < sc; i++) {[tmp appendFormat:@" %d",((SubRenderSpan*)[spans objectAtIndex:i])->offset];}
	[tmp appendFormat:@" %d", [text length]];
	return tmp;
}

-(SubRenderDiv*)init
{
	if (self = [super init]) {
		text = nil;
		styleLine = nil;
		marginL = marginR = marginV = layer = 0;
		spans = nil;
		
		posX = posY = -1;
		alignH = kSubAlignmentMiddle; alignV = kSubAlignmentBottom;
		
		is_shape = NO;
		render_complexity = 0;
	}
	
	return self;
}

-(SubRenderDiv*)nextDivWithDelegate:(SubRenderer*)delegate
{
	SubRenderDiv *div = [[[SubRenderDiv alloc] init] autorelease];
	
	div->text    = [[NSMutableString string] retain];
  div->styleLine = [styleLine retain];
	div->marginL = marginL;
	div->marginR = marginR;
	div->marginV = marginV;
	div->layer   = layer;
	
	div->spans   = [[NSMutableArray arrayWithObject:[[spans objectAtIndex:[spans count]-1] cloneWithDelegate:delegate]] retain];
	
	div->posX    = posX;
	div->posY    = posY;
	div->alignH  = alignH;
	div->alignV  = alignV;
  div->wrapStyle = wrapStyle;
  
    div->is_shape = NO;
	div->render_complexity = render_complexity;
	
	return div;
}

-(void)dealloc
{
	[text release];
	[styleLine release];
	[spans release];
	[super dealloc];
}
@end

extern BOOL IsScriptASS(NSDictionary *headers);

static NSArray *SplitByFormat(NSString *format, NSArray *lines)
{
	NSArray *formarray = STSplitStringIgnoringWhitespace(format,@",");
	int i, numlines = [lines count], numfields = [formarray count];
	NSMutableArray *ar = [NSMutableArray arrayWithCapacity:numlines];
	
	for (i = 0; i < numlines; i++) {
		NSString *s = [lines objectAtIndex:i];
		NSArray *splitline = STSplitStringWithCount(s, @",", numfields);
		
		if ([splitline count] != numfields) continue;
		[ar addObject:[NSDictionary dictionaryWithObjects:splitline
												  forKeys:formarray]];
	}
	
	return ar;
}

void SubParseSSAFile(const unichar *ssa, size_t len, NSDictionary **headers, NSArray **styles, NSArray **subs)
{
	const unichar *p = ssa, *pe = ssa + len, *strbegin = p;
	int cs=0;
	
	NSMutableDictionary *hd = [NSMutableDictionary dictionary];
	NSMutableArray *stylearr = [NSMutableArray array], *eventarr = [NSMutableArray array], *cur_array=NULL;
	NSCharacterSet *wcs = [NSCharacterSet whitespaceCharacterSet];
	NSString *str=NULL, *styleformat=NULL, *eventformat=NULL;
	
#define send() [NSString stringWithCharacters:strbegin length:p-strbegin]
	
	%%{
		alphtype unsigned short;
		
		action sstart {strbegin = p;}
		action setheaderval {[hd setObject:send() forKey:str];}
		action savestr {str = send();}
		action csvlineend {[cur_array addObject:[send() stringByTrimmingCharactersInSet:wcs]];}
		action setupevents {
			cur_array=eventarr;
			eventformat = IsScriptASS(hd) ?
				@"Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text":
				@"Marked, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text";
		}
				
		nl = ("\n" | "\r" | "\r\n");
		str = any*;
		ws = space | 0xa0;
		bom = 0xfeff;
		
		hline = ((";" str) | (([^;] str) >sstart %savestr :> (":" ws* str >sstart %setheaderval)?))? :> nl;
		
		header = "[Script Info]" nl hline*;
				
		format = "Format:" ws* %sstart str %savestr :> nl;
				
		action assformat {styleformat = @"Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding";}
		action ssaformat {styleformat = @"Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, TertiaryColour, BackColour, Bold, Italic, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, AlphaLevel, Encoding";}

		stylename = ("[" [Vv] "4 Styles]") %ssaformat | ("[" [Vv] "4+ Styles]") %assformat;
		
		sline = (("Style:" ws* %sstart str %csvlineend) | str) :> nl;
		
		styles = stylename % {cur_array=stylearr;} nl (format %{styleformat=str;})? <: (sline*);
		
		event_txt = (("Dialogue:" ws* %sstart str %csvlineend) | str);
		event = event_txt :> nl;
			
		lines = "[Events]" %setupevents nl (format %{eventformat=str;})? <: (event*);
		
		main := bom? header :> styles :> lines?;
	}%%
		
	%%write init;
	%%write exec;
	%%write eof;

	*headers = hd;
	if (styles) *styles = SplitByFormat(styleformat, stylearr);
	if (subs) *subs = SplitByFormat(eventformat, eventarr);
}

%%machine SSAtag;
%%write data;

static NSMutableString *FilterSlashEscapes(NSMutableString *s)
{
	[s replaceOccurrencesOfString:@"\\n" withString:@"\n" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [s length])];
	unichar nbsp = 0xA0;
	
	[s replaceOccurrencesOfString:@"\\h" withString:[NSString stringWithCharacters:&nbsp length:1] options:0 range: NSMakeRange(0,[s length])];
	return s;
}

static int compare_layer(const void *a, const void *b)
{
	const SubRenderDiv *divA = a, *divB = b;
	
	if (divA->layer < divB->layer) return -1;
	else if (divA->layer > divB->layer) return 1;
	return 0;
}

NSArray *SubParsePacket(NSString *packet, SubContext *context, SubRenderer *delegate, unichar *linebuf)
{
	packet = STStandardizeStringNewlines(packet);
	NSArray *lines = (context->scriptType == kSubTypeSRT) ? [NSArray arrayWithObject:[packet substringToIndex:[packet length]-1]] : [packet componentsSeparatedByString:@"\n"];
	size_t line_count = [lines count];
	NSMutableArray *divs = [NSMutableArray arrayWithCapacity:line_count];
	int i;
	
	for (i = 0; i < line_count; i++) {
		NSString *inputText = [lines objectAtIndex:(context->collisions == kSubCollisionsReverse) ? (line_count - i - 1) : i];
		SubRenderDiv *div = [[[SubRenderDiv alloc] init] autorelease];
		
		div->text = [[NSMutableString string] retain];
		div->spans = [[NSMutableArray array] retain];
		
		if (context->scriptType == kSubTypeSRT) {
			div->styleLine = [context->defaultStyle retain];
			div->marginL = div->styleLine->marginL;
			div->marginR = div->styleLine->marginR;
			div->marginV = div->styleLine->marginV;
			div->layer = 0;
			div->wrapStyle = kSubLineWrapTopWider;
		} else {
			NSArray *fields = STSplitStringWithCount(inputText, @",", 9);
			if ([fields count] < 9) continue;
			div->layer = [[fields objectAtIndex:1] intValue];
			div->styleLine = [[context styleForName:[fields objectAtIndex:2]] retain];
			div->marginL = [[fields objectAtIndex:4] intValue];
			div->marginR = [[fields objectAtIndex:5] intValue];
			div->marginV = [[fields objectAtIndex:6] intValue];
			inputText = [fields objectAtIndex:8];
			if ([inputText length] == 0) continue;
			
			if (div->marginL == 0) div->marginL = div->styleLine->marginL;
			if (div->marginR == 0) div->marginR = div->styleLine->marginR;
			if (div->marginV == 0) div->marginV = div->styleLine->marginV;
			
			div->wrapStyle = context->wrapStyle;
		}
		
		div->alignH = div->styleLine->alignH;
		div->alignV = div->styleLine->alignV;
		
		size_t linelen = [inputText length];
		[inputText getCharacters:linebuf];
		linebuf[linelen] = 0;
		
#undef send
#define send() [NSString stringWithCharacters:outputbegin length:p-outputbegin]
#define psend() [NSString stringWithCharacters:parambegin length:p-parambegin]
#define tag(tagt, p) [delegate spanChangedTag:tag_##tagt span:current_span div:div param:&(p)]
				
		{
			unichar *p = linebuf, *pe = linebuf + linelen, *outputbegin = p, *parambegin=p, *last_cmd_start=p;
			const unichar *pb = p;
			int cs = 0;
			SubRenderSpan *current_span = [SubRenderSpan startingSpanForDiv:div delegate:delegate];
			unsigned chars_deleted = 0; int intnum = 0; float floatnum = 0;
			NSString *strval=NULL;
			unsigned curX, curY;
			BOOL reached_end = NO, startNewLayout = NO;
			
			%%{
				action bold {tag(b, intnum);}
				action italic {tag(i, intnum);}
				action underline {tag(u, intnum);}
				action strikeout {tag(s, intnum);}
				action outlinesize {tag(bord, floatnum);}
				action shadowdist {tag(shad, floatnum);}
				action bluredge {tag(be, intnum);}
				action fontname {tag(fn, strval);}
				action fontsize {tag(fs, floatnum);}
				action scalex {tag(fscx, floatnum);}
				action scaley {tag(fscy, floatnum);}
				action tracking {tag(fsp, floatnum);}
				action frz {tag(frz, floatnum);}
				action frx {tag(frx, floatnum);}
				action fry {tag(fry, floatnum);}
				action primaryc {tag(1c, intnum);}
				action secondaryc {tag(2c, intnum);}
				action outlinec {tag(3c, intnum);}
				action shadowc {tag(4c, intnum);}
				action alpha {tag(alpha, intnum);}
				action primarya {tag(1a, intnum);}
				action secondarya {tag(2a, intnum);}
				action outlinea {tag(3a, intnum);}
				action shadowa {tag(4a, intnum);}
				action stylerevert {tag(r, strval);}

				action paramset {parambegin=p;}
				action setintnum {intnum = [psend() intValue];}
				action sethexnum {intnum = strtoul([psend() UTF8String], NULL, 16);}
				action setfloatnum {floatnum = [psend() floatValue];}
				action setstringval {strval = psend();}
				action setxypos {curX=curY=-1; sscanf([psend() UTF8String], "(%d,%d)", &curX, &curY);}
				
				action ssaalign {
					if (outputbegin == pb) ParseASSAlignment(SSA2ASSAlignment(intnum), &div->alignH, &div->alignV);
				}
				
				action align {
					if (outputbegin == pb) ParseASSAlignment(intnum, &div->alignH, &div->alignV);
				}
				
				action wrapstyle {
					if (!startNewLayout) {
						startNewLayout = YES;
						
						if ([div->text length] > 0) {[divs addObject:div]; div = [div nextDivWithDelegate:delegate];}
					}
					
					div->wrapStyle = intnum;
				}
				
				action position {
					if (!startNewLayout) {
						startNewLayout = YES;
						
						if ([div->text length] > 0) {[divs addObject:div]; div = [div nextDivWithDelegate:delegate];}
					}
					
					div->posX = curX;
					div->posY = curY;
				}

				intnum = ("-"? [0-9]+) >paramset %setintnum;
				flag = [01] >paramset %setintnum;
				floatnum = ([0-9]+ ("." [0-9]*)?) >paramset %setfloatnum;
				string = ([^\\}]*) >paramset %setstringval;
				color = ("H"|"&"){,2} (xdigit+) >paramset %sethexnum "&"?;
				parens = "(" [^)]* ")";
				xypos = ("(" [0-9]+ "," [0-9]+ ")") >paramset %setxypos;
				
				cmd = "\\" (
							"b" intnum %bold
							|"i" flag %italic
							|"u" flag %underline
							|"s" flag %strikeout
							|"bord" floatnum %outlinesize
							|"shad" floatnum %shadowdist
							|"be" flag %bluredge
							|"fn" string %fontname
							|"fs" floatnum %fontsize
							|"fscx" floatnum %scalex
							|"fscy" floatnum %scaley
							|"fsp" floatnum %tracking
							|("fr" "z"? floatnum %frz)
							|"frx" floatnum %frx
							|"fry" floatnum %fry
							|"fe" intnum
							|("1"? "c" color %primaryc)
							|"2c" color %secondaryc
							|"3c" color %outlinec
							|"4c" color %shadowc
							|"alpha" color %alpha
							|"1a" color %primarya
							|"2a" color %secondarya
							|"3a" color %outlinea
							|"4a" color %shadowa
							|"a" intnum %ssaalign
							|"an" intnum %align
							|([kK] [fo]? intnum)
							|"q" intnum %wrapstyle
							|"r" string %stylerevert
							|"pos" xypos %position
							|"t" parens
							|"org" parens
							|("fad" "e"? parens)
							|"clip" parens
							|"p" floatnum
							|"pbo" floatnum
					   );
				
				cmd_list = "{" (cmd* | any*) :> "}";

				action backslash_handler {
					[div->text appendString:send()];					
					unichar c = *(p+1), o=c;
					
					if (c) {
						switch (c) {
							case 'N': case 'n':
								o = '\n';
								break;
							case 'h':
								o = 0xA0; //non-breaking space
								break;
							default:
								o = c;
						}
					}
					
					[div->text appendFormat:@"%C",o];
					
					chars_deleted++;
					
					outputbegin = p+2;
				}
				
				action enter_tag {					
					if (p > outputbegin) [div->text appendString:send()];
					
					if (p != pb) {
						[div->spans addObject:current_span];
						current_span = [current_span cloneWithDelegate:delegate];
					}
					
					last_cmd_start = p;
					if (p == pe) reached_end = YES;
				}
				
				action exit_tag {			
					p++;
					chars_deleted += (p - last_cmd_start);
					
					current_span->offset = (p - pb) - chars_deleted;
					outputbegin = p;
					
					if (startNewLayout) {
						startNewLayout = NO;
						chars_deleted = outputbegin - pb;
					}
					
					p--;
				}
								
				special = ("\\" any) >backslash_handler | cmd_list >enter_tag @exit_tag;
				sub_text_char = [^\\{];
				sub_text = sub_text_char*;
				
				main := ((sub_text | special)* "\\"?) %/enter_tag;
			}%%
				
			%%write init;
			%%write exec;
			%%write eof;

			if (!reached_end) NSLog(@"parse error: %@",inputText);
			if (linebuf[linelen-1] == '\\') [div->text appendString:@"\\"];
			[divs addObject:div];
		}
		
	}
	
	STSortMutableArrayStably(divs, compare_layer);
	return divs;
}
