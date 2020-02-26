
BINDIR=bin

INCLUDES+=$(addprefix -I,$(SUBPROJECTS))

CXXFLAGS_BASE+= $(INCLUDES)
LIBRARY_PATH+= $(addprefix -L,$(SUBPROJECTS))
LDFLAGS_BASE+= $(patsubst ../%,-l%,$(SUBPROJECTS))

LDFLAGS=$(LDFLAGS_BASE) 
CXXFLAGS=$(CXXFLAGS_BASE)

SOURCES+=$(sort $(filter-out $(IGNORE_FILES),$(wildcard *.cpp)))
OBJECTS=$(addprefix $(TARGETDIR)/,$(subst .cpp,.o,$(SOURCES)))

BINS=$(filter-out $(IGNORE_FILES),$(foreach binext, $(BINEXT), $(wildcard *$(binext))))
GENSOURCES=$(foreach binext,$(BINEXT),$(patsubst %$(binext),generated_%.cpp,$(filter %$(binext),$(BINS))))
GENHEADERS=$(subst .cpp,.h,$(GENSOURCES))
SOURCES+= $(GENSOURCES)

QUIS=$(filter-out $(IGNORE_FILES),$(wildcard *.ui))
QUIS_HEADERS=$(patsubst %.ui,ui_%.h,$(QUIS))

QRCS=$(filter-out $(IGNORE_FILES),$(wildcard *.qrc))
QRCS_SOURCES=$(patsubst %.qrc,qrc_%.cpp,$(QRCS))

HEADERS=$(filter-out $(IGNORE_FILES),$(wildcard *.h))
QMOC_HEADERS=$(shell grep "Q_OBJECT" -l $(HEADERS) 2>/dev/null)
QMOC_SOURCES=$(patsubst %.h,moc_%.cpp,$(QMOC_HEADERS))

QT_SOURCES = $(QMOC_SOURCES) $(QRCS_SOURCES)

SOURCES+=$(QT_SOURCES)

DEPS=$(patsubst %.cpp,$(TARGETDIR)/%.d,$(SOURCES))

DEFAULT_CONF = release
DO_CONF = $(CONF_$(CONF))
CONF_ = $(CONF_$(DEFAULT_CONF))
CONF_release=release
CONF_debug=debug

ifeq ($(DO_CONF),release)
    CXXFLAGS+=$(CXXFLAGS_RELEASE)
    LDFLAGS+= $(LDFLAGS_RELEASE)
else 
    CXXFLAGS+=$(CXXFLAGS_DEBUG)
    LDFLAGS+= $(LDFLAGS_DEBUG)
endif

TARGETDIR=$(BINDIR)/$(DO_CONF)

all : build

release :
	$(MAKE) CONF=release
	
debug : 
	$(MAKE) CONF=debug

######### debug control
VERBOSITY ?= 0
V_AT = $(V_AT_$(V))
V_AT_ = $(V_AT_$(VERBOSITY))
V_AT_0 = @
V_AT_1 =

########## main rules

.PHONY : build link compile
build : link

compile: $(OBJECTS)

GENERATED_FILES += $(GENHEADERS) $(GENSOURCES) $(QMOC_SOURCES) $(QUIS_HEADERS)

$(OBJECTS): $(GENERATED_FILES)

link :: $(EXECUTABLE) $(DYNAMICLIB) $(STATICLIB)

$(EXECUTABLE): $(OBJECTS)
	@echo " =====> linking an executable $(EXECUTABLE)"
	$(V_AT)$(CXX) -o $@ $^ $(addsuffix /$(TARGETDIR),$(LIBRARY_PATH)) $(EXT_LIBRARY_PATH) $(LDFLAGS)

$(STATICLIB): $(OBJECTS)
	@echo " =====> linking a static library $(LIBRARY)"
	$(V_AT)$(AR) rcs $@ $(OBJECTS)

$(DYNAMICLIB): $(OBJECTS)
	@echo " =====> linking a dynamic library $(DYNAMIC)"
	$(V_AT)$(CXX) -shared -o $@ $(OBJECTS) $(addsuffix /$(TARGETDIR),$(LIBRARY_PATH)) $(LDFLAGS)

######### rule to create deps
ifeq (0,1)
$(TARGETDIR)/%.d : %.cpp
	@echo " =====> create dependency from $< in $@"
	$(V_AT)mkdir -p $(TARGETDIR)
	$(V_AT)$(CXX) -MM $(CXXFLAGS) $< >$@
endif

######### rule to create objects
$(TARGETDIR)/%.o : %.cpp
	@echo " =====> compile $< to $@"
	$(V_AT)mkdir -p $(TARGETDIR)
	$(V_AT)$(CXX) $(CXXFLAGS) $< -o $@ -c


######### help rules 
.PHONY: clean
clean::
	@echo " =====> clean"
	$(V_AT)$(RM) -r $(BINDIR)

.PHONY : show
show-all:
	@echo " =====> show-all"
	$(foreach var,$(.VARIABLES),$(info $(var) = $($(var))))

SHOWVARS+=OBJECTS SOURCES BINS GENSOURCES GENHEADERS QUIS_HEADERS QMOC_HEADERS QMOC_SOURCES 

.PHONY: show
show:
	$(foreach var,$(SHOWVARS),$(info $(var) = $($(var))))

######### binaries 

clean::
	$(V_AT)$(RM) $(GENSOURCES) $(GENHEADERS)

######### binary convertion ################

define BIN_CONVERT_h= 
@echo " =====> convert $$< to $$@"
	@echo "#ifndef __$$(patsubst %.h,%,$$@)_H__" > $$@      
	@echo "#define __$$(patsubst %.h,%,$$@)_H__" >> $$@     
	@echo >> $$@                                                           
	@echo "extern size_t $$(patsubst generated_%.h,%,$$@)_size;">> $$@ 
	@echo "extern unsigned char $$(patsubst generated_%.h,%,$$@)[];" >> $$@             
	@echo >> $$@                                                           
	@echo "#endif" >> $$@                                                  
	@echo  >> $$@                                   
endef

define BIN_CONVERT_cpp=
@echo " =====> convert $$< to $$@"
	@echo "#include \"StdAfx.h\""> $$@      
	@echo "#include \"$$(patsubst  %.cpp,%.h,$$@)\"" >> $$@
	@echo >> $$@                                                           
	@echo "size_t $$(patsubst generated_%.cpp,%,$$@)_size=$$(shell stat -L -c '%s' $$< );">> $$@ 
	@echo "unsigned char $$(patsubst generated_%.cpp,%,$$@)[] = {" >> $$@             
	@xxd -i < $$< >> $$@                                                    
	@echo "};" >> $$@                                                      
	@echo >> $$@                                                           
endef

define bin-to-cpp
generated_%.$2 : %$1
	$(V_AT)$(BIN_CONVERT_$2)

endef

define bin-to-src
$(call bin-to-cpp,$1,h)
$(call bin-to-cpp,$1,cpp)
endef

# generate rules to convert bin files to sources for every binary extension
$(foreach binext,$(BINEXT),$(eval $(call bin-to-src,$(binext))))

# generate dependency for generated cpp to generated h. otherwise the .h don't be generated
$(foreach f,$(GENSOURCES),$(eval $(f):$(patsubst %.cpp,%.h,$(f))))

#  ============ QT section end ==========

clean ::
	$(V_AT)$(RM) $(QT_SOURCES)

# convertion rules 
ui_%.h: %.ui
	@echo " =====> convert $< to $@"
	$(V_AT)$(QTDIR)/bin/uic $< -o $@

moc_%.cpp: %.h
	@echo " =====> convert $< to $@"
	$(V_AT)$(QTDIR)/bin/moc $< -o $@

qrc_%.cpp: %.qrc
	@echo " =====> convert $< to $@"
	$(V_AT)$(QTDIR)/bin/rcc -name $(basename $< ) $< -o $@

$(QT_SOURCES) :
######### footer ################ 

# -include $(DEPS)
