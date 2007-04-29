/*
 *  make-sjis-unicode.c
 *  FlashTranslator
 *
 *  Created by Alexander Strange on 4/29/07.
 *  Copyright 2007 __MyCompanyName__. All rights reserved.
 *
 */

#include <stdio.h>
#include <string.h>

//needs http://wakaba-web.hp.infoseek.co.jp/table/sjis-0208-1997-std.txt as input
static unsigned short sjis_unicode_map[0xeaa5];

static void sjis_point(unsigned short i) {printf("\t%#x%c\n",sjis_unicode_map[i], (i == (sizeof(sjis_unicode_map)/sizeof(unsigned short))-1)?' ':',');}

int main(int argc, char *argv[])
{
	if (argc < 2) return 1;
	FILE *dict = fopen(argv[1], "r");
	char *istr;
	size_t s;
	int i;
	const int gap_b = 0xdf, gap_e = 0x8140; // sjis points on either end of the large undefined gap in the middle
	const int gap2_b = 0x9ffc, gap2_e = 0xe040; // and the other gap
	
	while (istr = fgetln(dict, &s)) {
		char buf[s];
		strncpy(buf, istr, s);
		unsigned short sjis, unic;
		
		if (sscanf(buf, "0x%hx U+%hx", &sjis, &unic) == 2) sjis_unicode_map[sjis] = unic;
	}
	
	printf("static unsigned short sjis_unicode_map[] = {\n");	
	for (i = 0; i <= gap_b; i++) sjis_point(i);
	for (i = gap_e; i <= gap2_b; i++) sjis_point(i);
	for (i = gap2_e; i < (sizeof(sjis_unicode_map)/sizeof(unsigned short)); i++) sjis_point(i);
	printf("};\n");
	printf("\nstatic unsigned short sjis2ucs2(unsigned short i)\n{\n");
	printf("\tif (i > %#x) i -= %#x;\n", gap2_e, ((gap2_e - gap2_b) - 1) + ((gap_e - gap_b) - 1));
	printf("\telse if (i > %#x) i -= %#x;\n", gap_e, (gap_e - gap_b) - 1);
	printf("\treturn sjis_unicode_map[i];\n}\n");
	
	return 0;
}