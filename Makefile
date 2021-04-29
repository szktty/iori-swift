.PHONY: all clean doc

all:
	swift build -j 8 -c release
	cp .build/release/iori iori

clean:
	rm -rf .build iori iori.log ayame.log signaling.log webhook.log docs

doc:
	jazzy
