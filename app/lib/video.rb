module Video
  # Los errores viven en Ffprobe, que es quien los conoce. Se re-exportan acá
  # para que quien trabaja con video no tenga que saber de dónde vienen.
  Unreadable = Ffprobe::Unreadable
  NotInstalled = Ffprobe::NotInstalled
end
