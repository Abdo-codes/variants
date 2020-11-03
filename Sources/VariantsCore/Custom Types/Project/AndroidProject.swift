//
//  Variants
//
//  Copyright (c) Backbase B.V. - https://www.backbase.com
//  Created by Balazs Toth
//

import Foundation
import PathKit
import ArgumentParser
import Stencil

class AndroidProject: Project {
    init(
        specHelper: SpecHelper,
        gradleFactory: GradleScriptFactory = GradleScriptFactory(),
        fastlaneFactory: FastlaneParametersFactory = FastlaneParametersFactory(),
        yamlParser: YamlParser = YamlParser()
    ) {
        self.gradleFactory = gradleFactory
        self.fastlaneFactory = fastlaneFactory
        super.init(specHelper: specHelper, yamlParser: yamlParser)
    }
    
    // MARK: - Public

    override func setup(spec: String, skipFastlane: Bool, verbose: Bool) throws {
        guard let configuration = try loadConfiguration(spec) else {
            throw RuntimeError("Unable to load spec '\(spec)'")
        }

        createVariants(with: configuration, spec: spec)
        setupFastlane(with: configuration, skip: skipFastlane)
    }

    override func `switch`(to variant: String, spec: String, verbose: Bool) throws {
        guard let configuration = try loadConfiguration(spec) else {
            throw RuntimeError("Unable to load specs '\(spec)' for platform 'android'")
        }

        guard let desiredVariant = configuration.variants.first(where: { $0.name.lowercased() == variant.lowercased() }) else {
            throw ValidationError("Variant \(variant) not found.")
        }

        do {
            try switchTo(desiredVariant, spec: spec, configuration: configuration)
        } catch let error as TemplateDoesNotExist {
            throw error
            
        } catch {
            throw RuntimeError("Unable to switch variants - Check your YAML spec")
        }
    }

    // MARK: - Private

    private func loadConfiguration(_ path: String?) throws -> AndroidConfiguration? {
        guard let path = path else {
            throw ValidationError("Error: Use '-s' to specify the configuration file")
        }

        let configurationPath = Path(path)
        guard !configurationPath.isDirectory else {
            throw ValidationError("Error: \(configurationPath) is a directory path")
        }

        do {
            return try yamlParser.extractConfiguration(from: path, platform: .android).android
        } catch {
            Logger.shared.logError(item: (error as NSError).debugDescription)
            throw RuntimeError("Unable to load your YAML spec")
        }
    }

    private func process(variant: String, spec: String, configuration: Configuration) throws {

    }

    private func switchTo(_ variant: AndroidVariant, spec: String, configuration: AndroidConfiguration) throws {
        Logger.shared.logInfo(item: "Found: \(variant.configIdSuffix)")
        // Create script 'variants.gradle'
        gradleFactory.createScript(with: configuration, variant: variant)
        
        // Create 'variants_params.rb' with parameters whose destination are set as '.fastlane'
        try storeFastlaneParams(with: configuration, variant: variant)
    }

    private func createVariants(with configuration: AndroidConfiguration, spec: String) {

    }

    // swiftlint:disable function_body_length
    private func setupFastlane(with configuration: AndroidConfiguration, skip: Bool) {
        if skip {
            Logger.shared.logInfo("Skipped Fastlane setup", item: "")
        } else {
            Logger.shared.logInfo("Setting up Fastlane", item: "")

            do {
                let path = try TemplateDirectory().path
                try Bash("cp", arguments: "-R", "\(path.absolute())/android/_fastlane/", ".")
                    .run()

                let projectSourceFolder = configuration.path
                let baseSetupCompletedMessage =
                    """
                    ✅  You variants configuration was setup
                    ✅  For configuration properties with 'environment' destination, a temporary
                        file has been created. You can source this file directly.
                    ✅  For configuration properties with 'project' destination, they have been
                        stored in '\(projectSourceFolder)/gradleScripts/variants.gradle'.
                        This gradle file should be used by your 'app/build.gradle' in order to read the app's
                        information and custom properties you've set with destination 'project'.
                    🔄  Use 'variants switch --variants <value>' to switch between variants and
                        update the properties in the files described above.

                    That is all.
                    """
                
                var setupCompleteMessage =
                    """

                    We got almost everything done!

                    ❌  Fastlane could not be setup. The template wasn't found or something else went wrong when
                        copying it.

                    """
                
                if Path("./fastlane/").isDirectory {
                    setupCompleteMessage =
                        """

                        Your setup is complete, congratulations! 🎉
                        However, you still need to provide some parameters in order for fastlane to run correctly.

                        ⚠️  Check the files in 'fastlane/parameters/', change the parameters accordingly,
                            provide environment variables when applicable.
                        ⚠️  Note that the values in the file 'fastlane/parameters/variants_params.rb' are
                            generated automatically.

                        """
                    
                    Logger.shared.logInfo("🚀 ", item: "Fastlane setup with success", color: .green)
                    Logger.shared.logInfo("👇  Next steps ", item: "", color: .yellow)
                } else {
                    Logger.shared.logWarning("", item: "Fastlane setup couldn't be completed")
                    Logger.shared.logInfo("👇  What happened ", item: "", color: .yellow)
                }
                
                setupCompleteMessage += baseSetupCompletedMessage
                setupCompleteMessage.enumerateLines { (line, _) in
                    Logger.shared.logInfo("", item: line, color: .yellow)
                }

            } catch {
                Logger.shared.logFatal(item: error.localizedDescription)
            }
        }
    }
    // swiftlint:enable function_body_length
    
    private func storeFastlaneParams(with configuration: AndroidConfiguration, variant: AndroidVariant) throws {
        var fastlaneParams: [CustomProperty] = (variant.custom ?? []) + (configuration.custom ?? [])
        fastlaneParams = fastlaneParams.filter { $0.destination == .fastlane }
        guard !fastlaneParams.isEmpty else { return }
        
        let fastlaneParamPath = try Path(configuration.path).safeJoin(path: StaticPath.Fastlane.parametersFolder)
        try fastlaneFactory.createParametersFile(in: fastlaneParamPath, with: fastlaneParams)
    }
    
    private let gradleFactory: GradleScriptFactory
    private let fastlaneFactory: FastlaneParametersFactory
}
