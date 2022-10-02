CXX = g++
CA65 = ca65
LD65 = ld65
AR65 = ar65

CFLAGS65 = -Os

OBJDIR = .obj

APPS = \
	$(OBJDIR)/dump.com \
	$(OBJDIR)/bitmap.com \
	$(OBJDIR)/submit.com \
	$(OBJDIR)/stat.com \
	$(OBJDIR)/rand.com \
	os3bdos.asm \
	cpmfs/test.sub \
	cpmfs/readme.txt

LIBXFCB_OBJS = \
	$(OBJDIR)/lib/xfcb/clear.o \
	$(OBJDIR)/lib/xfcb/close.o \
	$(OBJDIR)/lib/xfcb/erase.o \
	$(OBJDIR)/lib/xfcb/get.o \
	$(OBJDIR)/lib/xfcb/make.o \
	$(OBJDIR)/lib/xfcb/open.o \
	$(OBJDIR)/lib/xfcb/prepare.o \
	$(OBJDIR)/lib/xfcb/readrand.o \
	$(OBJDIR)/lib/xfcb/readseq.o \
	$(OBJDIR)/lib/xfcb/set.o \
	$(OBJDIR)/lib/xfcb/vars.o \
	$(OBJDIR)/lib/xfcb/writerand.o \
	$(OBJDIR)/lib/xfcb/writeseq.o \

all: $(OBJDIR)/multilink bbcmicro.img c64.d64 bdos.img bbcmicro.ssd $(OBJDIR)/libxfcb.a

$(OBJDIR)/multilink: tools/multilink.cc
	@mkdir -p $(dir $@)
	$(CXX) -Os -g -o $@ $< -lfmt

$(OBJDIR)/mkdfs: tools/mkdfs.c
	@mkdir -p $(dir $@)
	$(CXX) -Os -g -o $@ $<

$(OBJDIR)/%.o: %.s include/zif.inc include/mos.inc include/cpm65.inc
	@mkdir -p $(dir $@)
	$(CA65) -o $@ $< -I include -I lib/xfcb --listing $(patsubst %.o,%.lst,$@)

$(OBJDIR)/libxfcb.a: $(LIBXFCB_OBJS)
	@mkdir -p $(dir $@)
	$(AR65) r $@ $^

$(OBJDIR)/bbcmicro.exe: $(OBJDIR)/src/bbcmicro.o scripts/bbcmicro.cfg
	$(LD65) -m $(patsubst %.img,%.map,$@) -vm -C scripts/bbcmicro.cfg -o $@ $<
	
$(OBJDIR)/c64.exe: $(OBJDIR)/src/c64.o scripts/c64.cfg
	$(LD65) -m $(patsubst %.img,%.map,$@) -vm -C scripts/c64.cfg -o $@ $<
	
$(OBJDIR)/apps/%.elf: apps/%.c lib/printi.S
	mos-cpm65-clang $(CFLAGS65) -I. -o $@ $^

$(OBJDIR)/%.com: $(OBJDIR)/apps/%.elf
	elftocpm65 -o $@ $<

$(OBJDIR)/%.com: $(OBJDIR)/apps/%.o $(OBJDIR)/multilink $(OBJDIR)/libxfcb.a
	$(OBJDIR)/multilink -o $@ $< $(OBJDIR)/libxfcb.a

$(OBJDIR)/bdos.img: $(OBJDIR)/src/bdos.o $(OBJDIR)/multilink
	$(OBJDIR)/multilink -o $@ $<

$(OBJDIR)/ccp.sys: $(OBJDIR)/src/ccp.o $(OBJDIR)/multilink $(OBJDIR)/libxfcb.a
	$(OBJDIR)/multilink -o $@ $< $(OBJDIR)/libxfcb.a

$(OBJDIR)/bbcmicrofs.img: $(APPS) $(OBJDIR)/ccp.sys
	mkfs.cpm -f bbc192 $@
	cpmcp -f bbc192 $@ $(OBJDIR)/ccp.sys $(APPS) 0:
	cpmchattr -f bbc192 $@ s 0:ccp.sys

bbcmicro.ssd: $(OBJDIR)/bbcmicro.exe $(OBJDIR)/bdos.img Makefile $(OBJDIR)/bbcmicrofs.img $(OBJDIR)/mkdfs
	$(OBJDIR)/mkdfs -O $@ \
		-N CP/M-65 \
		-f bbc/\!boot -l 0x400 -e 0x400 -B 2 \
		-f $(OBJDIR)/bdos.img -n bdos \
		-f $(OBJDIR)/bbcmicrofs.img -n cpmfs

c64.d64: $(OBJDIR)/c64.exe $(OBJDIR)/bdos.img Makefile $(APPS) $(OBJDIR)/ccp.sys
	@rm -f $@
	cc1541 -q -n "cp/m-65" $@
	mkfs.cpm -f c1541 $@
	cc1541 -q \
		-t -u 0 \
		-r 18 -f cpm -w c64.img \
		-r 18 -s 1 -f bdos -w $(OBJDIR)/bdos.img \
		$@
	cpmcp -f c1541 $@ /dev/null 0:cbm.sys
	echo "00f: 30 59 5a 5b 5c 5d 5e" | xxd -r - $@
	echo "16504: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00" | xxd -r - $@
	echo "16514: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00" | xxd -r - $@
	echo "16524: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00" | xxd -r - $@
	echo "16534: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00" | xxd -r - $@
	echo "16544: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00" | xxd -r - $@
	echo "16554: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00" | xxd -r - $@
	echo "16564: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00" | xxd -r - $@
	echo "16574: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00" | xxd -r - $@
	echo "16584: 00 00 00 00 00 00 00 00 00 00 00 00" | xxd -r - $@
	cpmcp -f c1541 $@ $(OBJDIR)/ccp.sys $(APPS) 0:
	cpmchattr -f c1541 $@ s 0:ccp.sys 0:cbm.sys

clean:
	rm -rf $(OBJDIR) c64.d64 bbcmicro.ssd

.DELETE_ON_ERROR:
.SECONDARY:

