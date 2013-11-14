#
# Perform a deep copy of an object
#
class Object
  def deepcopy
    Marshal.load(Marshal.dump(self))
  end
end

#
# This class reads a file written in Yaml and returns a table containing the read data.
#
# If the "all_signals" alternative has been specified, its rules will constitute the
# initial setting for each signal.
# If a signal is named in a document, any rule it has whose key is identical to a key
# given by the "all_signals" alternative, will be overridden.
#
class YamlReader
  require 'yaml'
  require 'pp'

  def initialize(infile)
    @infile = infile
    @yamltab = {}
    @newtab = {}
  end

  def yamltab
    @yamltab
  end

  def has?(ydoc, name)
    ydoc.has_key?(name) && !ydoc[name].empty?
  end

  def read_documents(ydoc)
    return if ydoc.nil?
    if ydoc["signal"].kind_of?(String)
      ydoc["signal"] = [ydoc["signal"]]
    elsif ydoc["signal"].nil?
      return # dummy entry, discard    
    end

    ydoc["signal"].each do |e|
      @yamltab[e] = {} unless @yamltab.has_key?(e)
      if has?(ydoc, "ioexception_rec")
        @yamltab[e]["ioexception_rec"] = ydoc["ioexception_rec"]
      end
      if has?(ydoc, "ioexception_send")
        @yamltab[e]["ioexception_send"] = ydoc["ioexception_send"]
      end
      if has?(ydoc, "extends")
        @yamltab[e]["extends"] = ydoc["extends"]
      end
      if has?(ydoc, "import")
        @yamltab[e]["import"] = ydoc["import"]
      end
      if (has?(ydoc, "union") && !has?(ydoc, "selector")) ||
         (!has?(ydoc, "union") && has?(ydoc, "selector"))
        raise "Both \'union\' and \'selector\' have to be present"
      elsif has?(ydoc, "union") && has?(ydoc, "selector")
        @yamltab[e]["union"] = ydoc["union"]
        @yamltab[e]["selector"] = ydoc["selector"]
      end
    end
  end

  def merge_rules
    if @yamltab.has_key?("all_signals") && !@yamltab["all_signals"].empty?
      @newtab["all_signals"] = @yamltab["all_signals"].deepcopy
      @yamltab.each do |a,b|
        unless a.eql?("all_signals")
          h = {}
          h[a] = @yamltab["all_signals"].deepcopy
          h[a].merge!(@yamltab[a].deepcopy)
          @newtab[a] = h[a]
        end
      end
      @yamltab = @newtab
    end
  end

  def parse
    d = YAML.load_file(@infile)
    if d.has_key?("filelist")
      kind = "filelist"
    elsif d.has_key?("signal")
      kind = "signal"
    else
      raise "Invalid codefile"
    end
    case kind
    when "filelist"
      d["filelist"].each do |f|
        file = File.expand_path(f)
        if File.exist?(file)
          File.open(file) do |g|
            YAML.each_document(g) do |ydoc|
              read_documents(ydoc)
            end
          end
        else
          raise "File #{file} doesn't exist"
        end
      end
    when "signal"
      File.open(@infile) do |f|
        YAML.each_document(f) do |ydoc|
          read_documents(ydoc)
        end
      end
    end
    merge_rules
    return @yamltab
  end

end