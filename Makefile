# using from project subdirectory:
#	make CONF=debug build
#	make CONF=release build
#	make clean

include Makefile.linux

############## DON'T EDIT UNDER ######################

SOURCE_FILES=$(filter-out $(IGNORE_FILES),$(wildcard *.cpp))
HEADER_FILES=$(filter-out $(IGNORE_FILES),$(wildcard *.h *.hpp))

MOCKS=$(patsubst %.h,%_mock.h,$(patsubst %.hpp,%_mock.hpp,$(filter-out stdafx.h ui_%.h,$(HEADERS))))

UIS=$(filter-out $(IGNORE_FILES),$(wildcard *.ui))
HEADER_FILES+=$(patsubst %.ui,ui_%.h,$(UIS))

MOC_HEADERS=$(shell grep "Q_OBJECT" -l $(HEADERS) 2>/dev/null)
MOCS=$(patsubst %.h,moc_%.cpp,$(MOC_HEADERS))
SOURCE_FILES+=$(MOCS)

QRCS=$(filter-out $(IGNORE_FILES),$(wildcard *.qrc))
QRC_SOURCES=$(patsubst %.qrc,qrc_%.cpp,$(QRCS))
SOURCE_FILES+=$(QRC_SOURCES)

BINS=$(filter-out $(IGNORE_FILES),$(wildcard *.hex *.xsvf))
BIN_HEADERS=$(patsubst %.xsvf,%.h,$(patsubst %.hex,%.h,$(BINS)))
BIN_SOURCES=$(patsubst %.xsvf,%.cpp,$(patsubst %.hex,%.cpp,$(BINS)))

HEADER_FILES+=$(BIN_HEADERS)
SOURCE_FILES+=$(BIN_SOURCES)

TARGETDIR=bin/objects
#VPATH = $(TARGETDIR)
SOURCES=$(sort $(SOURCE_FILES))
HEADERS=$(sort $(HEADER_FILES))

######## Configuration controlling #########

CXXFLAGS=$(CXXFLAGS_BASE)
LDFLAGS=$(LDFLAGS_BASE) 
DEPDIR=deps
DEPS:=$(patsubst %.cpp,$(DEPDIR)/%.d,$(SOURCE_FILES))

ifeq ($(CONF),release)
    CXXFLAGS+=$(CXXFLAGS_RELEASE)
    LDFLAGS+= $(LDFLAGS_RELEASE)
else 
    CXXFLAGS+=$(CXXFLAGS_DEBUG)
    LDFLAGS+= $(LDFLAGS_DEBUG)
endif


TARGETDIR=bin/$(CONF)
OBJECTS+=$(addprefix $(TARGETDIR)/,$(subst .c,.o,$(subst .cpp,.o,$(SOURCES))))

.PHONY: release
release : 
	@$(MAKE) CONF=release rebuild

.PHONY: debug
debug : 
	@$(MAKE) CONF=debug build
	
.PHONY: show_conf
show_conf:
	@echo "CONF      = $(CONF)"
	@echo "TARGETDIR = $(TARGETDIR)"
	@echo "CXXFLAGS  = $(CXXFLAGS)"
	@echo "EXECUTABLE= $(EXECUTABLE)"

$(TARGETDIR):
	mkdir -p $(TARGETDIR)

.PHONY: all 
all: rebuild

.PHONY: rebuild
rebuild: clean build 

.PHONY: build
build: $(TARGETDIR) $(HEADERS) $(SOURCES) $(EXECUTABLE) $(LIBRARY)

$(DEPDIR)/%.d : %.cpp
	@echo "cleate dependency $@"
	@mkdir -p $(DEPDIR)
	@$(CXX) $(CXXFLAGS) -M $< | sed -e 's%\($*\)\.o[ :]*%$(TARGETDIR)/\1.o $@ : %g' > $@
	
.PHONY: depclean
depclean:
	@$(RM) -r $(DEPDIR)
 
.PHONY: clean
clean:
	@echo "Clear generated files" 
	@$(RM) -r $(TARGETDIR) $(DEPDIR) $(EXECUTABLE) $(LIBRARY) $(OBJECTS) $(MOCKS) $(MOCS) $(BIN_HEADERS) $(BIN_SOURCES) \
		$(QRC_SOURCES) *.bak


$(EXECUTABLE): $(OBJECTS)
	@echo "here has to be linking an executable"
	$(CXX) -o $(TARGETDIR)/$@ $^ $(addsuffix /$(TARGETDIR),$(LIBRARY_PATH)) $(LDFLAGS)


$(LIBRARY): $(OBJECTS)
	$(AR) rcs $(TARGETDIR)/$@ $^

$(TARGETDIR)/%.o : %.cpp 
	$(CXX) $(CXXFLAGS) $< -o $@
	


# ProjectRefsLog=$(for r in ${IncludeRefs}; do echo $r | tr '\\' '/' | sed -ne 's%.*"\(.*\)/.*\.vcxproj"%\1%gp' ; done  )
 
# ProjectRefs=$(for r in ${ProjectRefsLog}; do eval "echo $r"; done )
 

#.PHONY : depbuild
#depbuild: $(PROJFILE) 
#	sed -e 's/xmlns/ignore/'  $(PROJFILE) > $(PROJFILE).fixed
#	M=$(( xmllint --xpath '/Project/ItemGroup/ProjectReference/@Include'  $(PROJFILE).fixed )
#	@echo $(M)


######### Google Mock ################
.PHONY: mock
mock: $(HEADERS) $(MOCKS)

%_mock.h %_mock.hpp: %.h
	gmock_gen $< > $@ 

######### Debug ######################
.PHONY: files
files: 
	@echo "Filter "  $(IGNORE_FILES)
	@echo "Sources"  $(SOURCES)
	@echo "Objects"  $(OBJECTS)
	@echo "Headers"  $(HEADERS)
	@echo "Mocks  "  $(MOCKS)
	@echo "UIS    "  $(UIS)
	@echo "MOCS   "  $(MOCS)
	@echo "BINS   "  $(BINS)
	@echo "TARGET "  $(TARGETDIR)
	@echo "VPATH  "  $(VPATH)

.PHONY: test
test: 
	@echo "TARGETDIR = " $(TARGETDIR) 

######### BIN Sources ################

define BIN_CONVERT_H= 
	@echo "convert_h $< to $@"
	@echo "#ifndef __$(shell basename $@ .h | tr a-z A-Z )_H__" > $@      
	@echo "#define __$(shell basename $@ .h | tr a-z A-Z )_H__" >> $@     
	@echo >> $@                                                           
	@echo "extern size_t $(shell basename $@ .h)_size;">> $@ 
	@echo "extern unsigned char $(shell basename $@ .h)[];" >> $@             
	@echo >> $@                                                           
	@echo "#endif" >> $@                                                  
	@echo  >> $@                                   
endef

define BIN_CONVERT_C=
	@echo "convert_c $< to $@"
	@echo "#include \"StdAfx.h\""> $@      
	@echo "#include \"$(shell basename $@ .cpp).h\"" >> $@
	@echo >> $@                                                           
	@echo "size_t $(shell basename $@ .cpp)_size=$(shell stat -c '%s' $< );">> $@ 
	@echo "unsigned char $(shell basename $@ .cpp)[] = {" >> $@             
	@xxd -i < $< >> $@                                                    
	@echo "};" >> $@                                                      
	@echo >> $@                                                           
endef

%.h: %.hex
	$(BIN_CONVERT_H)

%.h: %.xsvf
	$(BIN_CONVERT_H)

%.cpp : %.hex
	$(BIN_CONVERT_C)

%.cpp : %.xsvf
	$(BIN_CONVERT_C)

######### QT #########################


ui_%.h: %.ui
	uic $< -o $@

moc_%.cpp: %.h
	moc $< -o $@ 

qrc_%.cpp: %.qrc
	rcc -name $(basename $< ) $< -o $@

ifneq ($(MAKECMDGOALS),clean)
-include $(DEPS)
endif
