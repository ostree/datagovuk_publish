require_relative 'update_organogram_filenames.rb'

desc "Fix existing organogram filenames"
task :fix_existing_organogram_filenames => :environment do
  UpdateOrganogramFilenames.new().call
end
