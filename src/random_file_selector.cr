require "magic"

struct JobQueueStatus
  @count : Int32 = 0
  property? first_job_encountered : Bool = false

  def push
    first_job_encountered = true
    (@count += 1) > 0
  end

  def pop
    raise "completed more jobs than started!" if @count < 0
    (@count -= 1) > 0
  end

  def done?
    first_job_encountered? && @count == 0
  end
end

class Radio::RandomFileSelector
  VALID_AUDIO_MIME = [
    "audio/mpeg",
    "audio/flac",
    "audio/ogg",
    "audio/x-m4a",
    "audio/x-wav",
  ]

  class_property file_list_location : Path do
    confdir = ENV["XDG_CONFIG_HOME"]?.try { |d| Path[d] }
    confdir ||= Path[ENV["HOME"], ".config"]
    confdir /= "radio"
    Dir.mkdir_p confdir.to_s
    confdir / "file.list"
  end

  property parent, paths
  delegate :sample, to: paths

  @jobs = JobQueueStatus.new
  @file_list = File.open file_list_location, mode: "a"

  def initialize(@parent : Path)
    @paths = [] of Path
    @file_list.truncate
    @file_list.puts @parent.to_s
    spawn do
      @jobs.push
      load @parent
    ensure
      @jobs.pop
    end
    spawn do
      until @jobs.done?
        sleep 1
      end
      @file_list.close
    end
  end

  def initialize(@parent : Path, @paths : Array(Path))
    @file_list.close
  end

  def finalize
    @file_list.try { |file| file.close unless file.closed? }
  end

  def self.from_file_list : RandomFileSelector?
    return unless File.exists? file_list_location
    parent : Path = Path["/"]
    paths = [] of Path
    File.open file_list_location do |file|
      parent = Path.new(file.gets || return)
      paths << Path.new(file.gets || return)
      while line = file.gets
        paths << Path.new line
      end
    end
    raise "implementation error" if parent == Path["/"]
    new parent, paths
  end

  private def load(path : Path)
    Dir.each_child path.to_s do |child|
      fullpath = path / child
      if File.directory? fullpath
        spawn do
          @jobs.push
          load fullpath
        ensure
          @jobs.pop
        end
      else
        mime = mime_type of: fullpath
        if is_audio?(mime) || (fullpath.extension === ".mp3")
          paths << fullpath
          @file_list.puts fullpath.to_s
        else
          puts "warning -- skipping invalid file #{fullpath} with \
                mime types #{mime} and extension '#{fullpath.extension}'"
        end
      end
    end
  end
end
