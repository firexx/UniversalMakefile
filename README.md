# UniversalMakefile


$ git clone https://github.com/firexx/UniversalMakefile.git

$ cd UniversalMakefile

$ make -C ExeProject/ -f Makefile.linux CONF=debug build

$ LD_LIBRARY_PATH=DllProject/bin/debug ExeProject/bin/debug/ExeProject
