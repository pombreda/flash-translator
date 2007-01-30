ADDITIONAL_OBJCFLAGS += -std=gnu99
ADDITIONAL_OBJC_LIBS += -lz

include $(GNUSTEP_MAKEFILES)/common.make

COMMON_FILES = SWFGeometry.m SWFParser.m SWFText.m SWFFont.m SWFWriter.m CSZlibHandle.m CSFileHandle.m CSMemoryHandle.m CSHandle.m

TOOL_NAME = swfextractssa swfinsertssa swfstrings swfcompress
swfextractssa_OBJC_FILES = swfextractssa.m $(COMMON_FILES)
swfinsertssa_OBJC_FILES = swfinsertssa.m $(COMMON_FILES)
swfstrings_OBJC_FILES = swfstrings.m $(COMMON_FILES)
swfcompress_OBJC_FILES = swfcompress.m $(COMMON_FILES)

# Command line tool make rules
include $(GNUSTEP_MAKEFILES)/tool.make
