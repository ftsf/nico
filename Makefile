NIM=/opt/nim/0.15.2/nim/bin/nim
APPNAME=ldbase

$(APPNAME)-debug: src/*.nim
	$(NIM) c -d:debug -o:$@ src/main.nim

$(APPNAME): src/*.nim
	$(NIM) c -d:release -o:$@ src/main.nim

clean:
	rm -vrf src/nimcache $(APPNAME) $(APPNAME)-debug || true

run: $(APPNAME)
	./$(APPNAME)

rund: $(APPNAME)-debug
	./$(APPNAME)-debug

android:
	${NIM} c --nimcache:android/jni/src/ --cpu:arm --noMain --os:linux --compileOnly -d:debug -d:android -p:. examples/platformer.nim
	make -C android

.PHONY: clean run rund android
