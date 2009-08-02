#!ruby
# vim: noet ts=2 sts=8 sw=2

require 'rubygems'
gem 'rdoc', '>= 2.4' unless defined? $rdoc_rakefile

require 'pp'
require 'pathname'
require 'fileutils'
require 'erb'
require 'yaml'

require 'rdoc/rdoc'
require 'rdoc/generator'
require 'rdoc/generator/markup'
require 'uri'

#
#  Darkfish RDoc HTML Generator
#  
#  $Id: darkfish.rb 52 2009-01-07 02:08:11Z deveiant $
#
#  == Author/s
#  * Michael Granger (ged@FaerieMUD.org)
#  
#  == Contributors
#  * Mahlon E. Smith (mahlon@martini.nu)
#  * Eric Hodel (drbrain@segment7.net)
#  
#  == License
#  
#  Copyright (c) 2007, 2008, Michael Granger. All rights reserved.
#  
#  Redistribution and use in source and binary forms, with or without
#  modification, are permitted provided that the following conditions are met:
#  
#  * Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
#  
#  * Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#  
#  * Neither the name of the author/s, nor the names of the project's
#    contributors may be used to endorse or promote products derived from this
#    software without specific prior written permission.
#  
#  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
#  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
#  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
#  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
#  FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
#  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
#  SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
#  CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
#  OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
#  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#  
class RDoc::Generator::SingleDarkfish < RDoc::Generator::Darkfish
	RDoc::RDoc.add_generator( self )
	
  RDoc::Context.instance_eval do
    org = instance_method(:http_url)
    define_method(:http_url) do |prefix|
	    if RDoc::Generator::SingleDarkfish.current?
	      prefix + full_name
      else
        org.bind(self).call(prefix)
      end
    end
  end
  
  RDoc::AnyMethod.instance_eval do
    org = instance_method(:path)
    define_method(:path) do
      if RDoc::Generator::SingleDarkfish.current?
	      "##{@aref}"
      else
        org.bind(self).call
      end
    end
  end
  
  def self.current?
    RDoc::RDoc.current.generator.class.ancestors.include?(self)
  end

	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Initialize a few instance variables before we start
	def initialize( options )
		@options = options
		@options.diagram = false

		template = @options.template || 'darkfish'

		template_dir = $LOAD_PATH.map do |path|
			File.join path, GENERATOR_DIR, 'template', template
		end.find do |dir|
			File.directory? dir
		end

		raise RDoc::Error, "could not find template #{template.inspect}" unless
			template_dir

		@template_dir = Pathname.new File.expand_path(template_dir)

		@basedir = Pathname.pwd.expand_path
	end

	######
	public
	######
	
	def class_dir
	  '#class-'
  end 
  
  def file_dir
    '#file-'
  end
  
  def index_template
    'reference.rhtml'
  end

	### Build the initial indices and output objects
	### based on an array of TopLevel objects containing
	### the extracted information.
	def generate( top_levels )
		@outputdir = Pathname.new( @options.op_dir ).expand_path( @basedir )

		@files = top_levels.sort
		@classes = RDoc::TopLevel.all_classes_and_modules.sort
		@methods = @classes.map { |m| m.method_list }.flatten.sort
		@modsort = get_sorted_module_list( @classes )

		# Now actually write the output
		generate_index
	rescue StandardError => err
		debug_msg "%s: %s\n  %s" % [ err.class.name, err.message, err.backtrace.join("\n  ") ]
		raise
	end
	
	def generate_index
		debug_msg "Rendering the index page..."

		templatefile = @template_dir + index_template
		template_src = templatefile.read
		template = ERB.new( template_src, nil, '<>' )
		template.filename = templatefile.to_s
		context = binding()

		output = nil

		begin
			output = template.result( context )
		rescue NoMethodError => err
			raise RDoc::Error, "Error while evaluating %s: %s (at %p)" % [
				templatefile,
				err.message,
				eval( "_erbout[-50,50]", context )
			], err.backtrace
		end

		outfile = @basedir + @options.op_dir + 'index.html'
		unless $dryrun
			debug_msg "Outputting to %s" % [outfile.expand_path]
			outfile.open( 'w', 0644 ) do |fh|
				fh.print( output )
			end
		else
			debug_msg "Would have output to %s" % [outfile.expand_path]
		end
	end
end # Roc::Generator::SingleDarkfish

# :stopdoc: