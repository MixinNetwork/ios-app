# MixinServices

## Integration

MixinServices is a local Swift package referenced by Mixin Messenger.
Open that project with Xcode 26.6 or later.

`Package.swift` declares the shared Swift services, the `CMixinServices` C and
Objective-C support target, and the bundled TIP and XKCP binary targets. The
Swift module re-exports the support target to preserve its public API.

The application project owns the package resolution lockfile.

## Author

wuyueyang, wuyueyang@mixin.one

## License

MixinServices is available under the GNU GPL v3 license. See the LICENSE file for more info.
