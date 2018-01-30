module FileExtractor

  require 'xcodeproj'
  require 'file-extractor/files_json_struct'

  class XcodeprojExtractor

    def initialize(root_path, project_path)
      @root_path = root_path
      @project = Xcodeproj::Project.open(project_path)
      @all_targets = @project.targets.to_a.select do |target| 
        target.instance_of? Xcodeproj::Project::Object::PBXNativeTarget
      end
      @main_target = @all_targets.first
      @main_build_settings = build_settings(@main_target)
    end

    def extract_data
      FileExtractor::FilesJson.new(
        FileExtractor::Project.new(@root_path),
        FileExtractor::Module.new(module_name, triple),
        FileExtractor::Sdk.new(sdk, nil),
        filenames,
        explicitelyLinkedFrameworks,
        nil
      )
    end

    private

    def module_name
      @main_target.name
    end

    def sdk
      # for now, the module name is the target name. ofc that's a non-generalizable assumption
      @main_target.sdk
    end

    def filenames 
      @all_targets.flat_map do |target|
        target.source_build_phase.files.to_a
      end.map do |pbx_build_file|
        pbx_build_file.file_ref.real_path.to_s
      end.select do |path|
        path.end_with?(".swift")
      end.select do |path|
        File.exists?(path)
      end.map do |path|
        File.expand_path(path)
      end
    end

    def explicitelyLinkedFrameworks 
      @main_target.frameworks_build_phase.files.map do |framework|
        name = framework.file_ref.name
        path = framework.file_ref.real_path.to_s
        FileExtractor::ExplicitelyLinkedFramework.new(name.sub(".framework", ""), path.sub(name, ""))
      end
    end

    def triple
      architecture = @main_build_settings["CURRENT_ARCH"]
      sdk = case @main_build_settings["PLATFORM_NAME"]
        when "iphoneos"
          @main_build_settings["SDK_NAME"].gsub("iphoneos", "ios")
        when "iphonesimulator"
          @main_build_settings["SDK_NAME"].gsub("iphonesimulator", "ios")
        when "appletvos"
          @main_build_settings["SDK_NAME"].gsub("apple", "")
        when "appletvsimulator"
          @main_build_settings["SDK_NAME"].gsub("appletvsimulator", "tvos")
        when "watchsimulator"
          @main_build_settings["SDK_NAME"].gsub("simulator", "os")
        else
          @main_build_settings["SDK_NAME"]
        end
      "#{architecture}-apple-#{sdk}"
    end

    def build_settings(target)
      %x{ xcodebuild -project "#{@project.path.expand_path.to_s}" -target "#{target.name}" -showBuildSettings }
        .split("\n")
        .map do |setting|
          setting.strip.split("=")
        end.select do |splitted|
          splitted.size == 2
        end.map do |splitted|
          splitted.map do |token|
            token.strip
          end
        end.to_h
    end

  end

end