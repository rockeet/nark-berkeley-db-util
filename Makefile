DBG_FLAGS ?= -g3 -D_DEBUG
RLS_FLAGS ?= -O3 -DNDEBUG

ifeq "$(origin LD)" "default"
  LD := ${CXX}
endif

COMPILER := $(shell ${CXX} --version | head -1 | awk '{split($$3, Ver, "."); printf("%s-%d.%d", $$1, Ver[1], Ver[2]);}')
#$(error COMPILER=${COMPILER})
UNAME_MachineSystem := $(shell uname -m -s | sed 's:[ /]:-:g')
BUILD_ROOT := build/${COMPILER}-${UNAME_MachineSystem}
ddir:=${BUILD_ROOT}/dbg
rdir:=${BUILD_ROOT}/rls

gen_sh := $(dir $(lastword ${MAKEFILE_LIST}))gen_env_conf.sh

err := $(shell env BDB_HOME=${BDB_HOME} BOOST_INC=${BOOST_INC} bash ${gen_sh} "${CXX}" ${COMPILER} ${BUILD_ROOT}/env.mk; echo $$?)
ifneq "${err}" "0"
   $(error err = ${err} MAKEFILE_LIST = ${MAKEFILE_LIST}, PWD = ${PWD}, gen_sh = ${gen_sh} "${CXX}" ${COMPILER} ${BUILD_ROOT}/env.mk)
endif

BRAIN_DEAD_RE2_INC = -I3rdparty/re2/re2 -I3rdparty/re2/util

NARK_INC := -Isrc -I../nark-serialization/src -I../nark-bone/src

include ${BUILD_ROOT}/env.mk

UNAME_System := $(shell uname | sed 's/^\([0-9a-zA-Z]*\).*/\1/')
ifeq (CYGWIN, ${UNAME_System})
  FPIC =
  # lazy expansion
  CYGWIN_LDFLAGS = -Wl,--out-implib=$@ \
				   -Wl,--export-all-symbols \
				   -Wl,--enable-auto-import
  DLL_SUFFIX = .dll.a
  CYG_DLL_FILE = $(shell echo $@ | sed 's:\(.*\)/lib\([^/]*\)\.a$$:\1/cyg\2:')
else
  FPIC = -fPIC
  DLL_SUFFIX = .so
  CYG_DLL_FILE = $@
endif
override CFLAGS += ${FPIC}
override CXXFLAGS += ${FPIC}
override LDFLAGS += ${FPIC}

ifeq "$(shell expr substr ${COMPILER} 1 3)" "g++"
  override LDFLAGS += -rdynamic
  override CXXFLAGS += -time
  ifeq "$(shell echo ${COMPILER} | awk -F- '{if ($$2 >= 4.8) print 1;}')" "1"
    CXX_STD := -std=gnu++1y
  endif
endif

ifeq "${CXX_STD}" ""
  CXX_STD := -std=gnu++11
endif

# icc or icpc
ifeq "$(shell expr substr ${COMPILER} 1 2)" "ic"
  override CXXFLAGS += -xHost -fasm-blocks
  CPU = -xHost
else
  CPU = -march=native
  COMMON_C_FLAGS  += -Wno-deprecated-declarations
  COMMON_C_FLAGS  += -fstrict-aliasing
  COMMON_C_FLAGS  += -Wstrict-aliasing=3
endif

COMMON_C_FLAGS  = -Wformat=2 -Wcomment
COMMON_C_FLAGS  += -Wall -Wextra
COMMON_C_FLAGS  += -Wno-unused-parameter
COMMON_C_FLAGS  += -D_GNU_SOURCE

#-v #-Wall -Wparentheses
#COMMON_C_FLAGS  += ${COMMON_C_FLAGS} -Wpacked -Wpadded -v
#COMMON_C_FLAGS	 += ${COMMON_C_FLAGS} -Winvalid-pch
#COMMON_C_FLAGS  += ${COMMON_C_FLAGS} -fmem-report

ifeq "$(shell expr substr ${COMPILER} 1 5)" "clang"
  COMMON_C_FLAGS += -fcolor-diagnostics
endif

override CFLAGS += ${COMMON_C_FLAGS}
override CXXFLAGS += ${COMMON_C_FLAGS}

DEFS := -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE
override CFLAGS   += ${DEFS}
override CXXFLAGS += ${DEFS}

override INCS := ${NARK_INC} ${INCS}

ifeq (, $(findstring ${BOOST_INC}, ${INCS} /usr/include /usr/local/include))
  override INCS += -I${BOOST_INC}
endif

ifeq (, $(findstring ${BOOST_LIB}, /usr/lib64 /usr/lib /usr/local/lib))
  override LIBS += -L${BOOST_LIB}
endif

extf = -pie -fno-stack-protector
override CFLAGS += ${extf}
override CXXFLAGS += ${extf}

override INCS += -I${BDB_HOME}/include
LIBS += -L${BDB_HOME}/lib -ldb_cxx-${BDB_VER} -ldb-${BDB_VER}
LIBS += -L../nark-serialization/lib 
LIBS += -L../nark-bone/lib 

ifeq (, ${prefix})
	ifeq (root, ${USER})
		prefix := /usr
	else
		prefix := /home/${USER}
	endif
endif

#$(warning prefix=${prefix} BDB_HOME=${BDB_HOME}: LIBS=${LIBS})

bdb_util_c   := $(wildcard src/nark/bdb_util/*.c)
bdb_util_cpp := $(wildcard src/nark/bdb_util/*.cpp)
bdb_util_src := ${bdb_util_c} ${bdb_util_cpp}

#function definition
#@param:${1} -- targets var prefix, such as bdb_util | serialization
#@param:${2} -- build type: d | r
objs = $(addprefix ${${2}dir}/, $(addsuffix .o, $(basename ${${1}_src})))

bdb_util_d_o := $(call objs,bdb_util,d)
bdb_util_r_o := $(call objs,bdb_util,r)
bdb_util_d := lib/libnark-bdb_util-${COMPILER}-d${DLL_SUFFIX}
bdb_util_r := lib/libnark-bdb_util-${COMPILER}-r${DLL_SUFFIX}
static_bdb_util_d := lib/libnark-bdb_util-${COMPILER}-d.a
static_bdb_util_r := lib/libnark-bdb_util-${COMPILER}-r.a

all : ${bdb_util_d} ${static_bdb_util_d} \
	  ${bdb_util_r} ${static_bdb_util_r}

allsrc = ${bdb_util_src}
alldep = $(addprefix ${rdir}/, $(addsuffix .dep, $(basename ${allsrc}))) \
         $(addprefix ${ddir}/, $(addsuffix .dep, $(basename ${allsrc})))

.PHONY : dbg rls
dbg: ${bdb_util_d} ${static_bdb_util_d}
rls: ${bdb_util_r} ${static_bdb_util_r}

${bdb_util_d} : LIBS += -lnark-serialization-${COMPILER}-d -lnark-bone-${COMPILER}-d
${bdb_util_r} : LIBS += -lnark-serialization-${COMPILER}-r -lnark-bone-${COMPILER}-r

${bdb_util_d} : $(call objs,bdb_util,d)
${bdb_util_r} : $(call objs,bdb_util,r)
${static_bdb_util_d} : $(call objs,bdb_util,d)
${static_bdb_util_r} : $(call objs,bdb_util,r)

%${DLL_SUFFIX}:
	@echo "----------------------------------------------------------------------------------"
	@echo "Creating dynamic library: $@"
	@echo BOOST_INC=${BOOST_INC} BOOST_SUFFIX=${BOOST_SUFFIX}
	@echo -e "OBJS:" $(addprefix "\n  ",$(sort $(filter %.o,$^)))
	@echo -e "LIBS:" $(addprefix "\n  ",${LIBS})
	@mkdir -p lib
	@ln -sfT $(notdir $@) $(subst -${COMPILER},, $@)
	@${LD} -shared $(sort $(filter %.o,$^)) ${LDFLAGS} ${LIBS} -o ${CYG_DLL_FILE} ${CYGWIN_LDFLAGS}
ifeq (CYGWIN, ${UNAME_System})
	@cp -l -f ${CYG_DLL_FILE} /usr/bin
endif

%.a:
	@echo "----------------------------------------------------------------------------------"
	@echo "Creating static library: $@"
	@echo BOOST_INC=${BOOST_INC} BOOST_SUFFIX=${BOOST_SUFFIX}
	@echo -e "OBJS:" $(addprefix "\n  ",$(sort $(filter %.o,$^)))
	@echo -e "LIBS:" $(addprefix "\n  ",${LIBS})
	@mkdir -p lib
	@ln -sfT $(notdir $@) $(subst -${COMPILER},, $@)
	@${AR} rcs $@ $(filter %.o,$^)

.PHONY : install
install : bdb_util
	cp -P lib/* ${prefix}/lib/
	mkdir -p ${prefix}/include/nark/bdb_util
	cp src/nark/bdb_util/*.{h,hpp} ${prefix}/include/nark/bdb_util

.PHONY : clean
clean:
	-rm -rf lib/libnark* ${BUILD_ROOT} ${PRECOMPILED_HEADER_GCH}

.PHONY : depends
depends : ${alldep}

-include ${alldep}

${ddir}/%.o: %.cpp
	@echo file: $< "->" $@
	@echo NARK_INC=${NARK_INC}
	@echo BOOST_INC=${BOOST_INC} BOOST_SUFFIX=${BOOST_SUFFIX}
	mkdir -p $(dir $@)
	${CXX} ${CXX_STD} ${CPU} -c ${DBG_FLAGS} ${CXXFLAGS} ${INCS} $< -o $@

${rdir}/%.o: %.cpp
	@echo file: $< "->" $@
	@echo NARK_INC=${NARK_INC}
	@echo BOOST_INC=${BOOST_INC} BOOST_SUFFIX=${BOOST_SUFFIX}
	mkdir -p $(dir $@)
	${CXX} ${CXX_STD} ${CPU} -c ${RLS_FLAGS} ${CXXFLAGS} ${INCS} $< -o $@

${ddir}/%.o: %.cc
	@echo file: $< "->" $@
	@echo NARK_INC=${NARK_INC}
	@echo BOOST_INC=${BOOST_INC} BOOST_SUFFIX=${BOOST_SUFFIX}
	mkdir -p $(dir $@)
	${CXX} ${CXX_STD} ${CPU} -c ${DBG_FLAGS} ${CXXFLAGS} ${INCS} $< -o $@

${rdir}/%.o: %.cc
	@echo file: $< "->" $@
	@echo NARK_INC=${NARK_INC}
	@echo BOOST_INC=${BOOST_INC} BOOST_SUFFIX=${BOOST_SUFFIX}
	mkdir -p $(dir $@)
	${CXX} ${CXX_STD} ${CPU} -c ${RLS_FLAGS} ${CXXFLAGS} ${INCS} $< -o $@

${ddir}/%.o : %.c
	@echo file: $< "->" $@
	mkdir -p $(dir $@)
	${CC} -c ${CPU} ${DBG_FLAGS} ${CFLAGS} ${INCS} $< -o $@

${rdir}/%.o : %.c
	@echo file: $< "->" $@
	mkdir -p $(dir $@)
	${CC} -c ${CPU} ${RLS_FLAGS} ${CFLAGS} ${INCS} $< -o $@

${ddir}/%.s : %.cpp ${PRECOMPILED_HEADER_GCH}
	@echo file: $< "->" $@
	${CXX} -S ${CPU} ${DBG_FLAGS} ${CXXFLAGS} ${INCS} $< -o $@

${rdir}/%.s : %.cpp ${PRECOMPILED_HEADER_GCH}
	@echo file: $< "->" $@
	${CXX} -S ${CPU} ${RLS_FLAGS} ${CXXFLAGS} ${INCS} $< -o $@

${ddir}/%.s : %.c ${PRECOMPILED_HEADER_GCH}
	@echo file: $< "->" $@
	${CC} -S ${CPU} ${DBG_FLAGS} ${CXXFLAGS} ${INCS} $< -o $@

${rdir}/%.s : %.c ${PRECOMPILED_HEADER_GCH}
	@echo file: $< "->" $@
	${CC} -S ${CPU} ${RLS_FLAGS} ${CXXFLAGS} ${INCS} $< -o $@

${rdir}/%.dep : %.c
	@echo file: $< "->" $@
	@echo INCS = ${INCS}
	mkdir -p $(dir $@)
	${CC} -M -MT $(basename $@).o ${INCS} $< > $@

${ddir}/%.dep : %.c
	@echo file: $< "->" $@
	@echo INCS = ${INCS}
	mkdir -p $(dir $@)
	${CC} -M -MT $(basename $@).o ${INCS} $< > $@

${rdir}/%.dep : %.cpp
	@echo file: $< "->" $@
	@echo INCS = ${INCS}
	mkdir -p $(dir $@)
	${CXX} -M -MT $(basename $@).o ${INCS} $< > $@

${ddir}/%.dep : %.cpp
	@echo file: $< "->" $@
	@echo INCS = ${INCS}
	mkdir -p $(dir $@)
	${CXX} -M -MT $(basename $@).o ${INCS} $< > $@

