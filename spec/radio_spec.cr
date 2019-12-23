require "magic"
require "./spec_helper"

TEST_MP3_FILE = Path["11 The World Is Horseradish.flac"]

describe Radio::Audio do
  describe "ffmpeg_mp3_cmd" do
    it "is correct" do
      Radio::Audio.ffmpeg_mp3_cmd(Path["test-file"])
        .should eq %<ffmpeg -i "test-file" -vn -f mp3 - >
    end
  end
  describe "audio_pipe" do
    it "works" do
      buffer = Bytes.new 32768
      Radio::Audio.audio_pipe TEST_MP3_FILE do |pipe|
        (pp! pipe).read buffer
        break
      end
      Radio::Audio.mime_type.of(buffer).should contain "audio/mpeg"
    end
  end
end
