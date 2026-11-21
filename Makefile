.PHONY: generate build test run clean

SCHEME = My-Usage
DERIVED = build

generate:
	xcodegen generate

build: generate
	xcodebuild -scheme $(SCHEME) -configuration Release -derivedDataPath $(DERIVED) build

test: generate
	xcodebuild test -scheme $(SCHEME) -destination 'platform=macOS' -derivedDataPath $(DERIVED)

run: build
	open $(DERIVED)/Build/Products/Release/My-Usage.app

clean:
	rm -rf $(DERIVED) My-Usage.xcodeproj
