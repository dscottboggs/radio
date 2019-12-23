Process.run %<ffmpeg -i "/home/scott/Music/Air/2004 - Talkie Walkie/01 - AIR - Venus.flac" -vn -f mp3 -">, shell: true do |proc|
  until proc.terminated?
    IO.copy proc.output, STDOUT
  end
end
