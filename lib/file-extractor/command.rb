module FileExtractor

  require 'xcodeproj'
  require 'json'

  class Command 
    def self.run(argv)
      puts "Path to .xcodeproj:"
      puts argv[0]
      @data = self.getDataFromXcodeproj(argv.first)
      @data = self.getSystemLinkedFrameworks(@data)
      @data = self.resolveSdkPath(@data)
      puts "\n\nFound data:\n"
      json = @data.to_json
      puts json
      output = argv[1]
      if output.nil?
        puts "\n\nNo output file"
      else
        File.open("#{argv[1]}","w") do |file|
          file.write(json)
        end
        puts "\n\nData written to:"
        puts argv[1]
      end    
    end

    def self.getDataFromXcodeproj(project_path)
      @data = {}
      @data[:module] = {}
      @data[:sdk] = {}
      @data[:filenames] = []
      @data[:explicitelyLinkedFrameworks] = {}

      project = Xcodeproj::Project.open(project_path)

      # for now, the module name is the target name. ofc that's a non-generalizable assumption
      @data[:module][:name] = project.targets.to_a.select do |target| 
        target.instance_of? Xcodeproj::Project::Object::PBXNativeTarget
      end.first.name

      @data[:sdk] = project.targets.to_a.select do |target| 
        target.instance_of? Xcodeproj::Project::Object::PBXNativeTarget
      end.map do |target| 
        @sdk = {}
        @sdk[:name] = target.sdk
        @sdk
      end.first

      @data[:filenames] = project.targets.to_a.select do |target| 
        target.instance_of? Xcodeproj::Project::Object::PBXNativeTarget
      end.flat_map do |target|
        target.source_build_phase.files.to_a
      end.map do |pbx_build_file|
        pbx_build_file.file_ref.real_path.to_s
      end.select do |path|
        path.end_with?(".swift")
      end.select do |path|
        File.exists?(path)
      end

      @data[:explicitelyLinkedFrameworks] = project.targets.first.frameworks_build_phase.files.map do |framework|
        @framework = {}
        name = framework.file_ref.name
        path = framework.file_ref.real_path.to_s
        @framework[:name] = name.sub(".framework", "")
        @framework[:path] = path.sub(name, "")
        @framework
      end

      @data
    end

    def self.getSystemLinkedFrameworks(data)
      data[:systemLinkedFrameworks] = []
      explicitelyLinkedFrameworksNames = data[:explicitelyLinkedFrameworks].map do |framework| 
        framework[:name]
      end
      frameworks = data[:filenames].flat_map do |file|
        %x{ xcrun swiftc -emit-imported-modules #{file} }.split("\n").reject(&:empty?)
      end.uniq.select do |framework|
        !(explicitelyLinkedFrameworksNames.include? framework)
      end
      data[:systemLinkedFrameworks] = frameworks
      data
    end

    def self.resolveSdkPath(data)
      sdkName = data[:sdk][:name]
      sdkPath = %x{ xcrun --sdk #{sdkName} --show-sdk-path }
      data[:sdk][:path] = sdkPath.sub("\n", "")
      data[:explicitelyLinkedFrameworks] = data[:explicitelyLinkedFrameworks].map do |framework|
        framework[:path] = framework[:path].sub("${SDKROOT}", data[:sdk][:path])
        framework
      end
      data
    end

  end
end
