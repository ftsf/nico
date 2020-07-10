APPNAME = exampleApp
NIMC=nim c
NIMJS=nim js
SOURCES = $(shell ls src/*.nim)
BUILDARGS = 
RELEASE_ARGS = -d:release
DEBUG_ARGS = -d:debug

release: $(SOURCES)
	${NIMC} $(RELEASE_ARGS) $(BUILDARGS) -o:${APPNAME} src/main.nim

debug: $(SOURCES)
	${NIMC} $(DEBUG_ARGS) $(BUILDARGS) -o:${APPNAME}_debug src/main.nim

run: release
	./${APPNAME}

rund: debug
	./${APPNAME}_debug

web: $(SOURCES)
	${NIMJS} $(RELEASE_ARGS) $(BUILDARGS) -o:$(APPNAME).js src/main.nim

webd: $(SOURCES)
	${NIMJS} $(DEBUG_ARGS) $(BUILDARGS) -o:$(APPNAME).js src/main.nim

.PHONY: release debug run rund web webd
