require "kemal"
require "./random_file_selector"
require "./audio"

module Radio
  CHUNK_SIZE = 32768 # less than that and the filetype is not detected
  # needs_skip and request_skip are each an end of singleton channel to request
  # that the current file stop being served.

  class_property root_dir : Path = Path.new ARGV[0]? || abort "expected search directory as the first argument, got #{ARGV}"

  class_property random_file_selector : RandomFileSelector = RandomFileSelector
    .from_file_list || RandomFileSelector.new root_dir

  extend Audio

  get "/stream" do |context|
    debugger
    context.response.content_type = "audio/mpeg3"
    # All Slice/Bytes constructors zero the memory, which is unnecessary
    # in this scenario. Instead, we stack-allocate a static buffer, then
    # create a buffer which points to that StaticArray. As a side-benefit,
    # this also avoids allocating the buffer on the heap!
    buf_data = uninitialized UInt8[CHUNK_SIZE]
    buffer = Bytes.new pointer: buf_data.to_unsafe, size: CHUNK_SIZE
    connected = true
    while connected
      file = random_file_selector.sample
      audio_pipe file do |pipe|
        until (count = pipe.read buffer) == 0
          select
          when skipper.receive then break
          else
            if context.response.closed?
              connected = false
              break
            end
            if count > CHUNK_SIZE
              puts "got read count #{count} that was larger than the buffer size #{CHUNK_SIZE}"
              raise "Internal server error: invalid buffer size"
            end
            # There could be junk data at the end of the buffer if
            # the call to #read doesn't fill it.
            context.response.write Bytes.new buffer.to_unsafe, size: count, read_only: true
          end
        end
      end
    end
  end
  get "/skip" do |context|
    skipper.send true
  end
  Kemal.run port: 10_000
end
