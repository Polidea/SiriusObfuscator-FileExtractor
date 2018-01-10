module FileExtractor

  require 'file-extractor/files_json_struct'
  require 'file-extractor/xcodeproj_extractor'
  require 'file-extractor/modules_extractor'
  require 'file-extractor/sdk_resolver'

  class DataExtractor

    def self.run(project_path, files_path)
      data_extractor = FileExtractor::XcodeprojExtractor.new(project_path)

      data = data_extractor.extract_data
      data.systemLinkedFrameworks = FileExtractor::ModulesExtractor.system_linked_frameworks(data)
      data.sdk.path = FileExtractor::SdkResolver.sdk_path(data)
      data.explicitelyLinkedFrameworks = FileExtractor::SdkResolver.update_frameworks_paths(data)

      json = JSON.pretty_generate(data)
      if files_path.nil?
        return json, "No output file given, so no data was written"
      else
        File.open("#{files_path}","w") do |file|
          file.write(json)
        end
        return json, "Data written to:\n#{files_path}"
      end
    end

  end

end