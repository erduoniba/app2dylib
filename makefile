
.PHONY:app2dylib

TMP_FILE := libMachObjC.a app2dylib.dSYM/ build/

restore-symbol: 
	rm -f app2dylib
	xcodebuild -project "app2dylib.xcodeproj" -target "app2dylib" -configuration "Release" -arch arm64 CONFIGURATION_BUILD_DIR="$(shell pwd)" HEADER_SEARCH_PATHS="/opt/homebrew/include" LIBRARY_SEARCH_PATHS="/opt/homebrew/lib" OTHER_LDFLAGS="-lcrypto -lssl" -jobs 4 build
	rm -rf $(TMP_FILE)
	

clean:
	rm -rf app2dylib $(TMP_FILE)

