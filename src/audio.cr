module Radio::Audio
  @@skipper = Channel(Bool).new
  class_property skipper

  extend self

  def ffmpeg_mp3_cmd(file : Path) : String
    %<ffmpeg -i "#{file}" -vn -f mp3 - >
  end

  def audio_pipe(file : Path)
    args = ffmpeg_mp3_cmd file
    Process.run args, shell: true do |process|
      sleep 0.1.seconds
      if process.terminated?
        status = process.wait
        return if status.success?
        exit_code = if status.normal_exit?
                      "exit code " + status.exit_code.to_s
                    else
                      "signal " + status.exit_signal.to_s
                    end
        raise "command #{args} failed with #{exit_code}"
      else
        yield process.output
      end
    end
  end

  class_property mime_type : Magic::TypeChecker { Magic.mime_type.all_types }

  def is_audio?(mime : Array(String))
    mime.any? do |mt|
      VALID_AUDIO_MIME.any? do |valid_mt|
        mt == valid_mt
      end
    end
  end

  private def mime_type(of path : Path | String) : Array(String)
    self.class.mime_type.of(path.to_s).split("\012- ")
  end
end
