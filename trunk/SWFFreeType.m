#import "SWFFreeType.h"
#import "SWFShape.h"

#include <ft2build.h>
#include FT_FREETYPE_H

@implementation SWFFont (FreeTypeLoader)

	void importGlyphPoints( FT_Vector *points, int n, SWFShape *shape, BOOL cubic ) {
 	        if( n==0 )  {
 	                [shape lineTo:SWFMakePoint( points[0].x/64, points[0].y/64 )];
 	        } else if( n==1 ) {
 	                [shape curveTo:SWFMakePoint(points[1].x/64, points[1].y/64 )
 	                        control:SWFMakePoint(points[0].x/64, points[0].y/64)];
 	        } else if( n>=2 ) {
 	                if( cubic ) {
 	                        //fprintf(stderr,"ERROR: cubic beziers in fonts are not yet implemented.\n");
 	                } else {
 	                        int x1, y1, x2, y2, midx, midy;
	                        for( int i=0; i<n-1; i++ ) {
 	                                x1 = points[i].x;
 	                                y1 = points[i].y;
 	                                x2 = points[i+1].x;
 	                                y2 = points[i+1].y;
	                                midx = x1 + ((x2-x1)/2);
	                                midy = y1 + ((y2-y1)/2);
	                                [shape curveTo:SWFMakePoint(midx/64, midy/64 )
									control:SWFMakePoint( x1/64, y1/64)];
	                        }
 	                [shape curveTo:SWFMakePoint(points[n].x/64, points[n].y/64 )
 	                        control:SWFMakePoint(x2/64, y2/64)];
 	                }
 	        } else {
 	        }
 	}

-(id)initWithFontName:(NSString *)fontname characterSet:(NSIndexSet *)set identifier:(int)identifier
{
	[NSException raise:@"SWFFreeTypeException" format:@"Function not implemented."];
	return nil;
}

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

/*			int countour=0;
			for(int j=0;j<outline->n_points;j++)
			{
				if(j==outline->contours[countour])
				{
					

					countour++;
					if(countour>=outline->n_contours) break;
				}*/
			int start = 0, end;
			BOOL control, cubic;
			for(int j=0;j<outline->n_contours;j++)
			{
				end = outline->contours[j];
				//fprintf(stderr,"  contour %i: %i-%i\n", contour, start, end );
				int n=0;
 	
				for(int p=start;p<=end;p++)
				{
					control = !(outline->tags[p] & 0x01);
					cubic = outline->tags[p] & 0x02;
					if( p==start ) {
						[shape moveTo:SWFMakePoint(outline->points[p-n].x/64, outline->points[p-n].y/64)];
					}
					if( !control && n > 0 ) {
						importGlyphPoints( &(outline->points[(p-n)+1]), n-1, shape, cubic );
						n=1;
					} else {
						n++;
					}
				}
 	                               
				if(n)
				{
					// special case: repeat first point
					FT_Vector points[n+1];
					int s=(end-n)+2;
					for( int i=0; i<n-1; i++ ) {
						points[i].x = outline->points[s+i].x;
						points[i].y = outline->points[s+i].y;
					}
					points[n-1].x = outline->points[start].x;
					points[n-1].y = outline->points[start].y;
 	                                       
					importGlyphPoints( points, n-1, shape, false );
				}
 	                               
				start = end+1;
			}

			int advance=face->glyph->advance.x/64;

			[self addGlyph:shape character:i advance:advance];
		}
	}
	return self;
}

@end
