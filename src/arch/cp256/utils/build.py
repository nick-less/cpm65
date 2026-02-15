from build.llvm import llvmprogram

llvmprogram(
    name="keyscan", 
    srcs=["./keyscan.c"], 
    deps=["lib+cpm65"])


llvmprogram(
    name="i2c_scan", 
    srcs=[
        "./i2c_wrapper.h",
        "./i2c_wrapper.S",
        "./i2c_helper.c",
        "./i2c_scan.c"], 
    deps=["include", "lib+cpm65"])


llvmprogram(
    name="mbrot-col", 
    srcs=["./ext_screen.h","./ext_screen.S","./mbrot-col.c"], 
    deps=["include", "lib+cpm65"])

llvmprogram(
    name="ds3231_temp", 
    srcs=[
          "./timer.h",
          "./timer_wrapper.S",
          "./i2c_wrapper.h",
          "./i2c_wrapper.S",
          "./i2c_helper.c",
          "./ds3231_temp.c"], 
    deps=["include", "lib+cpm65"])

llvmprogram(
    name="meminfo", 
    srcs=["./meminfo.c"], 
    deps=["include", "lib+cpm65"])


#llvmprogram(
#    name="tty80drv",
#    srcs=["./tty80drv.S"],
#    deps=[
#        "include",
#        "src/arch/atari800+headers",
#        "third_party/fonts/atari+ivo3x6",
#    ],
#)
