SWIFTC ?= swiftc
APP_NAME := krest
APP_DIR  := build/Krest.app
APP_EXEC := $(APP_DIR)/Contents/MacOS/Krest
SRC      := $(wildcard swift/*.swift)
VERSION  := $(shell /usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist)
ARCH     := $(shell uname -m)
DEPLOYMENT_TARGET ?= 13.0
LABEL    := org.aimindset.krest.bar
AGENT    := $(HOME)/Library/LaunchAgents/$(LABEL).plist
DOMAIN   := gui/$(shell id -u)
INSTALLED := $(HOME)/Applications/$(APP_NAME).app

.PHONY: bundle install uninstall test dist clean run

bundle:
	@mkdir -p $(APP_DIR)/Contents/MacOS $(APP_DIR)/Contents/Resources
	$(SWIFTC) -O -target $(ARCH)-apple-macosx$(DEPLOYMENT_TARGET) -o $(APP_EXEC) $(SRC) -framework AppKit \
	  -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker Info.plist
	@cp Info.plist $(APP_DIR)/Contents/Info.plist
	@cp assets/демо.json assets/*.ttf assets/*LICENSE.txt assets/design-receipt.json $(APP_DIR)/Contents/Resources/
	@cp LICENSE $(APP_DIR)/Contents/Resources/Krest-LICENSE.txt
	@[ -f assets/Krest.icns ] && cp assets/Krest.icns $(APP_DIR)/Contents/Resources/ || true
	@codesign --force --deep --sign - $(APP_DIR)
	@codesign --verify --deep --strict $(APP_DIR)
	@echo "собрано: $(APP_DIR)"

install: bundle
	@bash install.sh

uninstall:
	@launchctl bootout $(DOMAIN)/$(LABEL) 2>/dev/null || true
	@rm -f $(AGENT)
	@rm -rf "$(INSTALLED)"
	@echo "снято"

test: bundle
	@bash tests/проверка.sh
	@bash tests/contract.sh
	@bash tests/check-in-sync.sh
	@bash tests/check-in-http.sh
	@bash tests/theme-regression.sh

dist: bundle
	@mkdir -p dist
	@COPYFILE_DISABLE=1 ditto -c -k --norsrc --keepParent $(APP_DIR) dist/Krest-$(VERSION)-$(ARCH).zip
	@shasum -a 256 dist/Krest-$(VERSION)-$(ARCH).zip

clean:
	@rm -rf build dist
