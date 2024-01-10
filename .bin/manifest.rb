#!ruby
require 'fileutils'
require 'json'
require 'optparse'
require 'pathname'

SRC_DIR = File.expand_path(File.dirname(__FILE__))

DIGITAL_STACKS_DIR = Pathname.new(SRC_DIR).dirname

def verify_directory(file_path, relative_subdir: false, writable: false)

	if relative_subdir && Pathname.new(file_path).absolute?
		begin
			file_path =  Pathname.new(file_path).relative_path_from(DIGITAL_STACKS_DIR)
		rescue ArgumentError
			puts "Directory #{file_path} must be relative subdirectory of #{DIGITAL_STACKS_DIR}"
			return false
		end
	end
	unless Dir.exists?(file_path) && (!writable || File.writable?(file_path))
		puts "Directory #{file_path} must exist"
		puts "Directory #{file_path} must be writable" if writable
		return false
	end
	true
end

options = {
	output_dir: 'browser',
	host: 'lito.cul.columbia.edu',
	path: 'digitalstacks'
}

OPTIONS = OptionParser.new do |opts|
	opts.banner = "Usage: ruby .bin/manifest.rb [options]"
	opts.on("-h", "--help", "Prints this help") do
		puts opts
		exit
	end
	opts.on("-b [PATH]", "--base-path [PATH]", "Base path to use in links; no PATH arg will be none (default is #{options[:path]})") { |v| options[:path] = v }
	opts.on("-d DOMAIN", "--domain DOMAIN", "Domain name to use in links (default is #{options[:host]})") { |v| options[:host] = v }
	opts.on("-p", "--port PORT", Integer, "TCP port to use in links (default is implicit per ssl option)") { |v| options[:port] = v }
	opts.on("-s", "--[no-]ssl", TrueClass, "Build https links (default is true)") { |v| options[:ssl] = v }
	opts.on("-i", "--input-dir INPUT_DIR", "Input content directory (required)") do |v|
		abort("Input directory is required and must be an existing subdirectory of #{DIGITAL_STACKS_DIR}") unless v && verify_directory(v, relative_subdir: true)
		options[:input_dir] = v
	end
	opts.on("-o", "--output-dir OUTPUT_DIR", "Output directory (default is '#{options[:output_dir]}')") do |v|
		v ||= 'browser'
		abort("Output directory must exist and be writable") unless v && verify_directory(v, writable: true)
		options[:output_dir] = v
	end
end

OPTIONS.parse!

unless options[:input_dir]
	puts "Input directory is required and must be an existing subdirectory of #{DIGITAL_STACKS_DIR}"
	puts OPTIONS
	exit
end

options[:base_url] = "#{options[:ssl] ? 'https' : 'http'}://#{options[:host]}#{(':' + options[:port].to_s) if options[:port]}"
options[:base_url] = File.join(options[:base_url], options[:path]) if options[:path].to_s != ""

def evaluate_json_template(template_path, content_path, options)
	template_src = File.read(template_path)
	template_src.gsub!('$BASE_URL', options[:base_url])
	template_src.gsub!('$FILE_NAME', File.basename(content_path))
	template_src.gsub!('$OUTPUT_DIR', options[:output_dir])
	template_src.gsub!('$PARENT_PATH', File.dirname(content_path))
	template_src.gsub!('$PATH', content_path)
	JSON.load(template_src)
end

def manifest(options)
	dir_name = options[:input_dir]
	dir = Dir.new(dir_name)
	collection = evaluate_json_template(File.join(SRC_DIR, 'collection.json'), dir_name, options)
	collection['id'] << File.join(dir_name, 'collection.json')
	if (dir_name.split('/').length > 1)
		parent = File.dirname(dir_name)
		collection_id = collection.fetch('partOf', [{'id' => ''}])[0]['id']
		collection_id << File.join(parent, 'collection.json')
	else
		collection.delete('partOf')
	end
	items = collection['items']
	Dir.foreach(dir_name) do |entry|
		next if entry =~ /^\./
		entry_path = File.join(dir_name, entry)
		puts entry_path
		if File.directory?(entry_path)
			items << manifest(options.merge(input_dir: entry_path))
		elsif entry_path =~ /\.pdf/i
			items << canvas_manifest(entry_path, options)
		else
			puts "nothing for #{entry}"
		end
	end
	FileUtils.mkdir_p(File.join(options[:output_dir], dir_name))
	open(File.join(options[:output_dir], dir_name, 'collection.json'), mode: 'w') { |io| io << JSON.pretty_generate(collection)}
	{ 'id' => collection['id'], 'type' => 'Collection', 'label' => collection['label'] }
end

def canvas_manifest(file_path, options)
	canvas = evaluate_json_template(File.join(SRC_DIR, 'canvas.json'), file_path, options)
	canvas['metadata'].each do |att|
		att_label = att.fetch('label', { 'en' => [] })['en'][0]
		if att_label == 'File size'
			att['value'] = "#{File.size(file_path)} bytes"
		end
		if att_label == 'Modification date'
			att['value'] = File.mtime(file_path)
		end
	end
	json_path = File.join(options[:output_dir], "#{file_path}.json")
	FileUtils.mkdir_p(File.dirname(json_path))
	open(File.join(options[:output_dir], "#{file_path}.json"), mode: 'w') { |io| io << JSON.pretty_generate(canvas)}
	{ 'id' => canvas['id'], 'type' => 'Manifest', 'label' => canvas['label'] }
end

collection = manifest(options)
html_template = File.read(File.join(SRC_DIR, 'index.html'))
html_template.gsub!('$BASE_URL', options[:base_url])
html_template.gsub!('$MANIFEST', collection['id'])
open(File.join(options[:output_dir], options[:input_dir], 'index.html'), mode: 'w') { |io| io << html_template }
