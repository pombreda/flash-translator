#import "SWFFreeType.h"
#import "SWFShape.h"

#include <ft2build.h>
#include FT_FREETYPE_H
#include <freetype/ftoutln.h> // no idea why this is needed

@implementation SWFFont (FreeTypeParser)

-(id)initWithFontName:(NSString *)fontname characterSet:(NSIndexSet *)set identifier:(int)identifier
{
	[NSException raise:@"SWFFreeTypeException" format:@"Function not implemented."];
	return nil;
}

int SWFMoveTo(const FT_Vector *to,void *shape);
int SWFLineTo(const FT_Vector *to,void *shape);
int SWFConicTo(const FT_Vector *c,const FT_Vector *to,void *shape);
int SWFCubicTo(const FT_Vector *c1,const FT_Vector *c2,const FT_Vector *to,void *shape);

-(id)initWithFilename:(NSString *)filename fontName:(NSString *)fontname
characterSet:(NSIndexSet *)set identifier:(int)identifier
{
	if(self=[self initWithName:fontname identifier:identifier])
	{
		FT_Library swfft_library;
		FT_Face face;

		if(FT_Init_FreeType(&swfft_library))
		[NSException raise:@"SWFFreeTypeException" format:@"Failed to open FreeType library."];

		#ifdef __MINGW__
		if(FT_New_Face(swfft_library,[filename UTF8String],0,&face)) // Not quite correct, but what can you do? Thanks, GNUStep.
		[NSException raise:@"SWFFreeTypeException" format:@"Failed to load font file \"%@\".",filename];
		#else
		if(FT_New_Face(swfft_library,[filename fileSystemRepresentation],0,&face))
		[NSException raise:@"SWFFreeTypeException" format:@"Failed to load font file \"%@\".",filename];
		#endif

		//if(face->num_faces>1) fprintf( stderr, "WARNING: %s contains %i faces, but only the first is imported.\n", filename, face->num_faces );
		//if( face->charmap == 0 ) fprintf( stderr, "WARNING: %s doesn't seem to contain a unicode charmap.\n", filename );

		int fontsize=1024;

		FT_Set_Char_Size(face,fontsize*64,fontsize*64,75,75);
		FT_Matrix mtx={65536,0,0,-65536};
		FT_Vector vec={0,fontsize*64};
		FT_Set_Transform(face,&mtx,&vec);

		[self setAscent:(face->ascender*fontsize)/face->units_per_EM];
		[self setDescent:(face->descender*fontsize)/face->units_per_EM];
		[self setLeading:(face->height*fontsize)/face->units_per_EM];

		if(FT_Select_Charmap(face,FT_ENCODING_UNICODE))
		[NSException raise:@"SWFFreeTypeException" format:@"Font does not support unicode.",filename];

		for(int i=[set firstIndex];i!=NSNotFound;i=[set indexGreaterThanIndex:i])
		{
			FT_UInt index=FT_Get_Char_Index(face,i);
			if(!index) continue;

			if(FT_Load_Glyph(face,index,FT_LOAD_NO_BITMAP)) 
			[NSException raise:@"SWFFreeTypeException" format:@"Failed to load glyph %d.",i];

			if(face->glyph->format!=FT_GLYPH_FORMAT_OUTLINE )
			[NSException raise:@"SWFFreeTypeException" format:@"Glyph %d is not an outline.",i];

			SWFShape *shape=[[[SWFShape alloc] init] autorelease];
			FT_Outline *outline=&face->glyph->outline;

			FT_Outline_Funcs funcs={
				SWFMoveTo,SWFLineTo,SWFConicTo,SWFCubicTo,
				0,0,
			};

			FT_Outline_Decompose(outline,&funcs,shape);

			int advance=face->glyph->advance.x/64;

			[self addGlyph:shape character:i advance:advance];
		}
	}
	return self;
}

int SWFMoveTo(const FT_Vector *to,void *shape)
{
	[(SWFShape *)shape moveTo:SWFMakePoint(to->x/64,to->y/64)];
	return 0;
}

int SWFLineTo(const FT_Vector *to,void *shape)
{
	[(SWFShape *)shape lineTo:SWFMakePoint(to->x/64,to->y/64)];
	return 0;
}

int SWFConicTo(const FT_Vector *c,const FT_Vector *to,void *shape)
{
	[(SWFShape *)shape quadraticBezierTo:SWFMakePoint(to->x/64,to->y/64)
	control:SWFMakePoint(c->x/64,c->y/64)];
	return 0;
}

int SWFCubicTo(const FT_Vector *c1,const FT_Vector *c2,const FT_Vector *to,void *shape)
{
	[(SWFShape *)shape cubicBezierTo:SWFMakePoint(to->x/64,to->y/64)
	firstControl:SWFMakePoint(c1->x/64,c1->y/64)
	secondControl:SWFMakePoint(c2->x/64,c2->y/64)];
	return 0;
}

@end
