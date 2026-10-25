import CoreText
import Foundation

/// Registers the bundled .ttf files at launch, so we don't need UIAppFonts in Info.plist.
enum FontRegistrar {
    static func registerAll() {
        let urls = (Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [])
            + (Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") ?? [])
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
